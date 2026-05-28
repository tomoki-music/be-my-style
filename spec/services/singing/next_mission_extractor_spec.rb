require "rails_helper"

RSpec.describe Singing::NextMissionExtractor, type: :service do
  describe ".call" do
    subject(:result) { described_class.call(ai_comment) }

    context "「次回は〜」パターンのコメント" do
      let(:ai_comment) do
        "今回はリズムが安定していました。次回はAメロでリズムに合わせて身体を揺らしながら歌ってみましょう。継続すると改善します。"
      end

      it "ミッションを抽出する" do
        expect(result).not_to be_nil
        expect(result[:title]).to be_present
        expect(result[:body]).to be_present
      end

      it "title は TITLE_MAX 文字以内" do
        expect(result[:title].length).to be <= described_class::TITLE_MAX
      end

      it "body は BODY_MAX 文字以内" do
        expect(result[:body].length).to be <= described_class::BODY_MAX
      end
    end

    context "「意識してみましょう」パターンのコメント" do
      let(:ai_comment) do
        "音程は安定しています。フレーズの入りのタイミングを意識してみましょう。少しずつ改善できます。"
      end

      it "ミッションを抽出する" do
        expect(result).not_to be_nil
        expect(result[:body]).to include("タイミングを意識")
      end
    end

    context "「チャレンジしてみましょう」パターン" do
      let(:ai_comment) do
        "表現力が伸びています。ぜひサビで声量を変えてチャレンジしてみましょう。"
      end

      it "ミッションを抽出する" do
        expect(result).not_to be_nil
      end
    end

    context "ミッションシグナルが含まれないコメント" do
      let(:ai_comment) do
        "今回の診断は全体的に安定していました。特に音程が高い水準で維持できています。"
      end

      it "nil を返す" do
        expect(result).to be_nil
      end
    end

    context "空文字" do
      let(:ai_comment) { "" }

      it "nil を返す" do
        expect(result).to be_nil
      end
    end

    context "nil" do
      let(:ai_comment) { nil }

      it "nil を返す" do
        expect(result).to be_nil
      end
    end
  end
end
