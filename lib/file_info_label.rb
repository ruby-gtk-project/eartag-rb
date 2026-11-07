# frozen_string_literal: true

require 'gtk4'

require_relative 'misc'

# EartagFileInfoLabel: the dim, numeric label in the file view that shows
# length / bitrate / channels / filetype for the file(s) currently selected.
#
# Ported from upstream's src/fileview.py — EartagFileInfoLabel. Upstream
# tracks a `set` of bound files (so the same file bound twice is still one
# file) and shows "(Multiple files selected)" once more than one is bound;
# this keeps that shape with a plain Ruby Array deduplicated by object
# identity, since EartagFile has no `==` override to lean on.
class FileInfoLabel < Gtk::Label
  def build
    tap do
      add_css_class('dim-label')
      add_css_class('numeric')
      refresh_label
    end
  end

  def bind_to_files(files)
    @files = (bound_files | files)
    refresh_label
  end

  def unbind_from_files(files)
    @files = bound_files - files
    refresh_label
  end

  def refresh_label
    case bound_files.size
    when 0 then self.label = ''
    when 1 then self.label = info_label_for(bound_files.first)
    else self.label = '(Multiple files selected)'
    end
  end

  private

    def bound_files = @files ||= []

    def info_label_for(file)
      format(
        '%<length>s • %<bitrate>s kbps • %<channels>s • %<filetype>s',
        length: Misc.readable_length(file.length.to_i),
        bitrate: file.bitrate&.positive? ? file.bitrate.to_s : 'N/A',
        channels: channels_readable(file.channels),
        filetype: file.filetype,
      )
    end

    def channels_readable(channels)
      case channels
      when 0 then 'N/A'
      when 1 then 'Mono'
      when 2 then 'Stereo'
      else "#{channels} channels"
      end
    end
end
