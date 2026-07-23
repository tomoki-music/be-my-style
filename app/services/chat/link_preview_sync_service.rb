module Chat
  # 保存済みChatMessageの本文から検出したURL集合と、既存のChatMessageLinkPreviewの
  # URL集合を比較し、変化が無ければ何もしない(無駄な再取得を避ける)。
  # 変化がある場合のみ、既存分を全て破棄して検出結果から作り直す。
  #
  # 同一動画(provider, external_id)が直近30日以内に取得成功していれば、
  # 別メッセージ分であってもそのデータを再利用し、Jobをenqueueしない
  # (ChatMessageLinkPreview::CACHE_EXPIRES_IN)。
  #
  # Jobのenqueueは、破棄・作成を行うトランザクションのコミット後に行う。
  # ActiveJobのqueue_adapterは本番含めて:async(Pumaワーカー内の別スレッドで
  # ほぼ即時実行され得る)であるため、トランザクション内でenqueueすると
  # コミット前のレコードをJobが参照しようとする競合状態になり得るため。
  class LinkPreviewSyncService
    def self.call(chat_message)
      new(chat_message).sync
    end

    def initialize(chat_message)
      @chat_message = chat_message
    end

    def sync
      detected = Chat::LinkDetector.call(@chat_message.content)
      return if unchanged?(detected)

      preview_ids_to_fetch = []

      ActiveRecord::Base.transaction do
        @chat_message.chat_message_link_previews.destroy_all
        detected.each_with_index do |candidate, index|
          preview = create_preview(candidate, index)
          preview_ids_to_fetch << preview.id if preview.pending?
        end
      end

      preview_ids_to_fetch.each { |id| Chat::LinkPreviewFetchJob.perform_later(id) }
    end

    private

    def unchanged?(detected)
      detected_keys = detected.map { |candidate| [candidate.provider.to_s, candidate.external_id] }.sort
      existing_keys = @chat_message.chat_message_link_previews.map { |preview| [preview.provider, preview.external_id] }.sort
      detected_keys == existing_keys
    end

    def create_preview(candidate, position)
      cached = reusable_cache(candidate)

      @chat_message.chat_message_link_previews.create!(
        provider: candidate.provider,
        url: candidate.url,
        external_id: candidate.external_id,
        position: position,
        status: cached ? :fetched : :pending,
        title: cached&.title,
        author_name: cached&.author_name,
        thumbnail_url: cached&.thumbnail_url,
        fetched_at: cached&.fetched_at
      )
    end

    def reusable_cache(candidate)
      ChatMessageLinkPreview
        .where(provider: candidate.provider, external_id: candidate.external_id, status: :fetched)
        .where("fetched_at > ?", ChatMessageLinkPreview::CACHE_EXPIRES_IN.ago)
        .order(fetched_at: :desc)
        .first
    end
  end
end
