module Business
  # プロジェクト削除の確認画面に出す「一緒に削除されるもの」の件数。
  # 対象は Project の dependent: :destroy で実際に消えるものだけ(新しい連鎖削除はしない)。
  class ProjectDeletionImpact
    Item = CommunityDeletionImpact::Item

    def self.call(project)
      new(project).items
    end

    def initialize(project)
      @project = project
    end

    # always_shown でない項目(アクセス停止)は 1 件以上のときだけ出す。
    def items
      [
        Item.new(label: "スレッド", count: @project.project_threads.count, always_shown: true),
        Item.new(label: "スレッド内の投稿", count: @project.project_chats.count, always_shown: true),
        Item.new(label: "参加メンバーの登録(会員アカウントは残ります)", count: @project.project_members.count, always_shown: true),
        Item.new(label: "承認待ちの参加申請", count: @project.project_join_requests.count, always_shown: true),
        Item.new(label: "アクセス停止の設定", count: @project.project_access_suspensions.count, always_shown: false)
      ].select { |item| item.always_shown || item.count.positive? }
    end
  end
end
