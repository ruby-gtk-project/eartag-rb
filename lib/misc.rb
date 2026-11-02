# frozen_string_literal: true

require 'pathname'

# Misc holds the small helpers the rest of the app shares.
#
# A direct port of upstream's src/utils/misc.py. Everything there is a module
# level function, so everything here is a module function; the names follow
# Ruby convention (`is_float` becomes `float?`, `get_readable_length` becomes
# `readable_length`) but the behaviour, including the odd corners, is the
# upstream behaviour.
#
# `inspect_prettyprint` is deliberately missing: upstream says in its docstring
# that it is not used anywhere in the program and only exists for debugging.
#
module Misc
  # https://stackoverflow.com/questions/1976007/what-characters-are-forbidden-in-windows-and-linux-directory-names
  FILENAME_BANNED_CHARS = ['/', '\\', ':', '*', '?', '"', '<', '>', '|', "\t"].freeze

  BANNED_FILENAMES = %w[
    CON PRN AUX NUL
    COM1 COM2 COM3 COM4 COM5 COM6 COM7 COM8 COM9
    LPT1 LPT2 LPT3 LPT4 LPT5 LPT6 LPT7 LPT8 LPT9
  ].freeze

  SEPARATOR = File::SEPARATOR

  module_function

  # Check if all elements in a list are equal.
  def all_equal(iterable)
    iterable.to_a.uniq.length <= 1
  end

  # Gets the position of an item in the model, or -1 if not found.
  # Replacement for the .find function in models that don't have it.
  def find_in_model(model, item)
    found = -1
    i = 0
    while found.negative?
      current = model.get_item(i)
      if current.nil?
        found = -1
        break
      end
      if current == item
        found = i
      end
      i += 1
    end
    found
  end

  # Checks if the given value is a valid float.
  def float?(value)
    !Float(value.to_s, exception: false).nil?
  end

  # Returns human-readable version of the length, given in seconds.
  def readable_length(length)
    length_min, length_sec = length.to_i.divmod(60)
    length_hour, length_min = length_min.divmod(60)

    if length_hour.zero?
      format('%<m>02d∶%<s>02d', m: length_min, s: length_sec)
    else
      format('%<h>02d∶%<m>02d∶%<s>02d', h: length_hour, m: length_min, s: length_sec)
    end
  end

  # Capitalizes every word, except the ones that are already all-uppercase.
  def title_case_preserve_uppercase(text)
    text.split(' ').map { |word| word_title_case(word) }.join(' ')
  end

  def word_title_case(word)
    if word == word.upcase && word.match?(/[[:alpha:]]/)
      word
    else
      word.capitalize
    end
  end

  # Returns a "simplified string" that throws away non-alphanumeric characters
  # for more accurate searches and comparisons.
  def simplify_string(text)
    text.unicode_normalize(:nfkc)
        .downcase
        .each_char
        .select { |letter| letter.match?(/[[:alnum:]]/) || letter == ' ' }
        .join
        .strip
        .gsub(/ +/, ' ')
  end

  # Compares simplified representations of two strings.
  def simplify_compare(string1, string2)
    simplify_string(string1) == simplify_string(string2)
  end

  def reg_and_simple_cmp(string1, string2)
    string1 == string2 || simplify_compare(string1, string2)
  end

  # Takes a filename or path and returns a cleaned up version (that is, one
  # where invalid characters or tricks like ../ are ignored).
  def cleanup_filename(filename, allow_path: false, full_path: false)
    paths_allowed = allow_path || full_path
    cleaned = filename.dup
    banned_chars(allow_path: paths_allowed).each { |char| cleaned = cleaned.gsub(char, '_') }

    if full_path
      out = SEPARATOR.dup
    else
      if cleaned.start_with?(SEPARATOR)
        cleaned = cleaned[1..]
      end
      out = String.new
    end

    parts = cleaned.split(SEPARATOR, -1)
    parts.each_with_index do |part, index|
      stripped = part.strip
      unless stripped.empty?
        out << cleanup_filename_part(stripped, last: index == parts.length - 1)
        out << SEPARATOR
      end
    end

    out[0..-2].to_s
  end

  # Fixes a single path component: length, reserved names and trailing dots.
  def cleanup_filename_part(part, last: false)
    shortened = shorten_filename_part(part, last: last)

    if BANNED_FILENAMES.include?(shortened)
      "_#{shortened}"
    elsif shortened == '..'
      '__'
    elsif shortened.end_with?('.')
      "#{shortened[0..-2]}_"
    else
      shortened
    end
  end

  # 255 is a common limit, so upstream cuts at 249 to leave some space for
  # safety, keeping the extension when the component is the filename itself.
  def shorten_filename_part(part, last: false)
    if part.length <= 249
      part
    elsif last
      File.extname(part).then { |ext| part.delete_suffix(ext)[(-249 + ext.length - 1)..] + ext }
    else
      part[-249..]
    end
  end

  # Returns whether or not a filename is valid.
  def filename_valid?(filename, allow_path: false, full_path: false)
    checks = [
      filename == Pathname.new(filename).cleanpath.to_s,
      full_path || !filename.start_with?(SEPARATOR),
      banned_chars(allow_path: allow_path || full_path).none? { |char| filename.include?(char) },
      filename.split(SEPARATOR, -1).all? { |part| filename_part_valid?(part) },
    ]
    checks.all?
  end

  def filename_part_valid?(part)
    !(BANNED_FILENAMES.include?(part) ||
      part == '..' ||
      part.end_with?('.') ||
      part != part.strip ||
      part.length > 255)
  end

  def banned_chars(allow_path: false)
    if allow_path
      FILENAME_BANNED_CHARS - [SEPARATOR]
    else
      FILENAME_BANNED_CHARS
    end
  end

  # Takes a path and returns whether or not the file is sandboxed. This is a
  # best-guess based on the path, and has only really been tested to work
  # under Flatpak.
  def file_sandboxed?(path)
    path.to_s.match?(%r{^/run/user/[0-9].*/doc})
  end

  # Compares two strings using the "natural/human sorting" algorithm, returning
  # 0 if both strings are the same, 1 if a > b and -1 if a < b — the same
  # constraints GLib's collate functions satisfy.
  def natural_compare(first, second)
    natural_key(first) <=> natural_key(second)
  end

  def natural_key(text)
    text.split(/([0-9]+)/).map { |chunk| natural_key_chunk(chunk) }
  end

  def natural_key_chunk(chunk)
    if chunk.match?(/\A[0-9]+\z/)
      [0, chunk.to_i, '']
    else
      [1, 0, chunk.downcase]
    end
  end

  # Wrapper around Integer() that handles invalid values gracefully.
  def safe_int(value)
    if value.is_a?(Integer)
      value
    else
      Integer(value.to_s.strip, exception: false) || 0
    end
  end

  # Wrapper around Float() that handles invalid values gracefully.
  def safe_float(value)
    if value.is_a?(Float)
      value
    else
      Float(value.to_s.strip, exception: false) || 0.0
    end
  end

  # The selected items of a selection model, either from the whole selection or
  # from the given range. Upstream yields them one at a time; here they come
  # back as an array, which is the Ruby equivalent and is what every caller in
  # the app does with them anyway.
  def selected_items(model, position: -1, n_items: -1)
    if (position >= 0 && n_items.negative?) || (n_items >= 0 && position.negative?)
      raise ArgumentError, 'Both position and n_items must be set'
    end

    selection_range(model, position, n_items).then do |selection|
      (0...selection.size).map { |i| model.get_item(selection.nth(i)) }
    end
  end

  def selection_range(model, position, n_items)
    if position >= 0 && n_items >= 0
      model.get_selection_range(position, n_items)
    else
      model.selection
    end
  end
end
