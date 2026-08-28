require 'rails_helper'

RSpec.describe "customersコントローラーのテスト", type: :request do
  let(:customer) { create(:customer, :customer_with_parts) }
  let(:customer2) { create(:customer, :customer_with_parts) }
  let(:customer3) { create(:customer, :customer_with_parts) }
  let(:community) { create(:community) }
  describe 'ログイン済み' do
    before do
      sign_in customer
    end
    context "customer詳細ページが正しく表示される" do
      before do
        get public_customer_path(customer)
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
      it 'タイトルが正しく表示されていること' do
        expect(response.body).to include("アーティスト詳細")
      end
    end
    context "同じcommunity内のcustomer詳細ページは表示される" do
      before do
        get public_community_join_path(community)
        sign_in customer2
        get public_community_join_path(community)
        get public_customer_path(customer)
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
      it 'タイトルが正しく表示されていること' do
        expect(response.body).to include("アーティスト詳細")
      end
    end
    context "同じcommunityでないcustomer詳細ページは表示されない" do
      before do
        get public_community_join_path(community)
        sign_in customer3
        get public_customer_path(customer)
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
      it 'コミュニティ一覧へリダイレクトされる' do
        expect(response).to redirect_to('http://www.example.com/public/communities')
      end
    end
    context "退会済みユーザーのプロフィールへ直接アクセスした場合" do
      let(:withdrawn_customer) { create(:customer, is_deleted: true) }

      before do
        CommunityCustomer.find_or_create_by!(customer: customer, community: community)
        CommunityCustomer.find_or_create_by!(customer: withdrawn_customer, community: community)
      end

      it 'プロフィール内容を表示せず、コミュニティ一覧へリダイレクトされること' do
        get public_customer_path(withdrawn_customer)

        expect(response.status).to eq 302
        expect(response).to redirect_to(public_communities_path)
      end

      it '退会ユーザーを特定できる情報を含まない汎用メッセージであること' do
        get public_customer_path(withdrawn_customer)
        follow_redirect!

        expect(response.body).to include("このユーザーのプロフィールは表示できません。")
        expect(response.body).not_to include(withdrawn_customer.name)
      end
    end

    context "フォロー数・フォロワー数から退会済みユーザーが除かれること" do
      let(:withdrawn_customer) { create(:customer, is_deleted: true) }

      it '退会済みユーザーをフォローしていてもフォロー数に数えないこと' do
        customer.follow(customer2.id)
        customer.follow(withdrawn_customer.id)

        get public_customer_path(customer)

        expect(customer.followings.active.count).to eq 1
      end
    end

    context "customer編集ページが正しく表示される" do
      before do
        get edit_public_customer_path(customer)
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
      it 'タイトルが正しく表示されていること' do
        expect(response.body).to include("アーティスト編集画面")
      end
      it '加入年月日の入力欄が表示されること' do
        expect(response.body).to include("加入年月日")
        expect(response.body).to include('name="customer[joined_on]"')
      end
    end

    describe "加入年月日(joined_on)" do
      it '自分の加入年月日を過去日へ更新できること' do
        patch public_customer_path(customer), params: { customer: { joined_on: "2020-04-15" } }

        expect(customer.reload.joined_on).to eq Date.new(2020, 4, 15)
      end

      it '当日を保存できること' do
        patch public_customer_path(customer), params: { customer: { joined_on: Date.current.to_s } }

        expect(customer.reload.joined_on).to eq Date.current
      end

      it '未来日は保存できないこと' do
        original = customer.joined_on
        patch public_customer_path(customer), params: { customer: { joined_on: (Date.current + 1).to_s } }

        expect(customer.reload.joined_on).to eq original
        expect(response.body).to include("加入年月日は今日以前の日付を入力してください")
      end

      it '他人の加入年月日は更新できないこと' do
        original = customer2.joined_on
        patch public_customer_path(customer2), params: { customer: { joined_on: "2019-01-01" } }

        expect(customer2.reload.joined_on).to eq original
      end

      it 'プロフィール詳細に加入年月日が日本語形式で表示されること' do
        customer.update!(joined_on: Date.new(2024, 4, 15))

        get public_customer_path(customer)

        expect(response.body).to include("2024年4月15日")
      end

      it 'プロフィール詳細に正確なログイン日時が表示されないこと' do
        customer.update!(current_sign_in_at: Time.zone.local(2026, 8, 20, 9, 30, 0))

        get public_customer_path(customer)

        expect(response.body).not_to include("09:30")
        expect(response.body).not_to include("2026年8月20日")
      end
    end

    describe "アクティブアイコン(緑丸)" do
      before { customer.update!(current_sign_in_at: Time.current) }

      it 'ヘッダーの自分のアバターには緑丸を表示しないこと' do
        get edit_public_customer_path(customer)

        expect(response.body).not_to include("avatar-active-dot")
      end

      it 'プロフィール詳細では最近アクティブなユーザーに緑丸を表示すること' do
        get public_customer_path(customer)

        expect(response.body).to include("avatar-active-dot")
      end
    end

    describe "演奏実績のスクロール表示" do
      let(:history_community) { create(:community) }

      # 終了済みイベント(:event factoryのデフォルト日時は2023年)への出演実績を1件作る。
      def create_performance(song_name:, part_name: "Vocal")
        event = create(:event, :event_with_songs, community: history_community)
        song = create(:song, event: event, song_name: song_name, artist_name: "アーティスト")
        join_part = create(:join_part, song: song, join_part_name: part_name)
        create(:join_part_customer, join_part: join_part, customer: customer)
      end

      context "演奏実績があるとき" do
        before do
          create_performance(song_name: "スクロール確認曲")
          get public_customer_path(customer)
        end

        it "演奏実績欄が専用のスクロールコンテナで囲まれること" do
          container = Nokogiri::HTML(response.body).at_css("td .performance-history-scroll")

          expect(container).to be_present
          expect(container["tabindex"]).to eq "0"
          expect(container["role"]).to eq "region"
          expect(container["aria-label"]).to eq "演奏実績一覧"
        end
      end

      context "演奏実績が複数あるとき" do
        it "すべての演奏実績がスクロールコンテナ内のDOMに残ること" do
          song_names = %w[実績曲アルファ 実績曲ブラボー 実績曲チャーリー]
          song_names.each { |name| create_performance(song_name: name) }

          get public_customer_path(customer)

          container = Nokogiri::HTML(response.body).at_css(".performance-history-scroll")
          song_names.each do |name|
            expect(container.text).to include(name)
          end
        end
      end

      context "演奏実績が0件のとき" do
        it "スクロールコンテナ自体を表示しないこと" do
          get public_customer_path(customer)

          expect(response.body).not_to include("performance-history-scroll")
        end
      end

      context "演奏実績と演奏可能曲の両方があるとき" do
        before do
          create_performance(song_name: "実績側の曲")
          playable_event = create(:event, :event_with_songs, community: history_community)
          playable_song = create(:song, event: playable_event, song_name: "演奏可能曲側の曲", artist_name: "アーティスト")
          create(:customer_song_part, customer: customer, song: playable_song, song_master: playable_song.song_master, part_name: "Guitar")

          get public_customer_path(customer)
        end

        it "スクロールコンテナには演奏実績のみが含まれ、演奏可能曲は含まれないこと" do
          container = Nokogiri::HTML(response.body).at_css(".performance-history-scroll")

          expect(container.text).to include("実績側の曲")
          expect(container.text).not_to include("演奏可能曲側の曲")
        end
      end

      context "演奏可能曲だけが登録されているとき" do
        it "スクロールコンテナを付与しないこと" do
          playable_event = create(:event, :event_with_songs, community: history_community)
          playable_song = create(:song, event: playable_event, song_name: "自己申告のみの曲", artist_name: "アーティスト")
          create(:customer_song_part, customer: customer, song: playable_song, song_master: playable_song.song_master, part_name: "Guitar")

          get public_customer_path(customer)

          expect(response.body).to include("演奏可能曲")
          expect(response.body).not_to include("performance-history-scroll")
        end
      end
    end
  end
  describe '非ログイン' do
    context "customers詳細ページへ遷移されない" do
      before do
        get public_customer_path(customer)
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
    context "customers編集ページへ遷移されない" do
      before do
        get edit_public_customer_path(customer)
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
  end
end
