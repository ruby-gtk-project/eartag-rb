# frozen_string_literal: true

# Tags is the tag vocabulary: which tags Ear Tag knows about, what they are
# called in the interface, and which cover slots a file can carry.
#
# Ported from the data tables at the top of upstream's src/backends/file.py —
# BASIC_TAGS, EXTRA_TAGS, VALID_TAGS, CoverType and TAG_NAMES. Upstream keeps
# them next to the EartagFile base class because that class generates one
# property per tag; here they stand on their own, because the pattern entry,
# the tag selector and the extraction engine all need the vocabulary whether or
# not a file is open.
#
# The names are the translatable strings from upstream, with upstream's
# TRANSLATORS comments kept: they explain the ones a translator cannot guess.
#
module Tags
  BASIC_TAGS = %w[
    title artist album albumartist tracknumber
    totaltracknumber genre releasedate comment
  ].freeze

  EXTRA_TAGS = %w[
    bpm compilation composer copyright encodedby
    mood conductor arranger discnumber publisher
    isrc language discsubtitle url

    albumartistsort albumsort composersort artistsort
    titlesort

    musicbrainz_artistid musicbrainz_albumid
    musicbrainz_albumartistid musicbrainz_trackid
    musicbrainz_recordingid musicbrainz_releasegroupid
  ].freeze

  VALID_TAGS = (BASIC_TAGS + EXTRA_TAGS).freeze

  # Read-only tags: a file reports them, nothing writes them.
  INFO_TAGS = %w[length bitrate].freeze

  # Tags a filename pattern may contain, matching upstream's EXTRACTABLE_TAGS.
  EXTRACTABLE_TAGS = (VALID_TAGS + INFO_TAGS).freeze

  # Tags whose values are whole numbers, and the one that is a decimal.
  INT_TAGS = %w[tracknumber totaltracknumber discnumber].freeze
  FLOAT_TAGS = %w[bpm].freeze

  # Which cover a file's image belongs to. Upstream's CoverType IntEnum.
  module CoverType
    FRONT = 0
    BACK = 1

    ALL = [FRONT, BACK].freeze
  end

  # Human-readable tag names.
  TAG_NAMES = {
    'length'                     => 'Length',
    'bitrate'                    => 'Bitrate',

    'title'                      => 'Title',
    'artist'                     => 'Artist',
    'album'                      => 'Album',
    'albumartist'                => 'Album artist',
    'tracknumber'                => 'Track number',
    'totaltracknumber'           => 'Total tracks',
    'genre'                      => 'Genre',
    'releasedate'                => 'Release date',
    'comment'                    => 'Comment',

    'none'                       => '(Select a tag)',
    # TRANSLATORS: Short for "beats per minute".
    'bpm'                        => 'BPM',
    'compilation'                => 'Compilation',
    'composer'                   => 'Composer',
    'copyright'                  => 'Copyright',
    'encodedby'                  => 'Encoded by',
    'mood'                       => 'Mood',
    # TRANSLATORS: Orchestra conductor
    'conductor'                  => 'Conductor',
    'arranger'                   => 'Arranger',
    'discnumber'                 => 'Disc number',
    'publisher'                  => 'Publisher',
    'isrc'                       => 'ISRC',
    'language'                   => 'Language',
    'discsubtitle'               => 'Disc subtitle',
    'url'                        => 'Website/URL',

    # TRANSLATORS: This is a sort tag, as in, a tag that dictates how music
    # software should treat this tag when sorting.
    'albumartistsort'            => 'Album artist (sort)',
    # TRANSLATORS: This is a sort tag, as in, a tag that dictates how music
    # software should treat this tag when sorting.
    'albumsort'                  => 'Album (sort)',
    # TRANSLATORS: This is a sort tag, as in, a tag that dictates how music
    # software should treat this tag when sorting.
    'composersort'               => 'Composer (sort)',
    # TRANSLATORS: This is a sort tag, as in, a tag that dictates how music
    # software should treat this tag when sorting.
    'artistsort'                 => 'Artist (sort)',
    # TRANSLATORS: This is a sort tag, as in, a tag that dictates how music
    # software should treat this tag when sorting.
    'titlesort'                  => 'Title (sort)',

    'musicbrainz_artistid'       => 'MusicBrainz Artist ID',
    'musicbrainz_albumid'        => 'MusicBrainz Album ID',
    'musicbrainz_albumartistid'  => 'MusicBrainz Album Artist ID',
    'musicbrainz_trackid'        => 'MusicBrainz Release Track ID',
    'musicbrainz_recordingid'    => 'MusicBrainz Recording ID',
    'musicbrainz_releasegroupid' => 'MusicBrainz Release Group ID',
  }.freeze

  module_function

  # The display name for a tag, falling back to the raw tag name for tags that
  # only some file formats carry.
  def name_for(tag) = TAG_NAMES.fetch(tag.to_s, tag.to_s)

  def valid?(tag) = VALID_TAGS.include?(tag.to_s)

  def extractable?(tag) = EXTRACTABLE_TAGS.include?(tag.to_s)
end
