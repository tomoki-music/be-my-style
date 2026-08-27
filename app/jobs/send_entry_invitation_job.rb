class SendEntryInvitationJob < ApplicationJob
  queue_as :default

  # 受信者ごとに1通ずつ個別送信する。成否を EntryInvitation.status へ反映し、
  # 途中失敗しても「誰へ送れたか」を履歴・画面から追えるようにする。
  def perform(entry_invitation_id)
    invitation = EntryInvitation.find_by(id: entry_invitation_id)
    return if invitation.nil?
    return unless invitation.pending?

    EntryInvitationMailer.invite(invitation).deliver_now
    invitation.update!(status: :delivered)
  rescue => e
    Rails.logger.error("[SendEntryInvitationJob] invitation=#{entry_invitation_id} #{e.class}: #{e.message}")
    invitation&.update!(status: :failed, failure_reason: e.message.to_s.truncate(250))
    # 無限リトライ(と実在ユーザーへの多重送信)を避けるため re-raise しない。
  end
end
