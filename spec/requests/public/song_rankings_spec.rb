require 'rails_helper'

RSpec.describe "Public::SongRankings", type: :request do
  let(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:community) { create(:community, domain: music_domain, name: "公開コミュニティ") }

  def create_event(start_time, in_community: nil)
    create(
      :event, :event_with_songs,
      community: in_community || community,
      event_start_time: start_time,
      event_end_time: start_time + 2.hours,
      event_entry_deadline: start_time - 1.day
    )
  end

  def establish(event, song_name:, artist_name:, participant_name: "参加者太郎")
    song = create(:song, event: event, song_name: song_name, artist_name: artist_name)
    %w[Vocal Guitar].each do |part_name|
      part = create(:join_part, song: song, join_part_name: part_name)
      create(:join_part_customer, join_part: part, customer: create(:customer, name: participant_name))
    end
    song
  end

  describe "GET /song_rankings" do
    it "未ログインでも200で閲覧できること" do
      get public_song_rankings_path
      expect(response).to have_http_status(:ok)
    end

    it "ログイン状態を要求してログイン画面へリダイレクトしないこと" do
      get public_song_rankings_path
      expect(response).not_to redirect_to(new_customer_session_path)
    end

    context "成立楽曲がある場合" do
      let!(:song) do
        establish(create_event(3.days.from_now), song_name: "みんなの曲", artist_name: "あいみょん", participant_name: "秘密の参加者")
      end

      before { get public_song_rankings_path }

      it "順位・楽曲名・アーティスト名・成立回数が表示されること" do
        expect(response.body).to include("1")
        expect(response.body).to include("みんなの曲")
        expect(response.body).to include("あいみょん")
        expect(response.body).to include("回成立")
      end

      it "代表Songの楽曲詳細ページへのリンクが正しいこと" do
        expect(response.body).to include(public_event_song_path(song.event_id, song.id))
      end

      it "参加者などの個人情報がHTMLに出力されないこと" do
        expect(response.body).not_to include("秘密の参加者")
      end
    end

    context "絞り込み条件" do
      let!(:hidden_community) { create(:community, domain: business_domain, name: "ビジネス限定コミュニティ") }

      before do
        establish(create_event(Time.zone.local(2026, 9, 10, 12)), song_name: "9月の曲", artist_name: "X")
        get public_song_rankings_path, params: { period: "monthly", year: "2026", month: "9", community_id: community.id }
      end

      it "GETパラメータの選択状態がフォームに保持されること" do
        doc = Nokogiri::HTML(response.body)
        expect(doc.at_css('select#period option[selected]')['value']).to eq "monthly"
        expect(doc.at_css('select#year option[selected]')['value']).to eq "2026"
        expect(doc.at_css('select#month option[selected]')['value']).to eq "9"
        expect(doc.at_css('select#community_id option[selected]')['value']).to eq community.id.to_s
      end

      it "非公開ドメインのコミュニティが選択肢に出ないこと" do
        expect(response.body).not_to include("ビジネス限定コミュニティ")
      end
    end

    context "期間UIの表示・有効化(JavaScript無効時のサーバーレンダリング)" do
      it "初期状態は「すべての期間」が選択され、対象年・対象月は非表示かつdisabledであること" do
        get public_song_rankings_path
        doc = Nokogiri::HTML(response.body)

        expect(doc.at_css('select#period option[selected]')['value']).to eq "all"
        expect(doc.at_css('select#period').text).to include("すべての期間")
        expect(doc.at_css('.song-ranking__field--year')['hidden']).not_to be_nil
        expect(doc.at_css('.song-ranking__field--month')['hidden']).not_to be_nil
        expect(doc.at_css('select#year')['disabled']).not_to be_nil
        expect(doc.at_css('select#month')['disabled']).not_to be_nil
      end

      it "「年間」選択時は対象年のみ表示・有効化され、対象月は非表示かつdisabledであること" do
        get public_song_rankings_path, params: { period: "yearly", year: "2026" }
        doc = Nokogiri::HTML(response.body)

        expect(doc.at_css('.song-ranking__field--year')['hidden']).to be_nil
        expect(doc.at_css('select#year')['disabled']).to be_nil
        expect(doc.at_css('.song-ranking__field--month')['hidden']).not_to be_nil
        expect(doc.at_css('select#month')['disabled']).not_to be_nil
      end

      it "「月間」選択時は対象年・対象月がどちらも表示・有効化されること" do
        get public_song_rankings_path, params: { period: "monthly", year: "2026", month: "9" }
        doc = Nokogiri::HTML(response.body)

        expect(doc.at_css('.song-ranking__field--year')['hidden']).to be_nil
        expect(doc.at_css('select#year')['disabled']).to be_nil
        expect(doc.at_css('.song-ranking__field--month')['hidden']).to be_nil
        expect(doc.at_css('select#month')['disabled']).to be_nil
      end
    end

    context "全期間指定(period=all)" do
      before do
        establish(create_event(Time.zone.local(2024, 1, 5, 12)), song_name: "むかしの曲", artist_name: "X")
        establish(create_event(Time.zone.local(2027, 12, 20, 12)), song_name: "みらいの曲", artist_name: "X")
      end

      it "初期表示(パラメータなし)で全期間が集計されること" do
        get public_song_rankings_path
        expect(response.body).to include("むかしの曲")
        expect(response.body).to include("みらいの曲")
      end

      it "period=all に不要な year / month が送信されても集計に影響しないこと" do
        get public_song_rankings_path, params: { period: "all", year: "2024", month: "1" }
        expect(response.body).to include("むかしの曲")
        expect(response.body).to include("みらいの曲")
      end
    end

    context "不正なパラメータ" do
      it "想定外の文字列でも500にならず200を返すこと" do
        get public_song_rankings_path, params: {
          period: "<script>", year: "abc", month: "99", community_id: "not-a-number", artist_name: "' OR 1=1"
        }
        expect(response).to have_http_status(:ok)
      end
    end

    context "該当データが0件の場合" do
      it "エラーではなく空状態メッセージを表示すること" do
        get public_song_rankings_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("表示できるランキングがありません")
      end
    end

    context "公開範囲" do
      it "musicドメイン以外のコミュニティで成立した楽曲は集計されないこと" do
        biz = create(:community, domain: business_domain, name: "ビジネス")
        establish(create_event(1.day.from_now, in_community: biz), song_name: "ビジネス限定曲", artist_name: "X")

        get public_song_rankings_path
        expect(response.body).not_to include("ビジネス限定曲")
      end
    end
  end

  describe "ナビゲーション導線" do
    it "未ログイン向けトップページのフッターからランキングへ遷移できること" do
      get root_path
      expect(response.body).to include(%(href="#{public_song_rankings_path}"))
    end
  end

  describe "ランキングの種類切り替え" do
    it "成立楽曲 / ユーザー演奏実績 の 2 種類が表示されること" do
      get public_song_rankings_path
      nav = Nokogiri::HTML(response.body).at_css(".ranking-type-nav")
      expect(nav).to be_present
      expect(nav.text).to include("成立楽曲")
      expect(nav.text).to include("ユーザー演奏実績")
    end

    it "成立楽曲側が選択状態(aria-current=page)で、その側だけに付くこと" do
      get public_song_rankings_path
      nav = Nokogiri::HTML(response.body).at_css(".ranking-type-nav")
      current = nav.css('[aria-current="page"]')
      expect(current.size).to eq 1
      expect(current.first.text.strip).to eq("成立楽曲")
    end

    it "ユーザー演奏実績ランキングへのリンクを持つこと" do
      get public_song_rankings_path
      nav = Nokogiri::HTML(response.body).at_css(".ranking-type-nav")
      link = nav.css("a").find { |a| a.text.strip == "ユーザー演奏実績" }
      expect(link["href"]).to eq(public_performance_rankings_path)
    end

    it "横スクロールを生む固定幅・テーブル構造を使っていないこと" do
      get public_song_rankings_path
      nav = Nokogiri::HTML(response.body).at_css(".ranking-type-nav")
      expect(nav.css("table")).to be_empty
      expect(nav.to_html).not_to match(/style=/)
    end
  end
end
