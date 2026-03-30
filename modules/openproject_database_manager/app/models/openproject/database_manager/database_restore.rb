# frozen_string_literal: true

module OpenProject
  module DatabaseManager
    # 数据库恢复模型
    class DatabaseRestore < ActiveRecord::Base
      belongs_to :database_config
      belongs_to :backup, class_name: "DatabaseBackup"
      
      # 验证
      validates :status, inclusion: { in: %w(pending running completed failed) }
      
      # 作用域
      scope :completed, -> { where(status: "completed") }
      scope :failed, -> { where(status: "failed") }
      scope :recent, -> { order(created_at: :desc).limit(10) }
      
      # 实例方法
      def duration
        return nil unless started_at && completed_at
        completed_at - started_at
      end
      
      def human_duration
        d = duration
        return nil unless d
        
        if d < 60
          "#{d.round}秒"
        elsif d < 3600
          "#{(d / 60).round}分钟"
        else
          "#{(d / 3600).round(1)}小时"
        end
      end
      
      class << self
        # 创建恢复任务
        def create_restore(config, backup)
          create!(
            database_config: config,
            backup: backup,
            status: "pending"
          )
        end
      end
    end
  end
end
