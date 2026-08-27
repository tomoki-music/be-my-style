class EntryInvitationMailer < ApplicationMailer
  # イベント楽曲の演奏経験者へ送るエントリー依頼メール。
  # 1通=1受信者(To に複数人を入れない・CC/BCC を使わない)。
  # メールから直接エントリーは確定させず、イベント詳細ページへ誘導する。
  def invite(entry_invitation)
    @invitation = entry_invitation
    @recipient = entry_invitation.customer
    @sender = entry_invitation.requested_by_customer
    @event = entry_invitation.event
    @song = entry_invitation.song
    @join_part = entry_invitation.join_part
    @open_on = @event.event_start_time
    # 既存 CustomerMailer と同じく本番 URL をハードコードする。
    @event_url = "https://be-my-style.com/public/events/#{@event.id}"
    @mypage = "https://be-my-style.com/public/customers/#{@recipient.id}"

    mail(
      to: @recipient.email,
      subject: "【BeMyStyle】「#{@song.song_name}」の#{@join_part.join_part_name}にエントリーしませんか？"
    )
  end
end
