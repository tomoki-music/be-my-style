require "rails_helper"
require Rails.root.join("lib/migration_lock_wait_timeout")

# テスト環境は SQLite のため、MySQL の接続を模したオブジェクトで SET の順序と復元だけを確認する。
# 実際のロック待ち(時間切れ・再実行)は使い捨ての MySQL で確認している(リリースノート参照)。
RSpec.describe MigrationLockWaitTimeout do
  let(:fake_connection_class) do
    Class.new do
      attr_reader :statements

      def initialize
        @statements = []
      end

      def adapter_name
        "Mysql2"
      end

      def select_rows(_sql)
        [[31_536_000, 50]]
      end

      def execute(sql)
        @statements << sql
      end
    end
  end

  let(:conn) { fake_connection_class.new }

  def migration_class(&up)
    Class.new(ActiveRecord::Migration[6.1]) do
      include MigrationLockWaitTimeout

      define_method(:up) do
        connection.execute("ALTER")
        instance_exec(&up)
      end
    end
  end

  it "マイグレーションの間だけセッションの待ち時間を短くし、終わったら元に戻す" do
    migration_class { nil }.new.exec_migration(conn, :up)

    expect(conn.statements).to eq [
      "SET SESSION lock_wait_timeout = 5, innodb_lock_wait_timeout = 10",
      "ALTER",
      "SET SESSION lock_wait_timeout = 31536000, innodb_lock_wait_timeout = 50"
    ]
  end

  it "時間切れで失敗しても元に戻し、エラーはそのまま伝える" do
    migration = migration_class { raise ActiveRecord::LockWaitTimeout, "Lock wait timeout exceeded" }.new

    expect { migration.exec_migration(conn, :up) }.to raise_error(ActiveRecord::LockWaitTimeout)
    expect(conn.statements.last).to eq "SET SESSION lock_wait_timeout = 31536000, innodb_lock_wait_timeout = 50"
  end

  it "MySQL 以外の接続では何も設定しない" do
    allow(conn).to receive(:adapter_name).and_return("SQLite")
    migration_class { nil }.new.exec_migration(conn, :up)

    expect(conn.statements).to eq ["ALTER"]
  end
end
