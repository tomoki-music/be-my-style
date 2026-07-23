require "rails_helper"

RSpec.describe "チャットルーム内メッセージ検索(GET /chat_rooms/:id/search)のテスト", type: :request do
  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }
  let(:chat_room) { create(:chat_room) }

  describe "DMの場合" do
    before do
      create(:chat_room_customer, chat_room: chat_room, customer: customer)
      create(:chat_room_customer, chat_room: chat_room, customer: other_customer)
    end

    context "参加者としてログイン済み" do
      before { sign_in customer }

      it "本文が部分一致するメッセージを検索できること" do
        target = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "明日のライブ楽しみです")
        create(:chat_message, customer: customer, chat_room: chat_room, content: "全然関係ない内容")

        get search_public_chat_room_path(chat_room), params: { q: "ライブ" }

        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        expect(json["html"]).to include("明日のライブ楽しみです")
        expect(json["total_count"]).to eq 1
        expect(json["html"]).not_to match(/全然関係ない内容/)
      end

      it "スレッド返信も検索結果に含まれること" do
        root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")
        reply = create(:chat_message, customer: customer, chat_room: chat_room, content: "練習の日程について返信します",
                                       reply_to_chat_message: root)

        get search_public_chat_room_path(chat_room), params: { q: "練習" }

        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        expect(json["html"]).to include("練習の日程について返信します")
        expect(json["html"]).to include("スレッド内の返信")
        # data-search-is-reply/-root-idはJS側がstrictな文字列比較("true")で判定に使うため、
        # Hamlのbooleanがdata属性化される際に空文字になる事故を防ぐ回帰テスト。
        expect(json["html"]).to match(/data-search-message-id=['"]#{reply.id}['"]/)
        expect(json["html"]).to match(/data-search-root-id=['"]#{root.id}['"]/)
        expect(json["html"]).to match(/data-search-is-reply=['"]true['"]/)
      end

      it "通常メッセージのdata-search-is-replyはfalseであること" do
        normal = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "通常の投稿です")

        get search_public_chat_room_path(chat_room), params: { q: "通常の投稿" }

        json = JSON.parse(response.body)
        expect(json["html"]).to match(/data-search-message-id=['"]#{normal.id}['"]/)
        expect(json["html"]).to match(/data-search-root-id=['"]#{normal.id}['"]/)
        expect(json["html"]).to match(/data-search-is-reply=['"]false['"]/)
      end

      it "他ルームのメッセージが結果に混入しないこと" do
        create(:chat_message, customer: customer, chat_room: chat_room, content: "共通ワードのテスト")
        other_room = create(:chat_room)
        create(:chat_room_customer, chat_room: other_room, customer: customer)
        create(:chat_message, customer: customer, chat_room: other_room, content: "共通ワードのテスト")

        get search_public_chat_room_path(chat_room), params: { q: "共通ワード" }

        json = JSON.parse(response.body)
        expect(json["total_count"]).to eq 1
      end

      it "該当なしの場合は0件であること" do
        create(:chat_message, customer: customer, chat_room: chat_room, content: "全然関係ない内容")

        get search_public_chat_room_path(chat_room), params: { q: "ヒットしない検索語" }

        json = JSON.parse(response.body)
        expect(json["total_count"]).to eq 0
        expect(json["html"]).to include("見つかりませんでした")
      end

      it "空文字の場合は検索を実行せず案内を表示すること" do
        create(:chat_message, customer: customer, chat_room: chat_room, content: "何かの内容")

        get search_public_chat_room_path(chat_room), params: { q: "" }

        json = JSON.parse(response.body)
        expect(json["total_count"]).to eq 0
        expect(json["html"]).to include("キーワードを入力して検索してください")
      end

      it "1文字の場合は検索を実行せず文字数エラーを表示すること" do
        get search_public_chat_room_path(chat_room), params: { q: "a" }

        json = JSON.parse(response.body)
        expect(json["total_count"]).to eq 0
        expect(json["html"]).to include("2文字以上入力してください")
      end

      it "51文字以上の場合は検索を実行せず文字数エラーを表示すること" do
        get search_public_chat_room_path(chat_room), params: { q: "あ" * 51 }

        json = JSON.parse(response.body)
        expect(json["total_count"]).to eq 0
        expect(json["html"]).to include("50文字以内で入力してください")
      end

      it "1ページ20件でページネーションされ、page/next_page/prev_pageが正しく返ること" do
        25.times { |i| create(:chat_message, customer: customer, chat_room: chat_room, content: "検索対象メッセージ#{i}") }

        get search_public_chat_room_path(chat_room), params: { q: "検索対象" }
        json = JSON.parse(response.body)
        expect(json["page"]).to eq 1
        expect(json["next_page"]).to eq 2
        expect(json["prev_page"]).to be_nil
        expect(json["total_count"]).to eq 25

        get search_public_chat_room_path(chat_room), params: { q: "検索対象", page: 2 }
        json_page2 = JSON.parse(response.body)
        expect(json_page2["page"]).to eq 2
        expect(json_page2["next_page"]).to be_nil
        expect(json_page2["prev_page"]).to eq 1
      end

      it "本文にHTMLタグを含むメッセージがあっても、Hamlの通常出力によりエスケープされて返ること" do
        create(:chat_message, customer: customer, chat_room: chat_room, content: "<script>alert(1)</script>危険なテスト")

        get search_public_chat_room_path(chat_room), params: { q: "危険な" }

        json = JSON.parse(response.body)
        expect(json["html"]).not_to include("<script>alert(1)</script>")
        expect(json["html"]).to include("&lt;script&gt;")
      end
    end

    context "DM非参加者としてログイン済み" do
      it "検索できず404を返すこと(ルームの存在を推測させない)" do
        create(:chat_message, customer: other_customer, chat_room: chat_room, content: "内容")
        stranger = create(:customer)
        sign_in stranger

        get search_public_chat_room_path(chat_room), params: { q: "内容" }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "非ログイン" do
      it "302でログイン画面へリダイレクトされること" do
        get search_public_chat_room_path(chat_room), params: { q: "内容" }
        expect(response).to have_http_status(302)
      end
    end
  end

  describe "コミュニティの場合" do
    let(:community) { create(:community) }
    let(:member) { create(:customer) }

    before do
      create(:chat_room_customer, chat_room: chat_room, customer: customer, community: community)
      CommunityCustomer.find_or_create_by!(customer: customer, community: community)
      CommunityCustomer.find_or_create_by!(customer: member, community: community)
    end

    context "コミュニティメンバーとしてログイン済み" do
      before { sign_in customer }

      it "コミュニティチャットのメッセージを検索できること" do
        create(:chat_message, customer: member, chat_room: chat_room, community: community, content: "来週のライブ告知です")

        get search_public_chat_room_path(chat_room), params: { q: "ライブ" }

        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)
        expect(json["html"]).to include("来週のライブ告知です")
      end
    end

    context "コミュニティ非メンバー(退会済み含む)としてログイン済み" do
      it "検索できず404を返すこと" do
        create(:chat_message, customer: member, chat_room: chat_room, community: community, content: "内容")
        non_member = create(:customer)
        sign_in non_member

        get search_public_chat_room_path(chat_room), params: { q: "内容" }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "存在しないchat_room" do
    it "存在しないIDでも同じ404を返し、実在ルームの権限エラーと区別できないこと" do
      sign_in customer
      get search_public_chat_room_path(id: 999_999), params: { q: "内容" }
      expect(response).to have_http_status(:not_found)
      expect(response.body).to be_blank
    end
  end
end
