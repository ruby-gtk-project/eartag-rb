# frozen_string_literal: true

# Validation decides whether a file is one Ear Tag can open, and what its
# mimetype is.
#
# Ported from upstream's src/utils/validation.py. Upstream leans on filetype.py
# for content sniffing, with two matchers of its own bolted on (an improved MP3
# matcher and a WMA matcher filetype.py lacks). filetype.py has no Ruby
# equivalent, so the matchers for the formats in the two mime lists below are
# implemented here directly — the same approach filetype.py takes, which is to
# compare the first bytes of the file against each format's magic number.
#
# Upstream's async variants are not ported: they exist because filetype.py and
# os.path.exists block the Python event loop, which is not a problem Ruby's
# threads have.
#
module Validation
  VALID_AUDIO_MIMES = [
    'application/ogg',
    'application/x-ogg',
    'audio/aac',
    'audio/flac',
    'audio/mp3',
    'audio/mp4',
    'audio/mpeg',
    'audio/ogg',
    'audio/wav',
    'audio/x-flac',
    'audio/x-m4a',
    'audio/x-mp3',
    'audio/x-mpeg',
    'audio/x-ms-wma',
    'audio/x-vorbis+ogg',
    'audio/x-wav',
    'video/mp4',
    'video/x-ms-asf',
    'video/x-wmv',
  ].freeze

  VALID_IMAGE_MIMES = [
    # Supported natively by most formats:
    'image/jpg',
    'image/jpeg',
    'image/png',
    # Converted before embedding:
    'image/bmp',
    'image/jp2',
    'image/webp',
  ].freeze

  # The ASF header object GUID, which both WMA and WMV files open with.
  ASF_GUID = [
    0x30, 0x26, 0xB2, 0x75, 0x8E, 0x66, 0xCF, 0x11,
    0xA6, 0xD9, 0x00, 0xAA, 0x00, 0x62, 0xCE, 0x6C,
  ].freeze

  # The MPEG audio frame sync bytes upstream's ImprovedMP3 matcher accepts:
  # MPEG 1, 2 and 2.5, with and without error protection.
  MPEG_SYNC_BYTES = [0xE2, 0xE3, 0xF2, 0xF3, 0xFA, 0xFB].freeze

  # ISO base media file format brands, mapping the brand in the ftyp box to the
  # mimetype. The MP4 container carries both audio and video.
  FTYP_BRANDS = {
    'M4A'  => 'audio/mp4',
    'M4B'  => 'audio/mp4',
    'M4P'  => 'audio/mp4',
    'mp4'  => 'video/mp4',
    'iso'  => 'video/mp4',
    'avc'  => 'video/mp4',
    'dash' => 'video/mp4',
    'jp2'  => 'image/jp2',
  }.freeze

  # Only used when content sniffing fails, mirroring Python's mimetypes.guess_type.
  MIMES_BY_EXTENSION = {
    '.aac'  => 'audio/aac',
    '.asf'  => 'video/x-ms-asf',
    '.bmp'  => 'image/bmp',
    '.flac' => 'audio/x-flac',
    '.jp2'  => 'image/jp2',
    '.jpeg' => 'image/jpeg',
    '.jpg'  => 'image/jpeg',
    '.m4a'  => 'audio/mp4',
    '.m4b'  => 'audio/mp4',
    '.mp3'  => 'audio/mpeg',
    '.mp4'  => 'video/mp4',
    '.oga'  => 'audio/ogg',
    '.ogg'  => 'audio/ogg',
    '.opus' => 'audio/ogg',
    '.png'  => 'image/png',
    '.wav'  => 'audio/x-wav',
    '.webp' => 'image/webp',
    '.wma'  => 'audio/x-ms-wma',
    '.wmv'  => 'video/x-ms-wmv',
  }.freeze

  #: How much of the file's head the matchers need. The longest check (the ASF
  #: GUID) needs 16 bytes; reading a page keeps it to one read.
  HEADER_SIZE = 4096

  module_function

  # Get the mimetype from a buffer of file data, or nil if nothing matches.
  def mimetype_buffer(data)
    data.to_s.b.then do |buffer|
      matchers.find { |_mime, matcher| matcher.call(buffer) }&.first
    end
  end

  # Return the mimetype (or nil) for the file with the given path.
  #
  # no_extension_guess skips guessing the filetype from the extension;
  # no_cache skips the mimetype cache.
  def mimetype(path, no_extension_guess: false, no_cache: false)
    if !no_cache && cache.key?(path.to_s)
      cache[path.to_s]
    else
      detect_mimetype(path, no_extension_guess: no_extension_guess).tap do |mime|
        unless no_cache
          cache[path.to_s] = mime
        end
      end
    end
  end

  # Takes a path to a file and returns true if it's supported, false otherwise.
  def valid_file?(path, valid_mime_types, no_cache: false)
    # In Flatpak, some files don't exist; double-check to make sure.
    if File.exist?(path)
      valid_mime_types.include?(mimetype(path, no_cache: no_cache))
    else
      false
    end
  end

  # Check if the file at the provided path is a supported audio file.
  def valid_music_file?(path, no_cache: false)
    valid_file?(path, VALID_AUDIO_MIMES, no_cache: no_cache)
  end

  # Check if the file at the provided path is a supported image file.
  def valid_image_file?(path, no_cache: false)
    valid_file?(path, VALID_IMAGE_MIMES, no_cache: no_cache)
  end

  def cache = @cache ||= {}

  def clear_cache
    cache.clear
  end

  def detect_mimetype(path, no_extension_guess: false)
    mimetype_buffer(read_header(path)).then do |mime|
      if mime.nil? && !no_extension_guess
        MIMES_BY_EXTENSION[File.extname(path.to_s).downcase]
      else
        mime
      end
    end
  end

  def read_header(path)
    File.binread(path, HEADER_SIZE).to_s
  rescue SystemCallError
    ''
  end

  # The matchers, in the order upstream's FILETYPE_MATCHERS tuple puts them:
  # the custom MP3 and WMA matchers first, then audio, image and video.
  def matchers
    @matchers ||= {
      'audio/mpeg'     => ->(data) { mpeg?(data) },
      'audio/x-ms-wma' => ->(data) { asf?(data) },
      'audio/aac'      => ->(data) { aac?(data) },
      'audio/x-flac'   => ->(data) { data.start_with?('fLaC') },
      'audio/ogg'      => ->(data) { data.start_with?('OggS') },
      'audio/x-wav'    => ->(data) { riff?(data, 'WAVE') },
      'image/webp'     => ->(data) { riff?(data, 'WEBP') },
      'image/jpeg'     => ->(data) { data.start_with?("\xFF\xD8\xFF".b) },
      'image/png'      => ->(data) { data.start_with?("\x89PNG\r\n\x1A\n".b) },
      'image/bmp'      => ->(data) { data.start_with?('BM') },
      'image/jp2'      => ->(data) { jpeg2000?(data) },
      'audio/mp4'      => ->(data) { ftyp_mime(data) == 'audio/mp4' },
      'video/mp4'      => ->(data) { ftyp_mime(data) == 'video/mp4' },
    }
  end

  # Upstream's ImprovedMP3: an ID3 header, or a bare MPEG frame sync.
  def mpeg?(data)
    data.start_with?('ID3') ||
      (data.length > 2 && data.getbyte(0) == 0xFF && MPEG_SYNC_BYTES.include?(data.getbyte(1)))
  end

  def aac?(data)
    data.length > 1 && data.getbyte(0) == 0xFF && [0xF1, 0xF9].include?(data.getbyte(1))
  end

  # Upstream's Wma matcher, which also catches WMV — both are ASF containers,
  # and the audio/video distinction lives in the stream properties, not the
  # header, so upstream reports the audio mimetype for both.
  def asf?(data)
    data.length > ASF_GUID.length && data.bytes.first(ASF_GUID.length) == ASF_GUID
  end

  def riff?(data, form)
    data.start_with?('RIFF') && data[8, 4] == form
  end

  # Both the JP2 signature box and a bare ftyp-jp2 header appear in the wild.
  def jpeg2000?(data)
    data.start_with?("\x00\x00\x00\x0CjP  \r\n\x87\n".b) || ftyp_mime(data) == 'image/jp2'
  end

  # The brand in an ISO base media file format ftyp box, mapped to a mimetype.
  def ftyp_mime(data)
    if data.length >= 12 && data[4, 4] == 'ftyp'
      brand = data[8, 4].to_s
      FTYP_BRANDS[brand.strip] || FTYP_BRANDS[brand[0, 3]]
    end
  end
end
