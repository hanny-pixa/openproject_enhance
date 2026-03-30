# frozen_string_literal: true

module OpenProject
  module DatabaseManager
    # 恢复任务
    class RestoreJob < ApplicationJob
      queue_as :default
      
      def perform(restore_id)
        restore = DatabaseRestore.find(restore_id)
        config = restore.database_config
        backup = restore.backup
        
        restore.update!(
          status: "running",
          started_at: Time.current
        )
        
        begin
          service = BackupService.new(config)
          
          # 恢复数据库
          service.restore_from_file(backup.backup_path)
          
          restore.update!(
            status: "completed",
            completed_at: Time.current,
            rollback_available: true,
            rollback_backup_path: "#{config.database}.backup.before_restore"
          )
          
          Rails.logger.info "[RestoreJob] Restore completed from: #{backup.backup_path}"
        rescue StandardError => e
          restore.update!(
            status: "failed",
            error_message: e.message,
            completed_at: Time.current
          )
          
          Rails.logger.error "[RestoreJob] Restore failed: #{e.message}"
          raise
        end
      end
    end
  end
end
