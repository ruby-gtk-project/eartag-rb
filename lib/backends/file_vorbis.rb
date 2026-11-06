# frozen_string_literal: true

require 'taglib'
require_relative 'file'

# Backends::VorbisFile reads and writes the Xiph/Vorbis comment block shared
# by FLAC (.flac) and Ogg Vorbis (.ogg) files.
#
# Ported from upstream's src/backends/file_mutagen_vorbis.py, which uses
# Mutagen's FLAC/OggVorbis classes (both backed by the same VComment
# implementation upstream). taglib-ruby exposes the same comment block as
# TagLib::Ogg::XiphComment, reached via TagLib::FLAC::File#xiph_comment or
# TagLib::Ogg::Vorbis::File#tag — the field names (ALBUMARTIST, DISCNUMBER,
# ...) are the Vorbis comment convention upstream relies on too.
#
# As with the ID3 backend, tags are read into an in-memory hash once in
# load_from_file; get_tag/set_tag/has_tag?/delete_tag work against that hash,
# and save() writes it back to the comment block.
module Backends
  class VorbisFile < EartagFile
    FIELD_NAMES = {
      'title'                      => 'TITLE',
      'artist'                     => 'ARTIST',
      'album'                      => 'ALBUM',
      'albumartist'                => 'ALBUMARTIST',
      'tracknumber'                => 'TRACKNUMBER',
      'totaltracknumber'           => 'TRACKTOTAL',
      'genre'                      => 'GENRE',
      'releasedate'                => 'DATE',
      'comment'                    => 'COMMENT',
      'bpm'                        => 'BPM',
      'compilation'                => 'COMPILATION',
      'composer'                   => 'COMPOSER',
      'copyright'                  => 'COPYRIGHT',
      'encodedby'                  => 'ENCODED-BY',
      'mood'                       => 'MOOD',
      'conductor'                  => 'CONDUCTOR',
      'arranger'                   => 'ARRANGER',
      'discnumber'                 => 'DISCNUMBER',
      'publisher'                  => 'PUBLISHER',
      'isrc'                       => 'ISRC',
      'language'                   => 'LANGUAGE',
      'discsubtitle'               => 'DISCSUBTITLE',
      'url'                        => 'WEBSITE',
      'albumartistsort'            => 'ALBUMARTISTSORT',
      'albumsort'                  => 'ALBUMSORT',
      'composersort'               => 'COMPOSERSORT',
      'artistsort'                 => 'ARTISTSORT',
      'titlesort'                  => 'TITLESORT',

      'musicbrainz_artistid'       => 'MUSICBRAINZ_ARTISTID',
      'musicbrainz_albumid'        => 'MUSICBRAINZ_ALBUMID',
      'musicbrainz_albumartistid'  => 'MUSICBRAINZ_ALBUMARTISTID',
      'musicbrainz_trackid'        => 'MUSICBRAINZ_TRACKID',
      'musicbrainz_recordingid'    => 'MUSICBRAINZ_RELEASETRACKID',
      'musicbrainz_releasegroupid' => 'MUSICBRAINZ_RELEASEGROUPID',
    }.freeze

    def supported_extra_tags = FIELD_NAMES.keys - Tags::BASIC_TAGS

    def load_from_file(path)
      @path = path
      @tags = {}

      with_comment(path) do |comment, properties|
        fields = comment.field_list_map
        FIELD_NAMES.each do |name, field|
          @tags[name] = fields[field]&.first
        end
        @length = properties&.length_in_seconds
        @bitrate = properties&.bitrate
      end

      @tags.reject! { |_name, value| value.nil? || value.to_s.empty? }
      update_writability
      setup_present_extra_tags
      setup_original_values
    end

    def save
      with_comment(path, writable: true) do |comment, _properties, file|
        FIELD_NAMES.each do |name, field|
          comment.remove_fields(field)
          value = @tags[name]
          if value && !value.to_s.empty?
            comment.add_field(field, value.to_s)
          end
        end
        file.save
      end
      mark_as_unmodified
    end

    def get_tag(tag_name) = @tags[tag_name]
    def has_tag?(tag_name) = !@tags[tag_name].nil?

    def set_tag(tag_name, value)
      @tags[tag_name] = value
    end

    def delete_tag(tag_name)
      @tags.delete(tag_name)
    end

    def delete_all_raw
      with_comment(path, writable: true) do |comment, _properties, file|
        comment.remove_all_fields
        file.save
      end
      @tags = {}
    end

    private

      def flac? = filetype.downcase == '.flac'

      # Yields the XiphComment, the AudioProperties and the open File to the
      # block, using whichever taglib class matches this file's extension.
      def with_comment(file_path, writable: false)
        if flac?
          TagLib::FLAC::File.open(file_path) do |file|
            yield file.xiph_comment(writable), file.audio_properties, file
          end
        else
          TagLib::Ogg::Vorbis::File.open(file_path) do |file|
            yield file.tag, file.audio_properties, file
          end
        end
      end
  end
end
