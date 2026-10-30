module Business
  # 使い方ページ(/business/help)の表示切り替え・目次と、ログイン前トップ・使い方で共用する3ステップの文言。
  module HelpHelper
    # 表示の切り替えは説明の出し分けだけで、権限は変えない。URL の audience で選び、知らない値は一般ユーザー向けにする。
    HELP_AUDIENCES = {
      "member" => "一般ユーザー向け",
      "admin" => "管理者向け"
    }.freeze
    DEFAULT_HELP_AUDIENCE = "member".freeze

    HELP_SECTIONS = {
      "member" => [
        ["help-about", "NAKAMAでできること"],
        ["help-structure", "コミュニティ・プロジェクト・スレッドの関係"],
        ["help-community", "コミュニティを探す・参加する"],
        ["help-project", "プロジェクトに参加する"],
        ["help-status", "承認待ち・却下・アクセス停止の違い"],
        ["help-posting", "投稿・添付・スタンプの使い方"],
        ["help-notifications", "通知を確認する"],
        ["help-leave", "退出する"],
        ["help-invited", "招待用URLを受け取ったとき"],
        ["help-faq", "よくある質問"]
      ],
      "admin" => [
        ["help-roles", "この説明での「管理者」とは"],
        ["help-create", "コミュニティ・プロジェクトを作成する"],
        ["help-edit", "コミュニティ・プロジェクトを編集する"],
        ["help-join-mode", "参加方式を選ぶ"],
        ["help-requests", "参加申請を承認・却下する"],
        ["help-suspend", "アクセスを停止する・解除する"],
        ["help-threads", "スレッドを管理する"],
        ["help-share", "招待用URLで誘う"],
        ["help-delete", "削除・編集できる人"]
      ]
    }.freeze

    FLOW_STEPS = [
      { icon: "fa-users", title: "コミュニティに参加",
        text: "関心の近いコミュニティを探して参加します。承認制のコミュニティは、運営者が承認すると参加できます。" },
      { icon: "fa-layer-group", title: "プロジェクトに参加",
        text: "コミュニティの中から、テーマに関心のあるプロジェクトに参加します。承認制のプロジェクトは、管理者が承認すると参加できます。" },
      { icon: "fa-comments", title: "スレッドで話す",
        text: "プロジェクトの中で話題ごとにスレッドを分け、画像やファイル、スタンプを添えて話し合います。" }
    ].freeze

    def business_help_audience(value)
      HELP_AUDIENCES.key?(value.to_s) ? value.to_s : DEFAULT_HELP_AUDIENCE
    end

    # 一般ユーザー向けは audience を付けない URL を正とする(初期表示と同じ)。
    def business_help_audience_path(audience, anchor: nil)
      audience = business_help_audience(audience)
      business_help_path(audience: (audience unless audience == DEFAULT_HELP_AUDIENCE), anchor: anchor)
    end
  end
end
