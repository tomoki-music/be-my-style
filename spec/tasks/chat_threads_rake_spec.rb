require "rails_helper"
require "rake"

RSpec.describe "chat:normalize_reply_threads rakeタスク" do
  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }
  let(:chat_room) { create(:chat_room) }

  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("chat:normalize_reply_threads")
  end

  def run_task
    Rake::Task["chat:normalize_reply_threads"].invoke
  ensure
    Rake::Task["chat:normalize_reply_threads"].reenable
  end

  it "「返信への返信」をスレッド親(thread_root)へ付け替えること" do
    root = create(:chat_message, customer: customer, chat_room: chat_room, content: "A")
    reply1 = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "B",
                                    reply_to_chat_message: root)
    # Chat::ReplyTargetResolverを経由しないモデル直接操作で、正規化前(Phase2時点)の
    # 「返信への返信」データ形状を再現する。
    reply2 = create(:chat_message, customer: customer, chat_room: chat_room, content: "D",
                                    reply_to_chat_message: reply1)

    run_task

    expect(reply2.reload.reply_to_chat_message_id).to eq root.id
  end

  it "正規化によって子を失った旧親のreplies_countも、新しい親の件数も正しく再計算されること" do
    root = create(:chat_message, customer: customer, chat_room: chat_room, content: "A")
    reply1 = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "B",
                                    reply_to_chat_message: root)
    reply2 = create(:chat_message, customer: customer, chat_room: chat_room, content: "D",
                                    reply_to_chat_message: reply1)

    # 正規化前: reply1はreply2という「子」を1件持っている状態(counter cacheが1)
    expect(reply1.reload.replies_count).to eq 1

    run_task

    # 正規化後: reply2はrootの子になり、reply1はもう誰の親でもない
    expect(root.reload.replies_count).to eq 2
    expect(reply1.reload.replies_count).to eq 0
  end

  it "循環参照のような壊れたデータでも例外にならず、返信リンクが解除されること" do
    a = create(:chat_message, customer: customer, chat_room: chat_room, content: "A")
    b = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "B")
    a.update_column(:reply_to_chat_message_id, b.id)
    b.update_column(:reply_to_chat_message_id, a.id)

    expect { run_task }.not_to raise_error

    # 循環参照は「安全側」としてどちらか一方(またはどちらも)返信リンクが解除されるか、
    # 自己参照(id == reply_to_chat_message_id)にはならないことを確認する。
    expect(a.reload.reply_to_chat_message_id).not_to eq a.id
    expect(b.reload.reply_to_chat_message_id).not_to eq b.id
  end

  it "2回実行しても結果が変わらないこと(冪等性)" do
    root = create(:chat_message, customer: customer, chat_room: chat_room, content: "A")
    reply1 = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "B",
                                    reply_to_chat_message: root)
    create(:chat_message, customer: customer, chat_room: chat_room, content: "D",
                          reply_to_chat_message: reply1)

    run_task
    first_run_reply_to_ids = ChatMessage.order(:id).pluck(:reply_to_chat_message_id)
    first_run_counts = ChatMessage.order(:id).pluck(:replies_count)

    run_task
    second_run_reply_to_ids = ChatMessage.order(:id).pluck(:reply_to_chat_message_id)
    second_run_counts = ChatMessage.order(:id).pluck(:replies_count)

    expect(second_run_reply_to_ids).to eq first_run_reply_to_ids
    expect(second_run_counts).to eq first_run_counts
  end

  it "DRY_RUN=trueの場合はデータを更新しないこと" do
    root = create(:chat_message, customer: customer, chat_room: chat_room, content: "A")
    reply1 = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "B",
                                    reply_to_chat_message: root)
    reply2 = create(:chat_message, customer: customer, chat_room: chat_room, content: "D",
                                    reply_to_chat_message: reply1)

    original_env = ENV["DRY_RUN"]
    ENV["DRY_RUN"] = "true"
    begin
      run_task
    ensure
      ENV["DRY_RUN"] = original_env
    end

    expect(reply2.reload.reply_to_chat_message_id).to eq reply1.id
  end
end
