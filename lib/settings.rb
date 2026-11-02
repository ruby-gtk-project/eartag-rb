# frozen_string_literal: true

require 'json'
require 'fileutils'

# DLCoverSize is the size of cover art downloaded from the Cover Art Archive.
#
# Ported from upstream's src/config.py. The values are pixel sizes, so the enum
# member doubles as the number handed to the download URL, with 0 standing for
# "do not download covers". The index conversions exist because the
# preferences dialog shows the choices in a combo row, which knows only
# positions.
#
module DLCoverSize
  NO_DOWNLOAD = 0
  SIZE_250PX = 250
  SIZE_500PX = 500
  SIZE_1200PX = 1200
  MAX_SIZE = 2000

  ITEMS = [NO_DOWNLOAD, SIZE_250PX, SIZE_500PX, SIZE_1200PX, MAX_SIZE].freeze

  # The labels upstream's settings.blp lists in its combo row, and the nicks
  # of the dlcoversize enum in its GSettings schema.
  LABELS = [
    'Do not download covers',
    '250 px',
    '500 px',
    '1200 px',
    'Maximum size',
  ].freeze

  module_function

  def index_to_item(index)
    ITEMS.fetch(index)
  end

  def item_to_index(item)
    ITEMS.index(item.to_i) || raise(ArgumentError, "#{item} is not a cover size")
  end
end

# Settings holds the same keys as upstream's app.drey.EarTag GSettings schema
# (data/app.drey.EarTag.gschema.xml.in).
#
# Upstream uses GSettings, which needs a compiled schema installed into the
# system's glib-2.0/schemas directory. Requiring an install step to run the app
# from a checkout is worse than the alternative, so the same keys, defaults and
# semantics are backed by a small JSON file under XDG_CONFIG_HOME instead —
# including the two ranges the schema declares, which are clamped on write the
# way GSettings would refuse an out-of-range value.
#
class Settings
  DEFAULTS = {
    'open-folders-recursively'        => false,
    'rename-placeholder'              => '{tracknumber} {title} - {artist}',
    'rename-base-folder'              => '',
    'musicbrainz-confidence-treshold' => 85,
    'acoustid-confidence-treshold'    => 85,
    'musicbrainz-cover-size'          => DLCoverSize::SIZE_1200PX,
    'extract-pattern'                 => '{tracknumber} {title} - {artist}',
    'extract-strip-common-suffixes'   => true,
  }.freeze

  # The <range min="0" max="100"/> the schema puts on the two tresholds.
  RANGES = {
    'musicbrainz-confidence-treshold' => (0..100),
    'acoustid-confidence-treshold'    => (0..100),
  }.freeze

  def initialize(path: nil)
    @path = path || default_path
    @values = DEFAULTS.merge(read)
  end

  def [](key) = @values.fetch(key.to_s, DEFAULTS[key.to_s])

  def []=(key, value)
    @values[key.to_s] = clamp(key.to_s, value)
    write
    @values[key.to_s]
  end

  def location = @path

  # Named accessors for the keys the app reads most, so callers do not repeat
  # the string keys.
  DEFAULTS.each_key do |key|
    method_name = key.tr('-', '_')
    define_method(method_name) { self[key] }
    define_method(:"#{method_name}=") { |value| self[key] = value }
    if DEFAULTS[key].is_a?(TrueClass) || DEFAULTS[key].is_a?(FalseClass)
      define_method(:"#{method_name}?") { self[key] == true }
    end
  end

  # The cover size as a combo row position, and back.
  def cover_size_index = DLCoverSize.item_to_index(self['musicbrainz-cover-size'])

  def cover_size_index=(index)
    self['musicbrainz-cover-size'] = DLCoverSize.index_to_item(index)
  end

  private

    def clamp(key, value)
      RANGES[key].then do |range|
        if range
          value.to_i.clamp(range.first, range.last)
        else
          value
        end
      end
    end

    def default_path
      ::File.join(
        ENV.fetch('XDG_CONFIG_HOME', ::File.expand_path('~/.config')),
        'eartag-rb',
        'settings.json',
      )
    end

    def read
      if ::File.exist?(@path)
        JSON.parse(::File.read(@path))
      else
        {}
      end
    rescue JSON::ParserError => e
      warn "Error parsing #{@path}: #{e.message}"
      {}
    end

    def write
      FileUtils.mkdir_p(::File.dirname(@path))
      ::File.write(@path, JSON.pretty_generate(@values))
    end
end
