# frozen_string_literal: true

require 'gtk4'
require_relative 'tags'

# AlbumCoverImage shows a file's front or back cover, falling back to a
# generic "folder-music" placeholder when the file has none.
#
# Ported from upstream's src/utils/widgets.py — EartagAlbumCoverImage, a
# Gtk.Stack that switches between a placeholder icon and the loaded cover.
# Upstream reads two pre-rendered pixbuf sizes off the file's cover object
# (cover_small/cover_large) depending on how big the image widget is; this
# port decodes the cover's raw bytes through GdkPixbuf::PixbufLoader instead,
# since no backend caches a scaled pixbuf yet (see lib/backends/file.rb).
# No shipped backend currently sets supports_album_covers?, so bind_to_file
# always lands on the placeholder today; this is written against the
# Backends::EartagFile#front_cover/back_cover contract so it starts showing
# real art the moment a backend grows cover support, with no change needed
# here.
class AlbumCoverImage < Gtk::Stack
  def initialize
    super()
    self.add_css_class('cover-image')
    self.hexpand = true
    self.accessible_role = :presentation
    @file = nil
    @cover_type = Tags::CoverType::FRONT
    @pixel_size = 196
  end

  def build
    tap do |stack|
      stack.add_named(no_cover, 'no_cover')
      stack.add_named(cover_image, 'cover_image')
      stack.visible_child_name = 'no_cover'
    end
  end

  def no_cover
    @no_cover ||= Gtk::Image.new.tap do |i|
      i.icon_name = 'folder-music-symbolic'
      i.pixel_size = 96
      i.halign = :center
      i.valign = :center
      i.accessible_role = :presentation
    end
  end

  def cover_image
    @cover_image ||= Gtk::Image.new.tap do |i|
      i.hexpand = true
      i.vexpand = true
      i.pixel_size = 196
      i.overflow = :hidden
      i.accessible_role = :presentation
    end
  end

  attr_reader :file, :cover_type

  def cover_type=(value)
    @cover_type = value
    on_cover_change
  end

  def pixel_size = @pixel_size

  def pixel_size=(value)
    @pixel_size = value
    cover_image.pixel_size = value
    if value < 100
      no_cover.pixel_size = value > 28 ? 24 : value - 4
    else
      no_cover.pixel_size = 96
    end
  end

  def is_empty? = visible_child_name == 'no_cover'

  # Binds to a file, swapping out whatever file was previously bound.
  def bind_to_file(file)
    unbind_from_file if @file
    @file = file
    on_cover_change
  end

  def unbind_from_file(file = nil)
    if @file && !(file && file != @file)
      @file = nil
      mark_as_empty
    end
  end

  def mark_as_empty
    self.visible_child_name = 'no_cover'
  end

  def mark_as_nonempty
    on_cover_change
  end

  private

    def on_cover_change
      if @file
        cover = @cover_type == Tags::CoverType::FRONT ? @file.front_cover : @file.back_cover

        pixbuf = cover&.data && pixbuf_for(cover)
        if pixbuf
          cover_image.set_from_pixbuf(pixbuf)
          self.visible_child_name = 'cover_image'
        else
          mark_as_empty
        end
      else
        mark_as_empty
      end
    end

    def pixbuf_for(cover)
      GdkPixbuf::PixbufLoader.new.tap do |loader|
        loader.write(cover.data)
        loader.close
      end.pixbuf
    rescue GLib::Error
      nil
    end
end
