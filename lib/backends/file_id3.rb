# frozen_string_literal: true

require 'taglib'
require_relative 'file'

# Backends::Id3File reads and writes ID3v2 tags on MPEG (.mp3) files.
#
# Ported from upstream's src/backends/file_mutagen_id3.py, which builds on
# Mutagen's EasyID3/ID3 classes. There is no Mutagen in Ruby, so this backend
# talks to taglib-ruby's TagLib::MPEG::File/TagLib::ID3v2 bindings directly.
#
# Unlike Mutagen, taglib-ruby has no "give me the file's current tag value"
# call that is cheap enough to use on every get_tag — the frame list comes
# back from a freshly opened TagLib::MPEG::File each time. So, like the other
# backends in this port, tags are read into an in-memory hash once in
# load_from_file and written back to the file only on save; get_tag/set_tag/
# has_tag?/delete_tag all work against that hash. TRCK/TPOS ("track/total" in
# one frame) are split into two in-memory keys and joined back on save.
#
# TXXX-based tags (the MusicBrainz identifiers) are not supported: a TXXX
# frame needs its description field matched too, which this backend's plain
# frame-id mapping cannot express, so those tags are left out of
# supported_extra_tags, the same way some of upstream's own backends leave
# some extra tags unsupported for their format.
module Backends
  class Id3File < EartagFile
    BASIC_FRAME_IDS = {
      'title'       => 'TIT2',
      'artist'      => 'TPE1',
      'album'       => 'TALB',
      'albumartist' => 'TPE2',
      'genre'       => 'TCON',
      'comment'     => 'COMM',
    }.freeze

    EXTRA_FRAME_IDS = {
      'bpm'             => 'TBPM',
      'compilation'     => 'TCMP',
      'composer'        => 'TCOM',
      'copyright'       => 'TCOP',
      'encodedby'       => 'TENC',
      'mood'            => 'TMOO',
      'conductor'       => 'TPE3',
      'arranger'        => 'TPE4',
      'publisher'       => 'TPUB',
      'isrc'            => 'TSRC',
      'language'        => 'TLAN',
      'discsubtitle'    => 'TSST',
      'albumartistsort' => 'TSO2',
      'albumsort'       => 'TSOA',
      'composersort'    => 'TSOC',
      'artistsort'      => 'TSOP',
      'titlesort'       => 'TSOT',
    }.freeze

    TEXT_FRAME_IDS = BASIC_FRAME_IDS.merge(EXTRA_FRAME_IDS).freeze

    def supported_extra_tags = EXTRA_FRAME_IDS.keys + %w[url discnumber]

    def load_from_file(path)
      @path = path
      @tags = {}

      TagLib::MPEG::File.open(path) do |file|
        frames = file.id3v2_tag(true).frame_list

        TEXT_FRAME_IDS.each do |name, frame_id|
          frame = frames.find { |candidate| candidate.frame_id.to_s == frame_id }
          @tags[name] = frame&.to_string
        end

        url_frame = frames.find { |candidate| candidate.frame_id.to_s == 'WOAR' }
        @tags['url'] = url_frame&.url

        track, total_tracks = split_pair(frames, 'TRCK')
        @tags['tracknumber'] = track
        @tags['totaltracknumber'] = total_tracks

        disc, = split_pair(frames, 'TPOS')
        @tags['discnumber'] = disc

        date_frame = frames.find { |candidate| %w[TDRC TYER].include?(candidate.frame_id.to_s) }
        @tags['releasedate'] = date_frame&.to_string

        properties = file.audio_properties
        @length = properties&.length_in_seconds
        @bitrate = properties&.bitrate
        @channels = properties&.channels
      end

      @tags.reject! { |_name, value| value.nil? || value.to_s.empty? }
      update_writability
      setup_present_extra_tags
      setup_original_values
    end

    def save
      TagLib::MPEG::File.open(path) do |file|
        tag = file.id3v2_tag(true)
        tag.frame_list.dup.each { |frame| tag.remove_frame(frame) }

        TEXT_FRAME_IDS.each { |name, frame_id| write_text_frame(tag, frame_id, @tags[name]) }
        write_url_frame(tag, @tags['url'])
        write_pair(
          tag,
          'TRCK',
          @tags['tracknumber'],
          @tags['totaltracknumber'],
        )
        write_pair(
          tag,
          'TPOS',
          @tags['discnumber'],
          nil,
        )
        write_text_frame(tag, 'TDRC', @tags['releasedate'])

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
      TagLib::MPEG::File.open(path) do |file|
        file.id3v2_tag(true).tap { |tag| tag.frame_list.dup.each { |frame| tag.remove_frame(frame) } }
        file.save
      end
      @tags = {}
    end

    private

      def split_pair(frames, frame_id)
        frame = frames.find { |candidate| candidate.frame_id.to_s == frame_id }
        (frame&.to_string || '').split('/', 2)
      end

      def write_text_frame(tag, frame_id, value)
        if value.nil? || value.to_s.empty?
          nil
        else
          TagLib::ID3v2::TextIdentificationFrame.new(frame_id, TagLib::String::UTF8).tap do |frame|
            frame.text = value.to_s
            tag.add_frame(frame)
          end
        end
      end

      def write_url_frame(tag, value)
        if value.nil? || value.empty?
          nil
        else
          TagLib::ID3v2::UrlLinkFrame.new(TagLib::String::UTF8).tap do |frame|
            frame.url = value
            tag.add_frame(frame)
          end
        end
      end

      def write_pair(tag, frame_id, number, total)
        if number.nil? || number.to_s.empty?
          nil
        else
          write_text_frame(tag, frame_id, total ? "#{number}/#{total}" : number.to_s)
        end
      end
  end
end
