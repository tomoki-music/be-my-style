module EntryInvitations
  # エントリー依頼パネルから送られてくる targets 配列を厳格にパースする。
  #
  # 形式は "song_id:join_part_id:customer_id"(いずれも正の整数)のみ受け付ける。
  # ユーザーが組み立てた文字列を一切信用せず、正規表現に完全一致する要素だけを
  # 3 つ組の Integer へ変換する。nil・配列以外・不正形式は安全に捨てる。
  module TargetParser
    FORMAT = /\A\d+:\d+:\d+\z/.freeze

    # 一度の依頼で選択できる上限。現実的な経験者候補数(イベント全体で数十人規模)を
    # 十分に上回りつつ、確認画面(new)への GET クエリ長が過大にならない値。
    # 1 件あたり "targets[]=99999:99999:999999&" ≒ 32 文字。100 件でも 3KB 強に収まる。
    MAX_TARGETS = 100

    module_function

    # 戻り値: [[song_id, join_part_id, customer_id], ...](すべて Integer, uniq 済み)
    def parse(raw)
      tokens =
        if raw.is_a?(Array)
          raw
        elsif raw.is_a?(String)
          [raw]
        else
          []
        end

      tokens.filter_map do |token|
        str = token.to_s.strip
        next unless str.match?(FORMAT)

        str.split(":", 3).map(&:to_i)
      end.uniq
    end
  end
end
