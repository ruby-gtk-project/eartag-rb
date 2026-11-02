# frozen_string_literal: true

require_relative 'tags'

# ExtractTags turns a filename into tag values, using a pattern like
# "{tracknumber} {title} - {artist}".
#
# A direct port of upstream's src/utils/extracttags.py. The pattern is split
# into static text and placeholders, the placeholders become named capture
# groups, and the resulting regex is matched against the file's basename.
#
# Upstream encodes both the pattern and the filename to UTF-8 before matching,
# because the returned group positions feed Pango attributes, and Pango counts
# offsets in bytes rather than characters. The same trick works here: matching
# binary strings makes Ruby's offsets byte offsets too.
#
module ExtractTags
  module_function

  # Takes a filename and a placeholder string and splits the filename up into
  # a hash of tag data.
  #
  # positions: return [value, [start, end]] pairs instead of bare values, with
  #   the span measured in bytes.
  # strip_common_suffixes: remove the suffixes found in filenames of downloaded
  #   files before matching.
  def extract_tags_from_filename(filename, placeholder,
                                 positions: false, strip_common_suffixes: false)
    basename = ::File.basename(filename.to_s, '.*')
    if strip_common_suffixes
      basename = strip_suffixes(basename)
    end

    pattern, tags = build_pattern(placeholder)
    match = pattern.match(basename.dup.force_encoding(Encoding::ASCII_8BIT))

    if match
      collect(match, tags, positions: positions)
    else
      {}
    end
  end

  # Strip the suffixes download tools leave on filenames.
  def strip_suffixes(filename)
    strip_youtube_dl_id(strip_bracketed_id(filename))
  end

  # Modern yt-dlp: square brackets with the ID inside. The ID could be a
  # YouTube ID, or longer for e.g. SoundCloud, so its length is not limited.
  def strip_bracketed_id(filename)
    if filename.end_with?(']')
      filename.match(/\A(.*?) \[(.*)\]/)&.captures&.first.then do |stripped|
        if stripped.nil? || stripped.empty?
          filename
        else
          stripped
        end
      end
    else
      filename
    end
  end

  # Old youtube-dl: "-" and then the YouTube ID. To minimize the likelihood of
  # misdetections, only IDs that have numbers or special characters in them are
  # recognised.
  def strip_youtube_dl_id(filename)
    if filename[-12..].to_s.match?(/\A-[A-Za-z0-9_-]{11}\z/) &&
       filename[-11..].to_s.match?(/[0-9_-]/)
      filename[0..-13]
    else
      filename
    end
  end

  # Builds the regex for a placeholder string, and the list of tags it captures.
  # A placeholder that is not a known tag, or that repeats one already
  # captured, is treated as static text — the same fallback upstream has.
  def build_pattern(placeholder)
    tags = []
    pattern = String.new('\A', encoding: Encoding::ASCII_8BIT)

    split_placeholder(placeholder).each do |element|
      tag = placeholder_tag(element)
      if tag && Tags.extractable?(tag) && !tags.include?(tag)
        tags.push(tag)
        pattern << "(?<#{tag}>.*?)".b
      else
        pattern << Regexp.escape(element).b
      end
    end

    [Regexp.new("#{pattern}\\z".b), tags]
  end

  # Splits a placeholder string into its static strings and its placeholders,
  # dropping the empty pieces the split leaves behind.
  def split_placeholder(placeholder)
    placeholder.to_s.split(/(\{.*?\})/).reject(&:empty?)
  end

  def placeholder_tag(element)
    if element.start_with?('{') && element.end_with?('}')
      element[1..-2]
    end
  end

  def collect(match, tags, positions: false)
    tags.each_with_object({}) do |tag, out|
      value = match[tag]
      unless value.nil? || value.empty?
        out[tag] = tag_result(
          match,
          tag,
          value,
          positions: positions,
        )
      end
    end
  end

  def tag_result(match, tag, value, positions: false)
    if positions
      [value.dup.force_encoding(Encoding::UTF_8), match.offset(tag)]
    else
      value.dup.force_encoding(Encoding::UTF_8)
    end
  end
end
