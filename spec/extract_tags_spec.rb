# frozen_string_literal: true

# Ported from upstream's tests/utils/test_extracttags.py, against
# lib/extract_tags.rb (ExtractTags), which is itself a port of
# src/utils/extracttags.py.
RSpec.describe ExtractTags do
  describe ".extract_tags_from_filename" do
    it "returns an empty hash for an empty filename" do
      expect(
        described_class.extract_tags_from_filename("", "{tracknumber} - {title}"),
      ).to eq({})
    end

    it "matches a track number and title" do
      tags = described_class.extract_tags_from_filename(
        "02 - Pais E Filhos",
        "{tracknumber} - {title}",
      )

      expect(tags).to eq("tracknumber" => "02", "title" => "Pais E Filhos")
    end

    it "returns byte offsets alongside each value when positions: true" do
      tags = described_class.extract_tags_from_filename(
        "02 - Pais E Filhos",
        "{tracknumber} - {title}",
        positions: true,
      )

      expect(tags).to eq(
        "tracknumber" => ["02", [0, 2]],
        "title" => ["Pais E Filhos", [5, 18]],
      )
    end

    it "treats literal curly braces in the filename as ordinary text" do
      tags = described_class.extract_tags_from_filename(
        "02 - {Pais E Filhos}",
        "{tracknumber} - {title}",
      )

      expect(tags).to eq("tracknumber" => "02", "title" => "{Pais E Filhos}")
    end

    it "handles unicode characters in the matched value" do
      tags = described_class.extract_tags_from_filename(
        "02 - Pais E Filhos \u{1F44D}",
        "{tracknumber} - {title}",
      )

      expect(tags).to eq("tracknumber" => "02", "title" => "Pais E Filhos \u{1F44D}")
    end

    it "reports unicode byte offsets, not character offsets, when positions: true" do
      tags = described_class.extract_tags_from_filename(
        "02 - Pais E Filhos \u{1F44D}",
        "{tracknumber} - {title}",
        positions: true,
      )

      expect(tags).to eq(
        "tracknumber" => ["02", [0, 2]],
        "title" => ["Pais E Filhos \u{1F44D}", [5, 23]],
      )
    end

    malformed_placeholder_cases = [
      "",
      "{}",
      "{tracknumber} - {not_existing_placeholder}",
      "{not_existing_placeholder} - {title}",
      "tracknumber}",
      "tracknumber} - {title}",
      "{tracknumber} - title}",
      "{tracknumber",
      "{tracknumber - {title}",
      "{tracknumber} - {title",
      "{tracknumber} - {{title}}",
      "{tracknumber} - {title} - {tracknumber}",
    ].freeze

    malformed_placeholder_cases.each do |placeholder|
      it "returns an empty hash for the malformed placeholder #{placeholder.inspect}" do
        expect(
          described_class.extract_tags_from_filename("02 - Pais E Filhos", placeholder),
        ).to eq({})
      end
    end
  end
end
