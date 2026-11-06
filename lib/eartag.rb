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

# The model layer: the file backends and the manager that tracks which files
# are currently open. Required here for the same reason as the support layer
# above — loading the app loads the whole port, not just the parts the
# window has been wired up to reach so far.
require_relative 'backends/file'
require_relative 'backends/file_id3'
require_relative 'backends/file_vorbis'
require_relative 'backends/file_mp4'
require_relative 'file_manager'

require_relative 'eartag/application'
