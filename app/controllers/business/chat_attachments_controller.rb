# Business のタイムライン / プロジェクトチャットに添付されたファイルの配信窓口。
# 投稿本文を閲覧できる人(タイムライン=コミュニティ参加者 / プロジェクトチャット=プロジェクト参加者)だけに、短時間で失効する署名付き URL を発行してリダイレクトする。
# 画面には ActiveStorage の恒久的な blob URL を出さないため、URL を共有されても権限を迂回できない。
class Business::ChatAttachmentsController < ApplicationController
  include ActiveStorage::SetCurrent

  URL_EXPIRES_IN = 5.minutes
  THUMBNAIL_SIZE = [480, 480].freeze

  def show
    attachment = ActiveStorage::Attachment.find_by(
      id: params[:id],
      name: "attachments",
      record_type: %w[CommunityPost ProjectChat]
    )
    # 存在有無も推測されないよう、権限が無い場合も 404 にそろえる。
    return head :not_found unless attachment && readable?(attachment.record)

    response.headers["Cache-Control"] = "private, no-store"
    redirect_to signed_url_for(attachment)
  end

  private

  def readable?(record)
    case record
    # 本文を表示する画面と同じ判定(BusinessAccess)を使う。
    when CommunityPost
      current_customer.business_community_participant?(record.community)
    when ProjectChat
      current_customer.business_project_participant?(record.project)
    else
      false
    end
  end

  # 画像だけをブラウザ内で表示し、PDF・Office 資料は常にダウンロードさせる。
  def signed_url_for(attachment)
    return attachment.url(expires_in: URL_EXPIRES_IN, disposition: :attachment) unless BusinessChatContent.inline_image?(attachment)

    target = params[:variant] == "thumb" ? thumbnail_for(attachment) : attachment
    target.url(expires_in: URL_EXPIRES_IN, disposition: :inline)
  end

  def thumbnail_for(attachment)
    attachment.variant(resize_to_limit: THUMBNAIL_SIZE).processed
  rescue StandardError => e
    # 変換できない画像でも原寸で表示できるようにする(画面側で大きさを制限している)。
    Rails.logger.warn("[Business::ChatAttachments] thumbnail failed attachment_id=#{attachment.id} #{e.class}")
    attachment
  end
end
