# frozen_string_literal: true

module OpenProject
  module DatabaseManager
    # 数据库备份服务
    class BackupService
      attr_reader :config, :backup
      
      def initialize(config)
        @config = config
      end
      
      # 执行备份
      def perform_backup(options = {})
        @backup = DatabaseBackup.create_backup(@config, options)
        @backup
      end
      
      # 恢复备份
      def restore_backup(backup_id)
        backup = DatabaseBackup.find(backup_id)
        
        raise "备份文件不存在" unless backup.file_exists?
        raise "备份状态异常" unless backup.status == "completed"
        
        # 创建恢复记录
        restore = DatabaseRestore.create!(
          database_config: @config,
          backup: backup,
          status: "pending"
        )
        
        # 异步执行恢复
        RestoreJob.perform_later(restore.id)
        
        restore
      end
      
      # 直接备份到文件
      def backup_to_file
        DatabaseBackup.ensure_backup_dir
        
        timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
        filename = "#{@config.name}_#{timestamp}"
        
        case @config.adapter
        when "sqlite3"
          backup_sqlite(filename)
        when "postgresql"
          backup_postgresql(filename)
        when "mysql2"
          backup_mysql(filename)
        else
          raise "不支持的数据库类型：#{@config.adapter}"
        end
      end
      
      # 从文件恢复
      def restore_from_file(file_path)
        raise "备份文件不存在" unless File.exist?(file_path)
        
        case @config.adapter
        when "sqlite3"
          restore_sqlite(file_path)
        when "postgresql"
          restore_postgresql(file_path)
        when "mysql2"
          restore_mysql(file_path)
        else
          raise "不支持的数据库类型：#{@config.adapter}"
        end
      end
      
      # 列出所有备份
      def list_backups
        DatabaseBackup.where(database_config_id: @config.id)
                     .order(created_at: :desc)
      end
      
      # 获取备份统计
      def backup_stats
        backups = DatabaseBackup.where(database_config_id: @config.id)
        {
          total: backups.count,
          completed: backups.where(status: "completed").count,
          failed: backups.where(status: "failed").count,
          total_size: backups.sum { |b| b.file_size },
          last_backup: backups.order(created_at: :desc).first,
          oldest_backup: backups.order(created_at: :asc).first
        }
      end
      
      private
      
      # SQLite 备份
      def backup_sqlite(filename)
        db_path = @config.database
        
        unless File.exist?(db_path)
          raise "SQLite 数据库文件不存在：#{db_path}"
        end
        
        # 复制文件
        backup_path = File.join(DatabaseBackup::BACKUP_DIR, "#{filename}.sqlite3")
        FileUtils.cp(db_path, backup_path)
        
        # 压缩
        if @backup&.compression == "gzip"
          compressed_path = "#{backup_path}.gz"
          system("gzip -c #{backup_path} > #{compressed_path}")
          File.delete(backup_path)
          backup_path = compressed_path
        end
        
        # 更新备份记录
        @backup&.update!(
          backup_path: backup_path,
          backup_size: File.size(backup_path),
          status: "completed",
          completed_at: Time.current,
          checksum: Digest::MD5.file(backup_path).hexdigest
        )
        
        backup_path
      end
      
      # PostgreSQL 备份
      def backup_postgresql(filename)
        backup_path = File.join(DatabaseBackup::BACKUP_DIR, filename)
        
        # 使用 pg_dump
        cmd = [
          "pg_dump",
          "-h", @config.host || "localhost",
          "-p", @config.port || 5432,
          "-U", @config.username,
          "-d", @config.database,
          "-F", "c", # 自定义格式
          "-f", "#{backup_path}.dump"
        ]
        
        # 设置密码环境变量
        env = { "PGPASSWORD" => @config.password }
        
        success = system(env, *cmd)
        raise "pg_dump 失败" unless success
        
        backup_path = "#{backup_path}.dump"
        
        # 更新备份记录
        @backup&.update!(
          backup_path: backup_path,
          backup_size: File.size(backup_path),
          status: "completed",
          completed_at: Time.current,
          checksum: Digest::MD5.file(backup_path).hexdigest
        )
        
        backup_path
      end
      
      # MySQL 备份
      def backup_mysql(filename)
        backup_path = File.join(DatabaseBackup::BACKUP_DIR, filename)
        
        # 使用 mysqldump
        cmd = [
          "mysqldump",
          "-h", @config.host || "localhost",
          "-P", @config.port || 3306,
          "-u", @config.username,
          "-p#{@config.password}",
          "--single-transaction",
          "--routines",
          "--triggers",
          @config.database,
          ">", "#{backup_path}.sql"
        ]
        
        success = system(cmd.join(" "))
        raise "mysqldump 失败" unless success
        
        backup_path = "#{backup_path}.sql"
        
        # 压缩
        if @backup&.compression == "gzip"
          compressed_path = "#{backup_path}.gz"
          system("gzip #{backup_path}")
          backup_path = compressed_path
        end
        
        # 更新备份记录
        @backup&.update!(
          backup_path: backup_path,
          backup_size: File.size(backup_path),
          status: "completed",
          completed_at: Time.current,
          checksum: Digest::MD5.file(backup_path).hexdigest
        )
        
        backup_path
      end
      
      # SQLite 恢复
      def restore_sqlite(file_path)
        db_path = @config.database
        
        # 备份当前数据库
        if File.exist?(db_path)
          backup_current = "#{db_path}.backup.before_restore"
          FileUtils.cp(db_path, backup_current)
        end
        
        # 解压 (如果是 gzip)
        if file_path.end_with?(".gz")
          temp_path = File.join(DatabaseBackup::BACKUP_DIR, "temp_restore.sqlite3")
          system("gunzip -c #{file_path} > #{temp_path}")
          file_path = temp_path
        end
        
        # 恢复文件
        FileUtils.cp(file_path, db_path)
        
        # 清理临时文件
        File.delete(file_path) if file_path.include?("temp_restore")
        
        true
      end
      
      # PostgreSQL 恢复
      def restore_postgresql(file_path)
        # 使用 pg_restore
        cmd = [
          "pg_restore",
          "-h", @config.host || "localhost",
          "-p", @config.port || 5432,
          "-U", @config.username,
          "-d", @config.database,
          "--clean",
          "--if-exists",
          file_path
        ]
        
        env = { "PGPASSWORD" => @config.password }
        
        success = system(env, *cmd)
        raise "pg_restore 失败" unless success
        
        true
      end
      
      # MySQL 恢复
      def restore_mysql(file_path)
        # 解压 (如果是 gzip)
        if file_path.end_with?(".gz")
          temp_path = file_path.sub(".gz", "")
          system("gunzip -c #{file_path} > #{temp_path}")
          file_path = temp_path
        end
        
        cmd = [
          "mysql",
          "-h", @config.host || "localhost",
          "-P", @config.port || 3306,
          "-u", @config.username,
          "-p#{@config.password}",
          @config.database,
          "<", file_path
        ]
        
        success = system(cmd.join(" "))
        raise "mysql 恢复失败" unless success
        
        true
      end
    end
  end
end
