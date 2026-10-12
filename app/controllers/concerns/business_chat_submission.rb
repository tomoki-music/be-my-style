# CommunityPost / ProjectChat の送信パラメータを組み立てる共通処理。
# スタンプ・添付の妥当性はモデル(BusinessChatContent)側で検証する。
module BusinessChatSubmission
  extend ActiveSupport::Concern

  private

  # 添付件数の上限を超える場合は、ファイルを読み込む前に nil を返して送信を止める。
  def business_chat_attributes(param_key)
    permitted = params.require(param_key).permit(:body, :stamp_type, attachments: [])
    files = Array(permitted.delete(:attachments)).select { |file| file.respond_to?(:original_filename) }
    return if files.size > BusinessChatContent::MAX_ATTACHMENTS

    permitted.merge(attachments: files, content_format: :markdown)
  end

  def business_chat_too_many_files_message
    "添付ファイルは#{BusinessChatContent::MAX_ATTACHMENTS}件までです"
  end

  def business_chat_error_message(record)
    messages = record.errors[:base].presence || record.errors.full_messages
    "送信できませんでした：#{messages.uniq.join(' / ')}"
  end
end
