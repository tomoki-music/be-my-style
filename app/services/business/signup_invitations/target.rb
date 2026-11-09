module Business
  module SignupInvitations
    # 招待用URL(Business::ShareHelper#business_share_url)が指す詳細画面のパスと、その対象の相互変換・検証。
    # 招待用URLはトークンを持たないため、詳細画面のパスそのものを招待先として扱う。対象はサーバー側で読み直して確かめる。
    module Target
      PATH_PATTERN = %r{\A/business/(communities|projects)/(\d+)\z}.freeze
      TYPES_BY_SEGMENT = { "communities" => "Community", "projects" => "Project" }.freeze

      module_function

      # "/business/communities/12" → ["Community", 12]。招待用URL以外の形(一覧・編集・クエリ付きなど)は nil。
      def parse(path)
        match = PATH_PATTERN.match(path.to_s)
        return unless match

        [TYPES_BY_SEGMENT.fetch(match[1]), match[2].to_i]
      end

      # いまも存在する Business のコミュニティ・プロジェクトなら、その詳細画面のパス。削除済み・Business 以外は nil。
      # 開いた人が中身を見られるかは詳細画面側の判定(参加・承認・停止)に任せる。
      def path_for(type, id)
        routes = Rails.application.routes.url_helpers

        case type
        when "Community"
          community = business_communities.find_by(id: id)
          community && routes.business_community_path(community)
        when "Project"
          project = Project.where(community_id: business_communities.select(:id)).find_by(id: id)
          project && routes.business_project_path(project)
        end
      end

      def business_communities
        Community.where(domain_id: Domain.where(name: "business").select(:id))
      end
    end
  end
end
