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

    context "TAB譜情報" do
      it "TAB譜URLがあれば「TAB譜情報」が表示されること" do
        song = FactoryBot.create(:song, :with_tab_sheet, event: event)

        get public_event_song_path(event, song)

        expect(response.status).to eq 200
        expect(response.body).to include("TAB譜情報")
      end

      it "「TAB譜を見る」が表示されること" do
        song = FactoryBot.create(:song, :with_tab_sheet, event: event)

        get public_event_song_path(event, song)

        expect(response.body).to include("TAB譜を見る")
      end

      it "正しいURLがリンク先に設定されること" do
        song = FactoryBot.create(:song, event: event, tab_sheet_url: "https://example.com/tab-sheet")

        get public_event_song_path(event, song)

        expect(response.body).to include('href="https://example.com/tab-sheet"')
        expect(response.body).to include('target="_blank"')
      end

      it "TAB譜URLが空欄の場合、「TAB譜情報」が表示されないこと" do
        song = FactoryBot.create(:song, event: event, tab_sheet_url: nil)

        get public_event_song_path(event, song)

        expect(response.status).to eq 200
        expect(response.body).not_to include("TAB譜情報")
      end

      it "コード譜とTAB譜が両方存在する場合、両方表示されること" do
        song = FactoryBot.create(:song, :with_chord_sheet, :with_tab_sheet, event: event)

        get public_event_song_path(event, song)

        expect(response.body).to include("コード譜情報")
        expect(response.body).to include("コード譜を見る")
        expect(response.body).to include("TAB譜情報")
        expect(response.body).to include("TAB譜を見る")
      end
    end

    context "参加状況(募集中/成立の判定は一覧画面とSong#established?/#recruiting?を共有する)" do
      let(:song) { FactoryBot.create(:song, event: event, song_name: "テスト楽曲") }
      let(:member) { FactoryBot.create(:customer, name: "参加太郎") }

      it "パートが無い曲は一覧画面と同じ基準で「楽曲成立🎵」と表示されること" do
        get public_event_song_path(event, song)

        expect(response.body).to include("楽曲成立🎵")
      end

      it "現役参加者が0人のパートがあると「募集中!!」と、そのパート欄にも「募集中」と表示されること" do
        FactoryBot.create(:join_part, song: song, join_part_name: "ボーカル")

        get public_event_song_path(event, song)

        expect(response.body).to include("募集中!!")
        expect(response.body).to include("募集中")
      end

      it "エントリー済みメンバーがアイコン・名前・プロフィールリンク付きで表示されること" do
        join_part = FactoryBot.create(:join_part, song: song, join_part_name: "ギター")
        FactoryBot.create(:join_part_customer, join_part: join_part, customer: member)

        get public_event_song_path(event, song)

        expect(response.body).to include("参加太郎")
        expect(response.body).to include(public_customer_path(member))
      end

      it "同じパートに複数人参加している場合、全員表示されること" do
        join_part = FactoryBot.create(:join_part, song: song, join_part_name: "ドラム")
        other_member = FactoryBot.create(:customer, name: "参加花子")
        FactoryBot.create(:join_part_customer, join_part: join_part, customer: member)
        FactoryBot.create(:join_part_customer, join_part: join_part, customer: other_member)

        get public_event_song_path(event, song)

        expect(response.body).to include("参加太郎")
        expect(response.body).to include("参加花子")
      end

      it "退会済み参加者だけのパートは、一覧画面と同じく「募集中」(現役参加者0人)として扱われること" do
        withdrawn = FactoryBot.create(:customer, name: "退会済み花子", is_deleted: true)
        join_part = FactoryBot.create(:join_part, song: song, join_part_name: "ベース")
        FactoryBot.create(:join_part_customer, join_part: join_part, customer: withdrawn)

        get public_event_song_path(event, song)

        expect(response.body).to include("募集中")
        expect(response.body).not_to include("退会済み花子")
      end

      it "他の楽曲のパートが混在して表示されないこと" do
        other_song = FactoryBot.create(:song, event: event, song_name: "別の曲")
        other_part = FactoryBot.create(:join_part, song: other_song, join_part_name: "キーボード")

        get public_event_song_path(event, song)

        expect(response.body).not_to include("event_join_part_ids_#{other_part.id}")
      end
    end

    context "エントリー導線(パート選択・確認画面・登録は既存のjoin_confirm/joinをそのまま再利用する)" do
      # event factoryの既定日時(2023年)は現在から見て開催終了済みのため、
      # エントリー可否を検証するcontextでは一覧画面の既存specと同様に未来日時へ上書きする。
      let(:event) do
        FactoryBot.create(
          :event, :event_with_songs, customer: customer, community: community,
          event_start_time: 3.days.from_now, event_end_time: 3.days.from_now + 2.hours
        )
      end
      let(:song) { FactoryBot.create(:song, event: event, song_name: "テスト楽曲") }
      let!(:vocal_part) { FactoryBot.create(:join_part, song: song, join_part_name: "ボーカル") }

      context "開催コミュニティに所属している場合" do
        before { CommunityCustomer.find_or_create_by!(customer: customer, community: community) }

        it "募集中パートのエントリーチェックボックスと確認画面への導線が表示されること" do
          get public_event_song_path(event, song)

          expect(response.body).to include("event_join_part_ids_#{vocal_part.id}")
          expect(response.body).to include(public_event_join_confirm_path(event))
          expect(response.body).to include("参加確認画面へ")
        end

        it "チェックボックスから既存のjoin_confirm→joinを経て参加登録が完了すること" do
          get public_event_join_confirm_path(event, event: { join_part_ids: [vocal_part.id.to_s] })
          expect(response.status).to eq 200
          expect(response.body).to include("参加確認画面")

          expect do
            post public_event_join_path(event), params: { join_part_ids: { "0" => vocal_part.id.to_s } }
          end.to change(JoinPartCustomer, :count).by(1)
          expect(JoinPartCustomer.exists?(customer_id: customer.id, join_part_id: vocal_part.id)).to eq true
        end

        it "イベント終了後はチェックボックスが表示されず、一覧画面と同じ案内文が表示されること" do
          ended_event = FactoryBot.create(
            :event, :event_with_songs, customer: customer, community: community,
            event_start_time: 3.days.ago - 2.hours, event_end_time: 3.days.ago
          )
          ended_song = ended_event.songs.first
          ended_part = FactoryBot.create(:join_part, song: ended_song, join_part_name: "ドラム")

          get public_event_song_path(ended_event, ended_song)

          expect(response.body).not_to include("event_join_part_ids_#{ended_part.id}")
          expect(response.body).to include("終了イベントのためチェック不可")
        end
      end

      context "開催コミュニティに所属していない場合" do
        it "エントリーチェックボックスは表示されず、コミュニティ参加への案内が表示されること" do
          get public_event_song_path(event, song)

          expect(response.body).not_to include("event_join_part_ids_#{vocal_part.id}")
          expect(response.body).to include("まずこちらのコミュニティに参加してください")
        end

        it "詳細ページに導線が無くても直接POSTすれば従来どおり拒否されること(表示制御だけに依存しない)" do
          expect do
            post public_event_join_path(event), params: { join_part_ids: { "0" => vocal_part.id.to_s } }
          end.not_to change(JoinPartCustomer, :count)
          expect(response).to redirect_to(public_community_path(community))
        end
      end
    end
  end
end
