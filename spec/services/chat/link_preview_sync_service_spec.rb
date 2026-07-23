require "rails_helper"

RSpec.describe Chat::LinkPreviewSyncService, type: :service do
  let(:customer) { create(:customer) }
  let(:chat_room) { create(:chat_room) }
  let(:video_url) { "https://www.youtube.com/watch?v=dQw4w9WgXcQ" }

  def sync(chat_message)
    described_class.call(chat_message)
  end

  it "URLを含む新規メッセージでpendingなプレビューを作成し、Jobをenqueueすること" do
    chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "見て #{video_url}")

    expect {
      sync(chat_message)
    }.to change(ChatMessageLinkPreview, :count).by(1)
       .and have_enqueued_job(Chat::LinkPreviewFetchJob)

    preview = chat_message.chat_message_link_previews.first
    expect(preview.provider).to eq "youtube"
    expect(preview.external_id).to eq "dQw4w9WgXcQ"
    expect(preview.status).to eq "pending"
    expect(preview.position).to eq 0
  end

  it "URLを含まないメッセージではプレビューを作成しないこと" do
    chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "こんにちは")

    expect { sync(chat_message) }.not_to change(ChatMessageLinkPreview, :count)
  end

  it "本文編集でURL集合が変わらない場合、再取得(Job enqueue)しないこと" do
    chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "見て #{video_url}")
    sync(chat_message)
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear

    chat_message.update!(content: "見てね #{video_url} 良い曲です")

    expect {
      sync(chat_message)
    }.not_to change(ChatMessageLinkPreview, :count)
    expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq 0
  end

  it "編集でURLが追加された場合、追加分についてのみ再取得すること" do
    chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "見て #{video_url}")
    sync(chat_message)
    ChatMessageLinkPreview.update_all(status: :fetched, fetched_at: Time.current, title: "既存タイトル")

    second_url = "https://youtu.be/bbbbbbbbbbb"
    chat_message.update!(content: "見て #{video_url} #{second_url}")

    expect {
      sync(chat_message)
    }.to change(ChatMessageLinkPreview, :count).by(1)

    previews = chat_message.reload.chat_message_link_previews.order(:position)
    expect(previews.map(&:external_id)).to eq %w[dQw4w9WgXcQ bbbbbbbbbbb]
  end

  it "編集でURLが削除された場合、対応するプレビューが削除されること" do
    second_url = "https://youtu.be/bbbbbbbbbbb"
    chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room,
                                                      content: "#{video_url} #{second_url}")
    sync(chat_message)
    expect(chat_message.chat_message_link_previews.count).to eq 2

    chat_message.update!(content: video_url)

    expect {
      sync(chat_message)
    }.to change(ChatMessageLinkPreview, :count).by(-1)
    expect(chat_message.reload.chat_message_link_previews.pluck(:external_id)).to eq %w[dQw4w9WgXcQ]
  end

  it "同一動画が30日以内に取得成功済みの場合、キャッシュを再利用しJobをenqueueしないこと" do
    other_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: video_url)
    sync(other_message)
    other_message.chat_message_link_previews.first.update!(
      status: :fetched, fetched_at: 1.day.ago, title: "キャッシュ済みタイトル", thumbnail_url: "https://img.example.com/x.jpg"
    )

    chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: video_url)

    expect {
      sync(chat_message)
    }.not_to have_enqueued_job(Chat::LinkPreviewFetchJob)

    preview = chat_message.chat_message_link_previews.first
    expect(preview.status).to eq "fetched"
    expect(preview.title).to eq "キャッシュ済みタイトル"
  end

  it "同一動画の取得成功データが30日より古い場合はキャッシュを使わず再取得すること" do
    other_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: video_url)
    sync(other_message)
    other_message.chat_message_link_previews.first.update!(status: :fetched, fetched_at: 31.days.ago, title: "古いタイトル")

    chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: video_url)

    expect {
      sync(chat_message)
    }.to have_enqueued_job(Chat::LinkPreviewFetchJob)

    expect(chat_message.chat_message_link_previews.first.status).to eq "pending"
  end
end
