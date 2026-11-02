# frozen_string_literal: true

require 'adwaita'
require_relative 'tags'

# PlaceholderSyntaxHighlighter colours the tag placeholders in a pattern, so
# "{tracknumber} {title} - {artist}" reads as three tags and two separators
# rather than as a line of punctuation.
#
# Ported from upstream's src/utils/tagsyntaxhighlight.py. It attaches to an
# entry (whose buffer it watches for insertions and deletions) or to a label
# (whose label property it watches), re-colours the text on every change, and
# exposes an `error?` flag the rename and extract dialogs use to refuse an
# unparseable pattern.
#
# The colours are upstream's: the GNOME palette's _5 shades on light
# backgrounds and the _1 shades on dark ones, cycled per placeholder, with the
# braces themselves in a dimmer colour.
#
# Pango counts attribute offsets in bytes, so, like upstream, the matching
# happens on the UTF-8 bytes of the text rather than on its characters.
#
class PlaceholderSyntaxHighlighter
  THEMES = {
    'light' => {
      bracket_color:      [61, 56, 70],
      placeholder_colors: [
        [26, 95, 180],   # @blue_5
        [38, 162, 105],  # @green_5
        [229, 165, 10],  # @yellow_5
        [198, 70, 0],    # @orange_5
        [165, 29, 45],   # @red_5
        [97, 53, 131],   # @purple_5
        [99, 69, 44],    # @brown_5
      ],
    },
    'dark'  => {
      bracket_color:      [154, 153, 150],
      placeholder_colors: [
        [153, 193, 241], # @blue_1
        [143, 240, 164], # @green_1
        [249, 240, 107], # @yellow_1
        [255, 190, 111], # @orange_1
        [246, 97, 81],   # @red_1
        [220, 138, 221], # @purple_1
        [181, 131, 90],  # @brown_2
      ],
    },
  }.freeze

  # Matched against the pattern's bytes, so the offsets Pango is handed are
  # byte offsets.
  PLACEHOLDER_PATTERN = /\{.*?\}/n

  attr_reader :widget, :widget_type, :allow_duplicates, :theme

  def initialize(widget, widget_type: :entry, allow_duplicates: false)
    @widget = widget
    @widget_type = widget_type
    @allow_duplicates = allow_duplicates
    @error = false
    @error_handlers = []
    @theme = 'light'
    @high_contrast = false
  end

  # Sets up syntax highlighting for the widget. Upstream does this in its
  # constructor; here it is a separate call, so the highlighter can be built
  # before the widget it watches is in a window.
  def build
    tap do
      connect_widget
      style_manager.tap do |manager|
        manager.signal_connect('notify::dark') { update_theme }
        manager.signal_connect('notify::high-contrast') { update_theme }
      end
      update_theme
    end
  end

  def error? = @error

  def high_contrast? = @high_contrast

  # Connects a block that runs whenever the pattern's validity changes.
  def connect_error(&block)
    @error_handlers.push(block)
    self
  end

  def text
    if widget_type == :label
      widget.label.to_s
    else
      widget.text.to_s
    end
  end

  def update_theme
    @high_contrast = style_manager.high_contrast?
    if style_manager.dark?
      @theme = 'dark'
    else
      @theme = 'light'
    end
    update_syntax_highlighting
  end

  # Re-colours the pattern. full_text overrides the widget's own text, which is
  # how a deletion is handled: the buffer still holds the old text when the
  # signal arrives.
  def update_syntax_highlighting(full_text = nil)
    Pango::AttrList.new.tap do |attrs|
      highlight(attrs, (full_text || text).dup.force_encoding(Encoding::ASCII_8BIT))
      widget.set_attributes(attrs)
    end
  end

  private

    def style_manager = @style_manager ||= Adwaita::StyleManager.default

    def connect_widget
      if widget_type == :label
        widget.signal_connect('notify::label') { update_syntax_highlighting(widget.label.to_s) }
      else
        connect_entry
      end
    end

    def connect_entry
      widget.delegate.buffer.tap do |buffer|
        buffer.signal_connect('inserted-text') { update_syntax_highlighting }
        buffer.signal_connect('deleted-text') do |_buffer, position, n_chars|
          update_syntax_highlighting(text_without(position, n_chars))
        end
      end
    end

    # The text as it will be once the deletion the signal reports is applied.
    def text_without(position, n_chars)
      text.dup.tap { |full_text| full_text[position, n_chars] = '' }
    end

    # Walks the placeholders, inserting the bracket and tag colours, and
    # records whether the pattern contains anything unparseable.
    def highlight(attrs, full_text)
      error = false
      present_tags = []
      index = 0

      position = 0
      while (match = PLACEHOLDER_PATTERN.match(full_text, position))
        position = match.end(0)
        tag_name = match[0][1..-2].to_s
        if tag_name.include?('{') || tag_name.include?('}')
          error = true
        elsif colorable?(tag_name, present_tags)
          present_tags.push(tag_name)
          insert_bracket_colors(attrs, match)
          insert_tag_color(attrs, match, index)
          index += 1
        end
      end

      set_error(error)
    end

    def colorable?(tag_name, present_tags)
      !tag_name.empty? &&
        Tags.extractable?(tag_name) &&
        (allow_duplicates || !present_tags.include?(tag_name))
    end

    def insert_bracket_colors(attrs, match)
      [match.begin(0), match.end(0) - 1].each do |position|
        attrs.insert(foreground_attr(colors.fetch(:bracket_color), position, position + 1))
      end
    end

    def insert_tag_color(attrs, match, index)
      placeholder_colors.then do |palette|
        attrs.insert(
          foreground_attr(
            palette[index % palette.length],
            match.begin(0) + 1,
            match.end(0) - 1,
          ),
        )
      end
    end

    def colors = THEMES.fetch(theme)

    def placeholder_colors = colors.fetch(:placeholder_colors)

    # Pango takes its colour components as 16-bit values.
    def foreground_attr(color, start_index, end_index)
      Pango.attr_foreground_new(color[0] * 256, color[1] * 256, color[2] * 256).tap do |attr|
        attr.start_index = start_index
        attr.end_index = end_index
      end
    end

    def set_error(error)
      unless @error == error
        @error = error
        @error_handlers.each { |handler| handler.call(self, error) }
      end
    end
end
