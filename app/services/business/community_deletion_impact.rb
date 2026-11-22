module Business
  # コミュニティ削除の確認画面に出す「一緒に削除されるもの」の件数。
  # 対象は Community / Project の dependent: :destroy で実際に消えるものだけ(新しい連鎖削除はしない)。
  class CommunityDeletionImpact
    Item = Struct.new(:label, :count, :always_shown, keyword_init: true)

    def self.call(community)
      new(community).items
    end

    def initialize(community)
      @community = community
    end

    # always_shown の項目は 0 件でも出し、それ以外(Business では通常使わない音楽側の関連)は 1 件以上のときだけ出す。
    def items
      project_ids = @community.projects.select(:id)

      [
        Item.new(label: "プロジェクト", count: @community.projects.count, always_shown: true),
        Item.new(label: "プロジェクトのスレッド", count: ProjectThread.where(project_id: project_ids).count, always_shown: true),
        Item.new(label: "プロジェクト内の投稿", count: ProjectChat.where(project_id: project_ids).count, always_shown: true),
        Item.new(label: "タイムラインの投稿", count: @community.community_posts.count, always_shown: true),
        Item.new(label: "参加メンバーの登録(会員アカウントは残ります)", count: @community.community_customers.count, always_shown: true),
        Item.new(label: "承認待ちの参加申請", count: @community.permits.count, always_shown: true),
        Item.new(label: "主催イベント", count: @community.events.count, always_shown: false),
        Item.new(label: "コミュニティチャットのメッセージ", count: @community.chat_messages.count, always_shown: false)
      ].select { |item| item.always_shown || item.count.positive? }
    end
  end
end
