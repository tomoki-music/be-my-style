require "rails_helper"

RSpec.describe Chat::LinkPreviewFetchJob, type: :job do
  let(:customer) { create(:customer) }
  let(:chat_room) { create(:chat_room) }
  let(:chat_message) { create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "https://www.youtube.com/watch?v=dQw4w9WgXcQ") }
  let(:preview) do
    create(:chat_message_link_preview, chat_message: chat_message, provider: :youtube, external_id: "dQw4w9WgXcQ",
                                        url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ", position: 0, status: :pending)
  end

  describe "#perform" do
    it "取得成功時、title/author_name/thumbnail_urlを保存しfetchedにすること" do
      allow(Chat::LinkPreviews::YoutubeFetcher).to receive(:call).with(preview.url).and_return(
        title: "テスト動画", author_name: "テストチャンネル", thumbnail_url: "https://i.ytimg.com/vi/xxx/hqdefault.jpg"
      )

      described_class.perform_now(preview.id)

      preview.reload
      expect(preview).to be_fetched
      expect(preview.title).to eq "テスト動画"
      expect(preview.author_name).to eq "テストチャンネル"
      expect(preview.thumbnail_url).to eq "https://i.ytimg.com/vi/xxx/hqdefault.jpg"
      expect(preview.fetched_at).to be_present
    end

    it "取得失敗時、statusをfailedにしてfailure_reasonを保存すること" do
      allow(Chat::LinkPreviews::YoutubeFetcher).to receive(:call).and_raise(
        Chat::LinkPreviews::YoutubeFetcher::RequestError, "status 404"
      )

      described_class.perform_now(preview.id)

      preview.reload
      expect(preview).to be_failed
      expect(preview.failure_reason).to include("status 404")
    end

    it "既にfetched/failedのプレビューは再実行しないこと(冪等)" do
      preview.update!(status: :fetched, title: "既存タイトル", fetched_at: Time.current)

      expect(Chat::LinkPreviews::YoutubeFetcher).not_to receive(:call)
      described_class.perform_now(preview.id)

      expect(preview.reload.title).to eq "既存タイトル"
    end

    it "対象レコードが既に削除されている場合は何もしないこと" do
      deleted_id = preview.id
      preview.destroy!

      expect { described_class.perform_now(deleted_id) }.not_to raise_error
    end
  end
end
