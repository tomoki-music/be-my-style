require 'rails_helper'

RSpec.describe "Public::Songs", type: :request do
  let(:customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:community) { FactoryBot.create(:community) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, customer: customer, community: community) }

  before { sign_in customer }

  describe "GET show" do
    it "200 OKで曲詳細を表示すること" do
      song = FactoryBot.create(:song, event: event, song_name: "テスト楽曲")

      get public_event_song_path(event, song)

      expect(response.status).to eq 200
      expect(response.body).to include("テスト楽曲")
    end

    it "アーティスト名が登録されていれば表示すること" do
      song = FactoryBot.create(:song, event: event, artist_name: "テストアーティスト")

      get public_event_song_path(event, song)

      expect(response.body).to include("テストアーティスト")
    end

    it "アーティスト名が未登録でもエラーにならず「未設定」と表示すること" do
      song = FactoryBot.create(:song, event: event, artist_name: nil)

      get public_event_song_path(event, song)

      expect(response.status).to eq 200
      expect(response.body).to include("未設定")
    end

    context "コード譜情報" do
      it "全項目ありでコード譜情報が表示されること" do
        song = FactoryBot.create(:song, :with_chord_sheet, event: event)

        get public_event_song_path(event, song)

        expect(response.status).to eq 200
        expect(response.body).to include("コード譜情報")
        expect(response.body).to include("Key")
        expect(response.body).to include("G")
        expect(response.body).to include("Capo")
        expect(response.body).to include("2")
        expect(response.body).to include("初心者向けの簡単コード版です")
        expect(response.body).to include("コード譜を見る")
      end

      it "URLのみでもコード譜情報ブロックが表示されること" do
        song = FactoryBot.create(:song, event: event, chord_sheet_url: "https://example.com/chord-sheet")

        get public_event_song_path(event, song)

        expect(response.status).to eq 200
        expect(response.body).to include("コード譜情報")
        expect(response.body).to include("コード譜を見る")
      end

      it "Keyのみでもコード譜情報ブロックが表示されること" do
        song = FactoryBot.create(:song, event: event, musical_key: "Am")

        get public_event_song_path(event, song)

        expect(response.status).to eq 200
        expect(response.body).to include("コード譜情報")
        expect(response.body).to include("Am")
      end

      it "メモのみでもコード譜情報ブロックが表示されること" do
        song = FactoryBot.create(:song, event: event, chord_sheet_note: "原曲より半音下げ")

        get public_event_song_path(event, song)

        expect(response.status).to eq 200
        expect(response.body).to include("コード譜情報")
        expect(response.body).to include("原曲より半音下げ")
      end

      it "Capo 0の場合「なし」と表示されること" do
        song = FactoryBot.create(:song, event: event, capo: 0)

        get public_event_song_path(event, song)

        expect(response.body).to match(/Capo：\s*なし/)
      end

      it "Capo未入力の場合、Capo行が表示されないこと" do
        song = FactoryBot.create(:song, event: event, capo: nil, musical_key: "G")

        get public_event_song_path(event, song)

        expect(response.body).not_to include("Capo：")
      end

      it "コード譜情報が全て未入力の場合、ブロック自体が表示されないこと" do
        song = FactoryBot.create(:song, event: event, chord_sheet_url: nil, musical_key: nil, capo: nil, chord_sheet_note: nil)

        get public_event_song_path(event, song)

        expect(response.body).not_to include("コード譜情報")
      end

      it "外部リンクにtarget=\"_blank\"が付くこと" do
        song = FactoryBot.create(:song, event: event, chord_sheet_url: "https://example.com/chord-sheet")

        get public_event_song_path(event, song)

        expect(response.body).to include('href="https://example.com/chord-sheet"')
        expect(response.body).to include('target="_blank"')
      end

      it "外部リンクにrel=\"noopener\"が付くこと" do
        song = FactoryBot.create(:song, event: event, chord_sheet_url: "https://example.com/chord-sheet")

        get public_event_song_path(event, song)

        expect(response.body).to include('href="https://example.com/chord-sheet"')
        expect(response.body).to include('rel="noopener"')
      end

      it "長いメモでもレスポンスが成功すること" do
        song = FactoryBot.create(:song, event: event, chord_sheet_note: "あ" * 300)

        get public_event_song_path(event, song)

        expect(response.status).to eq 200
      end
    end
  end
end
