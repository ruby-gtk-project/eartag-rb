# frozen_string_literal: true

require 'fileutils'
require 'securerandom'
require_relative '../tags'
require_relative '../misc'
require_relative '../logger'
require_relative '../validation'

# Backends::Cover and Backends::EartagFile are the model layer: a GObject-free
# wrapper around a single music file and the cover art it carries.
#
# Ported from upstream's src/backends/file.py — EartagFileCover and the
# EartagFile base class. Upstream builds EartagFile on GObject.Object so every
# tag is a GObject property the widgets can bind to; this port has no widgets
# bound to it yet, and the ruby-gtk house style drops incidental machinery
# that nothing uses, so this is a plain Ruby class instead. The parts that
# matter to callers survive: present/modified tag tracking, the abstract
# save/get_tag/set_tag/has_tag?/delete_tag contract each format backend
# implements, and a callback list (`on_modified`) in place of upstream's
# "modified" GObject signal.
#
# Cover art (upstream's EartagFileCover, GdkPixbuf thumbnails, PIL fallback)
# is not ported this round: no backend here declares `supports_album_covers`,
# so the cover accessors below are the same no-ops upstream ships for a
# format that cannot carry a picture.
module Backends
  # A single cover image's raw bytes plus its mimetype. Upstream also caches
  # GdkPixbuf thumbnails on this object for the UI; nothing in this port reads
  # covers yet, so this is the data half only (upstream's EartagFileCover).
  Cover = Struct.new(:path, :data, :mime) do
    def self.from_bytes(data, mime)
      new(nil, data, mime)
    end

    def self.from_path(path)
      Validation.mimetype(path).then do |mime|
        unless mime&.start_with?('image/')
          next nil
        end

        new(path, ::File.binread(path), mime)
      end
    end

    def save_to_path(target_path)
      if data
        ::File.binwrite(target_path, data)
      end
    end

    def ==(other)
      other.is_a?(Cover) && other.data == data
    end
  end

  # Generic base for a wrapper that provides information about a music file.
  #
  # Subclasses implement:
  #   - load_from_file(path) - reads tags from the file at the given path.
  #   - save               - saves the changes back to the file.
  #   - get_tag(name)      - reads a single tag by its property name.
  #   - set_tag(name, val) - writes a single tag by its property name.
  #   - has_tag?(name)     - whether the tag is present in the file.
  #   - delete_tag(name)   - removes the tag from the file.
  #   - delete_all_raw     - removes every tag, including ones this app
  #                          cannot read back (upstream's "clear all tags").
  #
  # Do not call get_tag/set_tag directly from outside a backend; go through
  # the named accessor (title, artist, ...) so modified-tracking stays
  # correct.
  class EartagFile
    # Tags every backend is expected to expose; a format with no tagging
    # support for one of these would not be usable, so this list is not
    # overridable the way supported_extra_tags is.
    HANDLED_PROPERTIES = Tags::BASIC_TAGS
    INT_PROPERTIES = %w[tracknumber totaltracknumber discnumber].freeze
    FLOAT_PROPERTIES = %w[bpm].freeze

    attr_reader :path, :id, :modified_tags, :original_values, :present_extra_tags
    attr_reader :error_fields

    # The extra tags this format's backend can read and write. Empty by
    # default; each backend overrides it with the subset it supports.
    def supported_extra_tags = []

    # Whether this format can carry cover art. No backend in this port sets
    # this to true yet.
    def supports_album_covers? = false

    def initialize(path)
      @path = path
      @modified_tags = []
      @original_values = {}
      @error_fields = []
      @is_modified = false
      @is_writable = false
      @has_error = false
      @releasedate_cached = nil
      @modified_callbacks = []
      @covers = {}
      @id = SecureRandom.uuid
      update_writability
    end

    def self.new_from_path(path)
      new(path).tap { |file| file.load_from_file(path) }
    end

    # Registers a block to run whenever `mark_as_modified`/`mark_as_unmodified`
    # fires. Takes the tag name (or nil for "everything was reset").
    def on_modified(&block)
      @modified_callbacks << block
    end

    def load_from_file(_path)
      raise NotImplementedError
    end

    def save
      raise NotImplementedError
    end

    def get_tag(_tag_name)
      raise NotImplementedError
    end

    def set_tag(_tag_name, _value)
      raise NotImplementedError
    end

    def has_tag?(_tag_name)
      raise NotImplementedError
    end

    def delete_tag(_tag_name)
      raise NotImplementedError
    end

    def delete_all_raw
      raise NotImplementedError
    end

    # Deletes every present tag (but not raw/unreadable data; see
    # delete_all_raw for that).
    def delete_all
      present_tags.each { |tag| delete_tag(tag) }
      if supports_album_covers?
        Tags::CoverType::ALL.each { |cover_type| delete_cover(cover_type) }
      end
    end

    def present_tags
      HANDLED_PROPERTIES.select { |tag| has_tag?(tag) } + present_extra_tags
    end

    # For performance, each file keeps a list of present extra tags, used by
    # the fileview to decide which extra-tag rows to show.
    def setup_present_extra_tags
      @present_extra_tags = supported_extra_tags.select { |tag| has_tag?(tag) }
    end

    # Snapshots the current values to compare future changes against. Call
    # after load/save and after setup_present_extra_tags.
    def setup_original_values
      @original_values = {}
      (HANDLED_PROPERTIES + present_extra_tags).uniq.each do |tag|
        value = get_property(tag)
        if (INT_PROPERTIES + FLOAT_PROPERTIES).include?(tag) && value.nil?
          original_values[tag] = 0
        else
          original_values[tag] = value
        end
      end
    end

    def update_writability
      begin
        ::File.open(path, 'a') { true }
        @is_writable = true
      rescue SystemCallError
        @is_writable = false
      end
    end

    def set_error(field, has_error)
      unless has_error
        error_fields.delete(field)
      end
      if has_error && !error_fields.include?(field)
        error_fields.push(field)
      end
      @has_error = has_error
    end

    def has_error? = @has_error
    def is_modified? = @is_modified
    def is_writable? = @is_writable

    # Reads a tag property by name, going through the named accessor so
    # type coercion (int/float tags) matches what modified-tracking expects.
    def get_property(tag) = respond_to?(tag) ? public_send(tag) : nil

    def set_property(tag, value)
      if respond_to?("#{tag}=")
        public_send("#{tag}=", value)
      end
    end

    # Moves the file on disk and reloads it in place.
    def set_path(new_path)
      if new_path == path
        nil
      else
        modifications = modified_tags.to_h { |tag| [tag, get_property(tag)] }
        FileUtils.mv(path, new_path)
        @path = new_path
        load_from_file(new_path)
        modifications.each { |tag, value| set_property(tag, value) }
      end
    end

    # Reloads the file and discards all modifications.
    def reload
      load_from_file(path)
      mark_as_unmodified
    end

    def mark_as_modified(tag)
      @is_modified = true
      emit_modified(tag)
    end

    def mark_as_unmodified
      @is_modified = false
      emit_modified(nil)
      @modified_tags = []
    end

    def mark_tag_as_unmodified(tag)
      if modified_tags.delete(tag)
        @is_modified = modified_tags.any?
        emit_modified(nil)
      else
        nil
      end
    end

    def undo_all
      modified_tags.dup.each do |tag|
        if original_values.key?(tag)
          set_property(tag, original_values[tag])
        else
          delete_tag(tag)
        end
      end
      mark_as_unmodified
    end

    def reset_to_original
      original_values.each { |tag, value| set_property(tag, value) }
      mark_as_unmodified
    end

    # Filetype extension, e.g. ".mp3".
    def filetype = ::File.extname(path)

    # Read-only info tags (Tags::INFO_TAGS); each backend's load_from_file
    # fills in @length (seconds) and @bitrate (kbps).
    def length = @length
    def bitrate = @bitrate

    # Cover art handling. No backend supports this yet (see
    # supports_album_covers?), so these are deliberately inert.

    def get_cover(cover_type) = @covers[cover_type.to_i]
    def has_cover?(cover_type) = !get_cover(cover_type).nil?
    def front_cover = get_cover(Tags::CoverType::FRONT)
    def back_cover = get_cover(Tags::CoverType::BACK)

    def delete_cover(cover_type, clear_only: false)
      @covers.delete(cover_type.to_i)
      if clear_only
        nil
      else
        mark_as_modified(cover_type.to_i == Tags::CoverType::FRONT ? 'front_cover' : 'back_cover')
      end
    end

    # -- Basic tag properties --------------------------------------------

    def title = get_tag('title')

    def title=(value)
      if value && !value.empty?
        set_tag('title', value)
        mark_as_modified('title')
      elsif has_tag?('title')
        delete_tag('title')
      end
    end

    def artist = get_tag('artist')

    def artist=(value)
      if value && !value.empty?
        set_tag('artist', value)
        mark_as_modified('artist')
      elsif has_tag?('artist')
        delete_tag('artist')
      end
    end

    def tracknumber = (v = get_tag('tracknumber')) && Misc.safe_int(v)

    def tracknumber=(value)
      if value
        set_tag('tracknumber', Misc.safe_int(value))
        mark_as_modified('tracknumber')
      else
        if has_tag?('tracknumber')
          delete_tag('tracknumber')
        end
      end
    end

    def totaltracknumber = (v = get_tag('totaltracknumber')) && Misc.safe_int(v)

    def totaltracknumber=(value)
      if value
        set_tag('totaltracknumber', Misc.safe_int(value))
        mark_as_modified('totaltracknumber')
      else
        if has_tag?('totaltracknumber')
          delete_tag('totaltracknumber')
        end
      end
    end

    def album = get_tag('album')

    def album=(value)
      if value && !value.empty?
        set_tag('album', value)
        mark_as_modified('album')
      elsif has_tag?('album')
        delete_tag('album')
      end
    end

    def albumartist = get_tag('albumartist')

    def albumartist=(value)
      if value && !value.empty?
        set_tag('albumartist', value)
        mark_as_modified('albumartist')
      elsif has_tag?('albumartist')
        delete_tag('albumartist')
      end
    end

    def genre = get_tag('genre')

    def genre=(value)
      if value && !value.empty?
        set_tag('genre', value)
        mark_as_modified('genre')
      elsif has_tag?('genre')
        delete_tag('genre')
      end
    end

    # Release dates get custom handling: an invalid value does not get
    # written to the file, only kept around so the entry does not snap back
    # to the old value while the user is still typing.
    DATE_FORMATS = [
      /\A\d{4}\z/,
      /\A\d{4}-\d{2}\z/,
      /\A\d{4}-\d{2}-\d{2}\z/,
    ].freeze

    def validate_date(field, value)
      if value.nil? || value.empty?
        set_error(field, false)
      else
        if value.include?('-')
          has_error = DATE_FORMATS.none? { |fmt| fmt.match?(value) }
        else
          has_error = false
        end
        set_error(field, has_error)
      end
    end

    def releasedate
      if @releasedate_cached.nil? && has_tag?('releasedate')
        value = get_tag('releasedate')
        if value && value.length > 10
          value = value[0, 10]
        end
        @releasedate_cached = value
      end
      @releasedate_cached
    end

    def releasedate=(value)
      validate_date('releasedate', value)
      @releasedate_cached = value
      unless error_fields.include?('releasedate')
        if value && !value.empty?
          set_tag('releasedate', value)
        elsif has_tag?('releasedate')
          @releasedate_cached = nil
          delete_tag('releasedate')
        end
      end
      mark_as_modified('releasedate')
    end

    def comment = get_tag('comment')

    def comment=(value)
      if value && !value.empty?
        set_tag('comment', value)
        mark_as_modified('comment')
      elsif has_tag?('comment')
        delete_tag('comment')
      end
    end

    # -- Extra tag properties ---------------------------------------------
    #
    # Every extra tag follows the same shape as upstream: read/write only if
    # the backend lists it in supported_extra_tags, otherwise always nil. A
    # loop generates the accessors rather than repeating the same six lines
    # once per tag, the way upstream has to (Python has no equivalent of
    # define_method).

    (Tags::EXTRA_TAGS - %w[bpm discnumber]).each do |tag|
      define_method(tag) do
        if supported_extra_tags.include?(tag)
          get_tag(tag)
        end
      end

      define_method("#{tag}=") do |value|
        unless supported_extra_tags.include?(tag)
          next
        end

        if value && !value.to_s.empty?
          set_tag(tag, value)
          mark_as_modified(tag)
        elsif has_tag?(tag)
          delete_tag(tag)
        end
      end
    end

    def bpm
      if supported_extra_tags.include?('bpm')
        (v = get_tag('bpm')) && Misc.safe_float(v)
      else
        nil
      end
    end

    def bpm=(value)
      if supported_extra_tags.include?('bpm')
        if value
          set_tag('bpm', Misc.safe_float(value))
          mark_as_modified('bpm')
        elsif has_tag?('bpm')
          delete_tag('bpm')
        end
      else
        nil
      end
    end

    def discnumber
      if supported_extra_tags.include?('discnumber')
        (v = get_tag('discnumber')) && Misc.safe_int(v)
      else
        nil
      end
    end

    def discnumber=(value)
      if supported_extra_tags.include?('discnumber')
        if value
          set_tag('discnumber', Misc.safe_int(value))
          mark_as_modified('discnumber')
        elsif has_tag?('discnumber')
          delete_tag('discnumber')
        end
      else
        nil
      end
    end

    private

      def emit_modified(tag)
        if tag
          update_modified_tags(tag)
        end

        if modified_tags.empty?
          @is_modified = false
        end
        @modified_callbacks.each { |callback| callback.call(tag) }
      end

      def update_modified_tags(tag)
        if supported_extra_tags.include?(tag)
          if get_property(tag) && !present_extra_tags.include?(tag)
            present_extra_tags.push(tag)
          elsif !get_property(tag)
            present_extra_tags.delete(tag)
          end
        end

        new_value = get_property(tag)
        if original_values.key?(tag)
          old_value = original_values[tag]
          if old_value == new_value || (!old_value && !new_value)
            modified_tags.delete(tag)
          elsif !modified_tags.include?(tag)
            modified_tags.push(tag)
          end
        elsif !new_value
          modified_tags.delete(tag)
        elsif !modified_tags.include?(tag)
          modified_tags.push(tag)
        end
      end
  end
end
