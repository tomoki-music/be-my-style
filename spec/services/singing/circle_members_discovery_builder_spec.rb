require "rails_helper"

RSpec.describe Singing::CircleMembersDiscoveryBuilder do
  describe ".call" do
    subject(:result) { described_class.call(circle_slug) }

    context "circle なし (nil)" do
      let(:circle_slug) { nil }

      it "CircleMembersDiscovery を返す" do
        expect(result).to be_a(described_class::CircleMembersDiscovery)
      end

      it "デフォルトの circle_name を返す" do
        expect(result.circle_name).to eq("🎵 Singing Members")
      end

      it "circle_description が存在する" do
        expect(result.circle_description).to be_present
      end

      it "empty_title が存在する" do
        expect(result.empty_title).to be_present
      end

      it "empty_message が存在する" do
        expect(result.empty_message).to be_present
      end

      it "members_count が Integer である" do
        expect(result.members_count).to be_a(Integer)
      end

      it "circle_slug が nil になる" do
        expect(result.circle_slug).to be_nil
      end
    end

    context "circle なし (空文字)" do
      let(:circle_slug) { "" }

      it "デフォルトの circle_name を返す" do
        expect(result.circle_name).to eq("🎵 Singing Members")
      end
    end

    context "valid circle: emotional_singer" do
      let(:circle_slug) { "emotional_singer" }

      it "circle_slug を返す" do
        expect(result.circle_slug).to eq("emotional_singer")
      end

      it "circle-specific な circle_name を返す" do
        expect(result.circle_name).to eq("🎭 Emotional Singer Circle")
      end

      it "circle_description が存在する" do
        expect(result.circle_description).to be_present
      end

      it "members_count が正の整数である" do
        expect(result.members_count).to be > 0
      end

      it "empty_title が存在する" do
        expect(result.empty_title).to be_present
      end

      it "empty_message が存在する" do
        expect(result.empty_message).to be_present
      end
    end

    context "invalid circle" do
      let(:circle_slug) { "unknown_circle_xyz" }

      it "デフォルトの circle_name にフォールバックする" do
        expect(result.circle_name).to eq("🎵 Singing Members")
      end

      it "members_count が Integer である" do
        expect(result.members_count).to be_a(Integer)
      end

      it "empty_title が存在する" do
        expect(result.empty_title).to be_present
      end

      it "empty_message が存在する" do
        expect(result.empty_message).to be_present
      end
    end

    describe "circle_name が各 valid circle で返る" do
      let(:expected_names) do
        {
          "emotional_singer"  => "🎭 Emotional Singer Circle",
          "rhythm_explorer"   => "🥁 Rhythm Explorer Circle",
          "consistency_hero"  => "🔥 Consistency Circle",
          "voice_challenger"  => "🎤 Voice Challenge Circle",
          "dynamic_performer" => "🌟 Dynamic Performer Circle",
          "groove_builder"    => "🎵 Groove Builder Circle"
        }
      end

      it "各 circle で専用の circle_name を返す" do
        expected_names.each do |slug, expected_name|
          r = described_class.call(slug)
          expect(r.circle_name).to eq(expected_name), "slug=#{slug} のとき #{expected_name} を期待したが #{r.circle_name} だった"
        end
      end
    end

    describe "circle_description が circle ごとに返る" do
      it "consistency_hero は継続に関する説明を返す" do
        expect(described_class.call("consistency_hero").circle_description).to include("コツコツ")
      end

      it "rhythm_explorer はリズムに関する説明を返す" do
        expect(described_class.call("rhythm_explorer").circle_description).to include("リズム")
      end

      it "emotional_singer は表現に関する説明を返す" do
        expect(described_class.call("emotional_singer").circle_description).to include("表現")
      end
    end

    describe "empty_title" do
      context "valid circle" do
        let(:circle_slug) { "voice_challenger" }

        it "Circle 向け empty_title を返す" do
          expect(result.empty_title).to be_present
        end
      end

      context "circle なし" do
        let(:circle_slug) { nil }

        it "デフォルトの empty_title を返す" do
          expect(result.empty_title).to be_present
        end
      end
    end

    describe "empty_message" do
      let(:circle_slug) { "rhythm_explorer" }

      it "empty_message が存在する" do
        expect(result.empty_message).to be_present
      end
    end

    describe "members_count" do
      context "valid circle (consistency_hero)" do
        let(:circle_slug) { "consistency_hero" }

        it "Integer を返す" do
          expect(result.members_count).to be_a(Integer)
        end

        it "0 より大きい" do
          expect(result.members_count).to be > 0
        end
      end

      context "circle なし" do
        let(:circle_slug) { nil }

        it "Integer を返す" do
          expect(result.members_count).to be_a(Integer)
        end
      end
    end
  end
end
