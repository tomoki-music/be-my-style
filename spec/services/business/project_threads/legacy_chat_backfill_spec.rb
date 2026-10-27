require "rails_helper"

RSpec.describe Business::ProjectThreads::LegacyChatBackfill do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business") }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:project) { Project.create!(community: community, customer: owner, title: "企画") }

  # マイグレーション後〜Puma 再起動前に旧コードが書き込んだ(スレッド未所属の)チャットを再現する。
  def legacy_chat(body, created_at:, target: project)
    # 旧コードはスレッドを知らないため、検証・コールバック無しで保存する。
    chat = ProjectChat.new(project: target, customer: owner, body: body, created_at: created_at, updated_at: created_at)
    chat.save!(validate: false)
    chat.update_columns(project_thread_id: nil)
    chat
  end

  # 旧コードで作られた(全体トークの無い)プロジェクトを再現する。
  def legacy_project(title)
    Project.create!(community: community, customer: owner, title: title).tap { |created| created.project_threads.delete_all }
  end

  it "本文・投稿者・日時・添付を変えずに「全体トーク」へ紐づけ、何度実行しても同じ結果になる" do
    default_thread = ProjectThread.default_for(project)
    chat = legacy_chat("旧コードの投稿", created_at: 1.minute.from_now)
    chat.attachments.attach(io: StringIO.new("%PDF-1.4"), filename: "a.pdf", content_type: "application/pdf")
    before = chat.reload.attributes.except("project_thread_id")

    expect(described_class.call.linked).to eq 1
    expect(described_class.call.linked).to eq 0

    chat.reload
    expect(chat.project_thread).to eq default_thread
    expect(chat.attributes.except("project_thread_id")).to eq before
    expect(chat.attachments.count).to eq 1
    expect(default_thread.reload.last_posted_at).to be_within(1.second).of(chat.created_at)
  end

  it "旧コードで作られたプロジェクトには、投稿が無くても「全体トーク」を1つだけ作る" do
    empty = legacy_project("投稿なし")
    with_chat = legacy_project("投稿あり")
    chat = legacy_chat("旧コードの投稿", created_at: Time.current, target: with_chat)

    result = described_class.call

    expect(result.created_threads).to eq 2
    expect(empty.reload.project_threads.pluck(:title, :general)).to eq [["全体トーク", true]]
    expect(chat.reload.project_thread).to eq ProjectThread.default_for(with_chat)
    expect { described_class.call }.not_to change(ProjectThread, :count)
  end

  it "全体トークが無く別の話題のスレッドがあるときも、未所属の投稿を別スレッドへ混ぜない" do
    target = legacy_project("話題スレッドだけ")
    topic = target.project_threads.create!(customer: owner, title: "デザイン相談")
    chat = legacy_chat("全体向けの連絡", created_at: Time.current, target: target)

    described_class.call(project: target)

    general = ProjectThread.default_for(target)
    expect(general).to be_present
    expect(general).not_to eq topic
    expect(chat.reload.project_thread).to eq general
    expect(topic.project_chats).to be_empty
  end

  it "同時に補完されても、一意制約で全体トークは1つだけになる" do
    target = legacy_project("同時アクセス")
    # 別のリクエストが先に全体トークを作った直後(こちらはまだ見つけていない)状態を再現する。
    allow(ProjectThread).to receive(:default_for).and_call_original
    allow(ProjectThread).to receive(:default_for).with(target).and_return(nil, nil)
    ProjectThread.create!(project: target, customer: owner, title: "全体トーク", general: true)

    expect(ProjectThread.general_for!(target)).to eq target.project_threads.find_by(general: true)
    expect(target.project_threads.where(general: true).count).to eq 1
  end

  it "作成者が完全削除されたプロジェクトでも全体トークを補完できる" do
    target = legacy_project("作成者なし")
    target.update_column(:customer_id, nil)

    described_class.call(project: target)

    expect(ProjectThread.default_for(target).customer).to be_nil
  end

  it "失敗した場合はそのプロジェクトの処理を巻き戻し、投稿・添付を変えずにログへ残す" do
    chat = legacy_chat("旧コードの投稿", created_at: Time.current)
    chat.attachments.attach(io: StringIO.new("%PDF-1.4"), filename: "a.pdf", content_type: "application/pdf")
    allow(ProjectThread).to receive(:general_for!).and_raise(ActiveRecord::LockWaitTimeout)
    allow(Rails.logger).to receive(:error)

    expect(described_class.call_safely(project: project)).to eq false

    chat.reload
    expect(chat.project_thread_id).to be_nil
    expect(chat.body).to eq "旧コードの投稿"
    expect(chat.attachments.count).to eq 1
    expect(Rails.logger).to have_received(:error).with(/failed project_id=#{project.id}/)
  end
end
