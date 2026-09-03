require 'rails_helper'

RSpec.describe "Public::Requests", type: :request do
  let(:customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:other_customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:community) { FactoryBot.create(:community) }
  let(:join_part) { FactoryBot.create(:join_part, song: song) }
  let(:song) { FactoryBot.create(:song, :song_with_parts, event: event) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, customer: customer, community: community) }
  let(:request) { FactoryBot.create(:request, customer_id: other_customer.id, event_id: event.id) }

  describe 'ログイン済み' do
    before do
      sign_in customer
      get public_event_path(event)
    end
    context "リクエスト(create)が正しく処理され登録される" do
      it "リクエストの作成が成功する" do
        expect do
          post public_event_requests_path(event_id: event.id), params: {
            request: {
              request: "オリジナル曲を１曲お願いします！",
            }
          }
        end.to change(Request, :count).by(1)
      end
    end
    context "リクエストを正しく削除(destroy)できる" do
      before do
        request
      end
      it '正しく削除できる（リクエスト本人である場合）' do
        expect do
          delete public_event_request_path(event_id: event.id, id: request.id)
        end.to change(Request, :count).by(-1)
      end
    end
    context "コメントを正しく削除(destroy)できない" do
      before do
        sign_in other_customer
      end
      it 'リクエストは302 Foundとなること（投稿者本人でない場合）' do
        delete public_event_request_path(event_id: event.id, id: request.id)
        expect(response.status).to eq 302
      end
    end

    context "みんなのリクエストのYouTubeカード表示" do
      it "YouTube URLを含むリクエストを投稿すると、イベント画面にサムネイルカードが表示されること" do
        post public_event_requests_path(event_id: event.id), params: {
          request: {
            request: "この曲でお願いします！ https://www.youtube.com/watch?v=abcdefghijk"
          }
        }, xhr: true

        get public_event_path(event)

        expect(response.status).to eq 200
        expect(response.body).to include("img.youtube.com/vi/abcdefghijk/hqdefault.jpg")
      end

      it "URLを含まないリクエストではカードが表示されないこと(既存表示を維持)" do
        post public_event_requests_path(event_id: event.id), params: {
          request: {
            request: "オリジナル曲を１曲お願いします！"
          }
        }, xhr: true

        get public_event_path(event)

        expect(response.status).to eq 200
        expect(response.body).not_to include("event-song-youtube-card")
      end

      it "不正なURLを含むリクエストでも500エラーにならず、リンクとして描画されないこと" do
        post public_event_requests_path(event_id: event.id), params: {
          request: {
            request: "javascript:alert(1)"
          }
        }, xhr: true

        get public_event_path(event)

        expect(response.status).to eq 200
        expect(response.body).not_to include('href="javascript:alert(1)"')
        expect(response.body).not_to include("event-song-youtube-card")
      end
    end

    context "Markdown入力補助ツールバー" do
      it "みんなのリクエスト欄にツールバーが表示されること" do
        get public_event_path(event)

        expect(response.body).to match(/data-markdown-toolbar-root=['"]request['"]/)
        expect(response.body).to include("見出し")
        expect(response.body).to include("箇条書き")
        expect(response.body).to include("番号リスト")
        expect(response.body).to include("引用")
        expect(response.body).to include("リンク")
        expect(response.body).to include("プレビュー")
        expect(response.body).to include("文字を選択して、上のボタンから装飾できます")
      end

      it "対象のtextarea(#input_request)にdata-markdown-toolbar-textarea属性が付与されること" do
        get public_event_path(event)

        expect(response.body).to match(/<textarea[^>]*id="input_request"[^>]*data-markdown-toolbar-textarea="true"/)
      end
    end

    context "Markdownプレビュー(preview)" do
      it "Markdown記法を保存済み表示と同じHTMLへ変換して返すこと" do
        post preview_public_event_requests_path(event_id: event.id), params: { content: "**太字**の確認" }, xhr: true

        json = JSON.parse(response.body)
        expect(response.status).to eq 200
        expect(json["html"]).to include("<strong>太字</strong>")
      end

      it "危険なHTML(scriptタグ)は無害化されること" do
        post preview_public_event_requests_path(event_id: event.id), params: { content: "<script>alert(1)</script>本文" }, xhr: true

        json = JSON.parse(response.body)
        expect(json["html"]).not_to include("<script>")
      end

      it "javascript:スキームのリンクは無害化されること" do
        post preview_public_event_requests_path(event_id: event.id), params: { content: "[危険](javascript:alert(1))" }, xhr: true

        json = JSON.parse(response.body)
        expect(json["html"]).not_to include('href="javascript:alert(1)"')
      end

      it "保存済みリクエストの表示(Requests::MentionTextRenderer)と同じ変換結果になること" do
        content = "1曲目：オリジナル曲\n2曲目：**カバー曲**をお願いします"
        post preview_public_event_requests_path(event_id: event.id), params: { content: content }, xhr: true

        json = JSON.parse(response.body)
        expect(json["html"]).to eq(Requests::MentionTextRenderer.call(content, valid_customer_ids: []).to_s)
      end
    end

    context "スタンプ投稿" do
      it "スタンプ選択ボタンとパネル(10種)がリクエストフォームに表示されること" do
        get public_event_path(event)

        expect(response.body).to include('data-stamp-picker-toggle')
        Stampable::STAMP_DEFINITIONS.each_value do |definition|
          expect(response.body).to include(definition[:label])
        end
      end

      it "有効なスタンプキーでリクエストを投稿でき、本文は空で保存されること" do
        expect do
          post public_event_requests_path(event_id: event.id),
               params: { request: { stamp_type: "like" } }, xhr: true
        end.to change(Request, :count).by(1)

        created = Request.order(:created_at).last
        expect(created.stamp_type).to eq "like"
        expect(created.request).to be_blank
      end

      it "10種すべてのスタンプを投稿できること" do
        Stampable::STAMP_DEFINITIONS.each_key do |key|
          expect do
            post public_event_requests_path(event_id: event.id),
                 params: { request: { stamp_type: key } }, xhr: true
          end.to change(Request, :count).by(1)
        end
      end

      it "投稿したスタンプが正しい画像と代替テキストで一覧に表示されること" do
        post public_event_requests_path(event_id: event.id),
             params: { request: { stamp_type: "wonderful" } }, xhr: true

        get public_event_path(event)

        expect(response.body).to include("stamp-illustration")
        expect(response.body).to match(%r{stamps/stamp_wonderful[^"']*\.svg})
        expect(response.body).to match(/alt=["']素敵["']/)
      end

      it "不正なスタンプキー(任意URL)は保存されず、リクエストが作成されないこと" do
        expect do
          post public_event_requests_path(event_id: event.id),
               params: { request: { stamp_type: "https://evil.example.com/x.svg" } }, xhr: true
        end.not_to change(Request, :count)
      end

      it "パストラバーサルを含むスタンプキーは拒否されること" do
        expect do
          post public_event_requests_path(event_id: event.id),
               params: { request: { stamp_type: "../../etc/passwd" } }, xhr: true
        end.not_to change(Request, :count)
      end

      it "HTML/JavaScriptをスタンプキーに指定しても保存されないこと" do
        expect do
          post public_event_requests_path(event_id: event.id),
               params: { request: { stamp_type: "<img src=x onerror=alert(1)>" } }, xhr: true
        end.not_to change(Request, :count)
      end
    end

    context "複数行・Markdown記法のリクエスト" do
      it "改行を保持したまま保存され、Markdown記法もHTMLへ展開されて表示されること" do
        post public_event_requests_path(event_id: event.id), params: {
          request: {
            request: "1曲目：オリジナル曲\n2曲目：**カバー曲**をお願いします"
          }
        }, xhr: true

        created = Request.order(:created_at).last
        expect(created.request).to eq("1曲目：オリジナル曲\n2曲目：**カバー曲**をお願いします")

        get public_event_path(event)

        expect(response.body).to include("1曲目：オリジナル曲<br>")
        expect(response.body).to include("<strong>カバー曲</strong>")
      end
    end
  end

  describe '非ログイン' do
    it "プレビューAPIは未ログインだとログイン画面へリダイレクトされること" do
      # 注: このファイルのトップレベルlet(:request)がRequestモデルのFactoryインスタンスを
      # 指すため、`request`という名前を暗黙に参照するredirect_toマッチャは使わず、
      # ステータス・Locationヘッダを直接検証する(このファイルの他の未ログイン系検証と同じ方式)。
      post preview_public_event_requests_path(event_id: event.id), params: { content: "**太字**" }

      expect(response.status).to eq 302
      expect(response.location).to include("/customers/sign_in")
    end
  end
end
