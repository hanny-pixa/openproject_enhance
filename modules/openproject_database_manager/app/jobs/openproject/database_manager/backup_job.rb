# frozen_string_literal: true

module OpenProject
  module DatabaseManager
    # 备份任务
    class BackupJob < ApplicationJob
      queue_as :default
      
      def perform(backup_id)
        backup = DatabaseBackup.find(backup_id)
        config = backup.database_config
        
        backup.update!(
          status: "running",
          started_at: Time.current
        )
        
        begin
          service = BackupService.new(config)
          backup_path = service.backup_to_file
          
          backup.update!(
            status: "completed",
            completed_at: Time.current,
            backup_path: backup_path
          )
          
          Rails.logger.info "[BackupJob] Backup completed: #{backup_path}"
        rescue StandardError => e
          backup.update!(
            status: "failed",
            error_message: e.message,
            completed_at: Time.current
          )
          
          Rails.logger.error "[BackupJob] Backup failed: #{e.message}"
          raise
        end
      end
    end
  end
end
