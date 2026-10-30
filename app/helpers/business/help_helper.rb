module Business
  # 使い方ページ(/business/help)の目次と、ログイン前トップ・使い方で共用する3ステップの文言。
  module HelpHelper
    HELP_SECTIONS = [
      ["help-about", "NAKAMAでできること"],
      ["help-structure", "コミュニティ・プロジェクト・スレッドの関係"],
      ["help-community", "コミュニティを探す・参加する"],
      ["help-project", "プロジェクトに参加し、スレッドで話す"],
      ["help-posting", "投稿・添付・スタンプの使い方"],
      ["help-status", "承認待ち・却下・アクセス停止の違い"],
      ["help-operator", "運営者向け：作成・編集・メンバー管理"],
      ["help-faq", "よくある質問"]
    ].freeze

    FLOW_STEPS = [
      { icon: "fa-users", title: "コミュニティに参加",
        text: "関心の近いコミュニティを探して参加します。承認制のコミュニティは、運営者が承認すると参加できます。" },
      { icon: "fa-layer-group", title: "プロジェクトで協力",
        text: "コミュニティの中のプロジェクトに参加し、目標や締切を共有して一緒に進めます。" },
      { icon: "fa-comments", title: "スレッドで話す",
        text: "プロジェクトの中で話題ごとにスレッドを分け、画像やファイル、スタンプを添えて話し合います。" }
    ].freeze
  end
end
