# frozen_string_literal: true

require_relative 'validation'
require_relative 'backends/file'
require_relative 'backends/file_id3'
require_relative 'backends/file_vorbis'
require_relative 'backends/file_mp4'

# FileManager holds the collection of files Ear Tag currently has open:
# picking the right backend for a path, tracking which of the open files are
# modified or have an error, and saving/removing them.
#
# Ported from upstream's src/filemanager.py — EartagFileManager plus its
# module-level eartagfile_from_path helper. Upstream's version also owns the
# Gio::ListStore/Gtk::SortListModel/Gtk::FilterListModel/Gtk::MultiSelection
# chain that feeds the file list view, and a 3-worker async task queue for
# loading/saving/renaming in the background; none of that has anywhere to
# attach yet (lib/file_list.rb is not written this round), so this is the
# model half only: a plain Ruby Array of open files plus the aggregate
# is_modified?/has_error? bookkeeping upstream derives from it. The list/sort/
# filter/selection models belong with whichever round ports the file list.
module FileManager
  # The audio mimetypes (content-sniffed, see Validation) each backend
  # understands. Checked in this order; the first match wins.
  BACKEND_FOR_MIME = {
    'audio/mp3'          => Backends::Id3File,
    'audio/mpeg'         => Backends::Id3File,
    'audio/x-mp3'        => Backends::Id3File,
    'audio/x-mpeg'       => Backends::Id3File,

    'audio/flac'         => Backends::VorbisFile,
    'audio/x-flac'       => Backends::VorbisFile,
    'audio/ogg'          => Backends::VorbisFile,
    'application/ogg'    => Backends::VorbisFile,
    'application/x-ogg'  => Backends::VorbisFile,
    'audio/x-vorbis+ogg' => Backends::VorbisFile,

    'audio/mp4'          => Backends::Mp4File,
    'audio/x-m4a'        => Backends::Mp4File,
    'audio/aac'          => Backends::Mp4File,
    'video/mp4'          => Backends::Mp4File,
  }.freeze

  # taglib-ruby has no WMA/ASF binding (see lib/backends), so unlike
  # upstream, which ships a fourth backend for audio/x-ms-wma and friends,
  # that mimetype has nowhere to go and is left out of BACKEND_FOR_MIME.

  class UnsupportedFileError < StandardError; end

  module_function

  # Returns the backend class for the file at the given path, raising
  # UnsupportedFileError when the format is not one of the three backends
  # above support (matches upstream's eartagfile_from_path, minus the WMA
  # branch: see the note above BACKEND_FOR_MIME).
  def backend_for(path)
    BACKEND_FOR_MIME.fetch(Validation.mimetype(path)) do
      raise UnsupportedFileError, "Unsupported file format for file #{path}"
    end
  end

  # Loads the file at the given path through the right backend.
  def file_from_path(path)
    unless ::File.exist?(path)
      raise UnsupportedFileError, "No such file: #{path}"
    end

    backend_for(path).new_from_path(path)
  end

  # Holds the set of files currently open in the app and the aggregate state
  # (is_modified?/has_error?) the window's title and save button read.
  class Manager
    attr_reader :files

    def initialize
      @files = []
      @modified_file_ids = []
      @error_file_ids = []
    end

    def is_modified? = @modified_file_ids.any?
    def has_error? = @error_file_ids.any?

    # Opens the file at path (unless it is already open) and starts
    # tracking its modified/error state.
    def add_path(path)
      if files.any? { |file| file.path == path }
        files.find { |file| file.path == path }
      else
        FileManager.file_from_path(path).tap { |file| add_file(file) }
      end
    end

    def add_file(file)
      files.push(file)
      file.on_modified { update_modified_status(file) }
      update_modified_status(file)
      update_error_status(file)
      file
    end

    def remove(file)
      files.delete(file)
      @modified_file_ids.delete(file.id)
      @error_file_ids.delete(file.id)
    end

    def remove_all
      files.dup.each { |file| remove(file) }
    end

    # Saves every modified file, returning the ones that failed to save
    # along with the error that was raised.
    def save_all
      files.select(&:is_modified?).filter_map do |file|
        begin
          file.save
          nil
        rescue StandardError => e
          Log.error("Failed to save #{file.path}: #{e.message}")
          [file, e]
        end
      end
    end

    def update_modified_status(file)
      if file.is_modified? && !@modified_file_ids.include?(file.id)
        @modified_file_ids.push(file.id)
      elsif !file.is_modified?
        @modified_file_ids.delete(file.id)
      end
    end

    def update_error_status(file)
      if file.has_error? && !@error_file_ids.include?(file.id)
        @error_file_ids.push(file.id)
      elsif !file.has_error?
        @error_file_ids.delete(file.id)
      end
    end
  end
end
