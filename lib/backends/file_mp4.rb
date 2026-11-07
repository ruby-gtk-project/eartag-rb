# frozen_string_literal: true

require 'taglib'
require_relative 'file'

# Backends::Mp4File reads and writes the iTunes-style atoms on MP4 containers
# (.m4a, .m4b, .mp4).
#
# Ported from upstream's src/backends/file_mutagen_mp4.py, which maps each
# tag onto an MP4 atom through Mutagen's MP4Tags. taglib-ruby exposes the
# same atoms through TagLib::MP4::Tag's item map (`tag["aART"]`, keyed by the
# same four/five-character atom names Mutagen uses), so the mapping below
# matches upstream's ATOM_MAPPING.
#
# TRKN/DISK are "number/total" pairs stored as a single atom holding two
# integers (TagLib::MP4::Item#to_int_pair), split into two in-memory keys the
# same way the ID3 backend splits TRCK/TPOS.
module Backends
  class Mp4File < EartagFile
    STRING_ATOMS = {
      'title'           => "\u00A9nam",
      'artist'          => "\u00A9ART",
      'album'           => "\u00A9alb",
      'albumartist'     => 'aART',
      'genre'           => "\u00A9gen",
      'comment'         => "\u00A9cmt",
      'releasedate'     => "\u00A9day",
      'composer'        => "\u00A9wrt",
      'copyright'       => 'cprt',
      'discsubtitle'    => '----:com.apple.iTunes:DISCSUBTITLE',
      'encodedby'       => "\u00A9too",
      'publisher'       => '----:com.apple.iTunes:LABEL',
      'isrc'            => '----:com.apple.iTunes:ISRC',
      'language'        => '----:com.apple.iTunes:LANGUAGE',
      'url'             => '----:com.apple.iTunes:WEBSITE',
      'conductor'       => '----:com.apple.iTunes:CONDUCTOR',
      'arranger'        => '----:com.apple.iTunes:ARRANGER',
      'mood'            => '----:com.apple.iTunes:MOOD',
      'albumartistsort' => 'soaa',
      'albumsort'       => 'soal',
      'composersort'    => 'soco',
      'artistsort'      => 'soar',
      'titlesort'       => 'sonm',
    }.freeze

    BOOL_ATOMS = { 'compilation' => 'cpil' }.freeze
    INT_ATOMS = { 'bpm' => 'tmpo' }.freeze
    PAIR_ATOMS = {
      %w[tracknumber totaltracknumber] => 'trkn',
      %w[discnumber]                   => 'disk',
    }.freeze

    def supported_extra_tags
      (STRING_ATOMS.keys + BOOL_ATOMS.keys + INT_ATOMS.keys + %w[discnumber]) - Tags::BASIC_TAGS
    end

    def load_from_file(path)
      @path = path
      @tags = {}

      TagLib::MP4::File.open(path) do |file|
        tag = file.tag
        STRING_ATOMS.each do |name, atom|
          if tag.contains(atom)
            @tags[name] = tag[atom].to_string_list.first
          else
            @tags[name] = nil
          end
        end
        BOOL_ATOMS.each do |name, atom|
          if tag.contains(atom) && tag[atom].to_bool
            @tags[name] = '1'
          else
            @tags[name] = nil
          end
        end
        INT_ATOMS.each do |name, atom|
          if tag.contains(atom)
            @tags[name] = tag[atom].to_int.to_s
          else
            @tags[name] = nil
          end
        end
        PAIR_ATOMS.each do |names, atom|
          if tag.contains(atom)
            pair = tag[atom].to_int_pair
          else
            pair = [nil, nil]
          end
          names.each_with_index { |name, index| @tags[name] = pair[index]&.nonzero?&.to_s }
        end

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
      TagLib::MP4::File.open(path) do |file|
        tag = file.tag

        STRING_ATOMS.each { |name, atom| write_string(tag, atom, @tags[name]) }
        BOOL_ATOMS.each do |name, atom|
          @tags[name] ? (tag[atom] = TagLib::MP4::Item.from_bool(true)) : tag.remove_item(atom)
        end
        INT_ATOMS.each do |name, atom|
          @tags[name] ? (tag[atom] = TagLib::MP4::Item.from_int(@tags[name].to_i)) : tag.remove_item(atom)
        end
        PAIR_ATOMS.each { |names, atom| write_pair(tag, atom, names.map { |name| @tags[name] }) }

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
      TagLib::MP4::File.open(path) do |file|
        file.tag.strip
        file.save
      end
      @tags = {}
    end

    private

      def write_string(tag, atom, value)
        if value && !value.to_s.empty?
          tag[atom] = TagLib::MP4::Item.from_string_list([value.to_s])
        else
          tag.remove_item(atom)
        end
      end

      def write_pair(tag, atom, values)
        number, total = values
        if number
          tag[atom] = TagLib::MP4::Item.from_int_pair([number.to_i, total ? total.to_i : 0])
        else
          tag.remove_item(atom)
        end
      end
  end
end
