# frozen_string_literal: true

module OpenProject
  module DatabaseManager
    # 数据库配置模型
    class DatabaseConfig < ActiveRecord::Base
      self.table_name = "database_configs"
      
      # 支持的数据库类型
      SUPPORTED_ADAPTERS = {
        sqlite3: "SQLite (轻量级)",
        postgresql: "PostgreSQL (生产级)",
        mysql2: "MySQL (通用型)"
      }.freeze
      
      # 验证
      validates :adapter, presence: true, inclusion: { in: SUPPORTED_ADAPTERS.keys.map(&:to_s) }
      validates :name, presence: true, uniqueness: true
      validates :database, presence: true
      
      # 序列化
      serialize :connection_options, JSON
      
      # 作用域
      scope :active, -> { where(is_active: true) }
      scope :by_adapter, ->(adapter) { where(adapter: adapter) }
      
      # 实例方法
      def connection_hash
        {
          adapter: adapter,
          database: database,
          host: host,
          port: port,
          username: username,
          password: password,
          pool: pool || 5,
          timeout: timeout || 5000,
          encoding: encoding || "utf8"
        }.merge(connection_options || {}).compact
      end
      
      def test_connection
        ActiveRecord::Base.establish_connection(connection_hash)
        ActiveRecord::Base.connection.active?
      rescue StandardError => e
        false
      end
      
      def database_size
        ActiveRecord::Base.establish_connection(connection_hash)
        case adapter
        when "sqlite3"
          File.exist?(database) ? File.size(database) : 0
        when "postgresql", "mysql2"
          # 查询数据库大小
          result = ActiveRecord::Base.connection.execute(
            "SELECT pg_database_size(current_database())"
          )
          result.first.values.first.to_i
        end
      rescue StandardError
        0
      end
      
      def human_size
        size = database_size
        if size < 1024
          "#{size} B"
        elsif size < 1024 * 1024
          "#{(size / 1024.0).round(2)} KB"
        elsif size < 1024 * 1024 * 1024
          "#{(size / 1024.0 / 1024.0).round(2)} MB"
        else
          "#{(size / 1024.0 / 1024.0 / 1024.0).round(2)} GB"
        end
      end
      
      class << self
        def current_config
          active.first || first
        end
        
        def switch_to(config_id)
          config = find(config_id)
          update_all(is_active: false)
          config.update(is_active: true)
          
          # 重新建立连接
          ActiveRecord::Base.establish_connection(config.connection_hash)
          
          config
        rescue StandardError => e
          Rails.logger.error "[DatabaseManager] Switch failed: #{e.message}"
          raise
        end
        
        def available_adapters
          SUPPORTED_ADAPTERS
        end
      end
    end
  end
end
