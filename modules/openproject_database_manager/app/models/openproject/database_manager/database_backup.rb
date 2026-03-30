# frozen_string_literal: true

module OpenProject
  module DatabaseManager
    # 数据库备份模型
    class DatabaseBackup < ActiveRecord::Base
      belongs_to :database_config
      
      # 验证
      validates :backup_name, presence: true
      validates :backup_path, presence: true
      validates :backup_type, inclusion: { in: %w(full incremental) }
      validates :compression, inclusion: { in: %w(none gzip zip) }
      validates :status, inclusion: { in: %w(pending running completed failed) }
      
      # 作用域
      scope :completed, -> { where(status: "completed") }
      scope :failed, -> { where(status: "failed") }
      scope :auto_backups, -> { where(is_auto_backup: true) }
      scope :manual_backups, -> { where(is_auto_backup: false) }
      scope :expired, -> { where("expires_at IS NOT NULL AND expires_at < ?", Time.current) }
      scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
      
      # 常量
      BACKUP_DIR = Rails.root.join("db", "backups")
      
      # 实例方法
      def file_exists?
        File.exist?(backup_path)
      end
      
      def file_size
        file_exists? ? File.size(backup_path) : 0
      end
      
      def human_size
        size = file_size
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
      
      def is_expired?
        expires_at && expires_at < Time.current
      end
      
      def download_path
        "/database_manager/api/backups/#{id}/download"
      end
      
      # 删除备份文件
      def destroy_with_file
        if file_exists?
          File.delete(backup_path)
        end
        destroy
      end
      
      # 验证 checksum
      def verify_checksum
        return true unless checksum && file_exists?
        
        case checksum.length
        when 32
          # MD5
          actual = Digest::MD5.file(backup_path).hexdigest
        when 64
          # SHA256
          actual = Digest::SHA256.file(backup_path).hexdigest
        else
          return true
        end
        
        actual == checksum
      end
      
      class << self
        # 创建备份
        def create_backup(config, options = {})
          backup = new(
            database_config: config,
            backup_name: options[:name] || "backup_#{Time.current.strftime('%Y%m%d_%H%M%S')}",
            backup_type: options[:type] || "full",
            compression: options[:compression] || "gzip",
            is_auto_backup: options[:auto] || false,
            expires_at: options[:retain_days] ? options[:retain_days].days.from_now : nil,
            status: "pending"
          )
          
          backup.save!
          
          # 异步执行备份
          BackupJob.perform_later(backup.id)
          
          backup
        end
        
        # 清理过期备份
        def cleanup_expired
          expired.each do |backup|
            backup.destroy_with_file
          end
          count
        end
        
        # 获取最近的备份
        def recent_backups(config_id = nil, limit = 10)
          scope = completed.order(created_at: :desc)
          scope = scope.where(database_config_id: config_id) if config_id
          scope.limit(limit)
        end
        
        # 确保备份目录存在
        def ensure_backup_dir
          FileUtils.mkdir_p(BACKUP_DIR) unless Dir.exist?(BACKUP_DIR)
        end
      end
    end
  end
end
