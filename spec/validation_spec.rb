# frozen_string_literal: true

# Ported from upstream's tests/utils/test_validation.py, against
# lib/validation.rb (Validation), which is itself a port of
# src/utils/validation.py.
RSpec.describe Validation do
  let(:example_mp3) { File.join(__dir__, "..", "test", "fixtures", "sample.mp3") }

  before { described_class.clear_cache }

  describe ".valid_music_file?" do
    it "is false for a path that does not exist" do
      expect(described_class.valid_music_file?("/eartag/not-found")).to be(false)
    end

    it "is true for a real mp3 file" do
      expect(described_class.valid_music_file?(example_mp3, no_cache: true)).to be(true)
    end
  end

  describe ".valid_image_file?" do
    it "is false for an audio file" do
      expect(described_class.valid_image_file?(example_mp3, no_cache: true)).to be(false)
    end
  end

  describe ".mimetype" do
    it "sniffs an mp3's content as audio/mpeg" do
      expect(described_class.mimetype(example_mp3, no_cache: true)).to eq("audio/mpeg")
    end

    it "caches the result by path unless no_cache is given" do
      described_class.mimetype(example_mp3)

      expect(described_class.cache[example_mp3.to_s]).to eq("audio/mpeg")
    end

    it "falls back to the extension when content sniffing fails" do
      mime = described_class.mimetype_buffer("not a real header")

      expect(mime).to be_nil
    end
  end

  describe ".valid_file?" do
    it "rejects a mimetype that is not in the given list" do
      expect(
        described_class.valid_file?(example_mp3, ["audio/invalid"], no_cache: true),
      ).to be(false)
    end
  end
end
