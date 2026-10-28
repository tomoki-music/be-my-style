# マイグレーションの接続だけ、ロック待ちの上限を短くする(サーバー全体の設定は変えない)。
# 本番の lock_wait_timeout は既定の1年。ALTER がメタデータロックを待つ間は、同じ表への後続の問い合わせも
# その後ろで待たされるため、長いトランザクションが残っていると migrate もサイトも止まり続ける。
# 上限を超えたらそのマイグレーションは失敗し(schema_migrations に記録されない)、各マイグレーションは
# 途中から再実行できるので、待ちの原因が解消してから migrate をやり直す。
module MigrationLockWaitTimeout
  # ALTER のメタデータロック待ち(秒)。待っている間は同じ表の読み書きも止まるため短くする。
  METADATA_LOCK_WAIT_SECONDS = 5
  # 行ロック待ち(秒)。既存チャットを全体トークへ紐づける UPDATE が対象。
  ROW_LOCK_WAIT_SECONDS = 10

  def exec_migration(conn, direction)
    return super unless conn.adapter_name.match?(/mysql/i)

    previous = conn.select_rows("SELECT @@SESSION.lock_wait_timeout, @@SESSION.innodb_lock_wait_timeout").first
    conn.execute("SET SESSION lock_wait_timeout = #{METADATA_LOCK_WAIT_SECONDS}, innodb_lock_wait_timeout = #{ROW_LOCK_WAIT_SECONDS}")
    begin
      super
    ensure
      conn.execute("SET SESSION lock_wait_timeout = #{Integer(previous[0])}, innodb_lock_wait_timeout = #{Integer(previous[1])}")
    end
  end
end
