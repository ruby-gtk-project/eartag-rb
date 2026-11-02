# frozen_string_literal: true

# The support layer: the tag vocabulary and the helpers the widgets are built
# on. They are required here rather than from the widgets that use them, so
# that loading the app loads the whole port.
require_relative 'logger'
require_relative 'misc'
require_relative 'validation'
require_relative 'tags'
require_relative 'extract_tags'
require_relative 'entry_limiters'
require_relative 'async_task'
require_relative 'placeholder_syntax_highlighter'

require_relative 'eartag/application'
