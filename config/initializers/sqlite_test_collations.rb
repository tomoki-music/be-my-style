# frozen_string_literal: true

# The development/production databases use MySQL, so db/schema.rb may contain
# MySQL-specific collation names. Test uses SQLite locally; register compatible
# SQLite collations so schema loading can keep using the checked-in schema.
if Rails.env.test?
  ActiveSupport.on_load(:active_record_sqlite3adapter) do
    module BeMyStyleSQLiteTestCollations
      MYSQL_COMPATIBLE_COLLATIONS = %w[
        utf8mb3_bin
        utf8mb4_0900_ai_ci
        utf8mb4_general_ci
      ].freeze

      def configure_connection
        super
        register_mysql_compatible_collations
      end

      private

      def register_mysql_compatible_collations
        MYSQL_COMPATIBLE_COLLATIONS.each do |collation_name|
          @connection.collation(collation_name, ->(left, right) { left.to_s <=> right.to_s })
        end
      end
    end

    prepend BeMyStyleSQLiteTestCollations
  end
end
