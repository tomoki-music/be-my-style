# Chat内のURLリンクカード機能(Chat::LinkDetector)が「自ドメインのURL」と判定する
# ホスト一覧をここへ一元管理する。本番ドメインをサービスへ直接ハードコードしない。
#
# Chat::LinkPreviewHostConfig.resolveは必ず正規化済みのArrayを返す(nil・空文字を
# 返すことはない)。ここで得られる値をfreezeして格納することで、設定不備によって
# メッセージ投稿全体が500になることを防ぐ(Chat::LinkDetector側でもArray(...)による
# 二重の防御を入れている)。
#
# Chat::LinkPreviewHostConfigはapp/配下のautoload対象のため、initializer本体で直接
# 参照すると「Initialization autoloaded the constants ...」という非推奨警告が発生し、
# 起動直後にそのモジュールがunloadされてしまう(Rails 6.1で将来的にエラーになる予定の
# 挙動)。Railsが推奨するto_prepareブロック内で参照することでこれを避ける。
Rails.application.config.x.chat_link_preview = ActiveSupport::OrderedOptions.new

Rails.application.reloader.to_prepare do
  Rails.application.config.x.chat_link_preview.internal_hosts =
    Chat::LinkPreviewHostConfig.resolve(
      env_value: ENV["CHAT_LINK_PREVIEW_INTERNAL_HOSTS"],
      rails_env: Rails.env
    ).freeze
end
