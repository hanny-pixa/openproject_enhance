# frozen_string_literal: true

module OpenProject
  module DatabaseManager
    class ApiController < ApplicationController
      before_action :authenticate_user!
      before_action :check_admin_permission
      
      # 列出所有数据库配置
      def index
        @configs = DatabaseConfig.all
        render json: @configs.map(&:as_json)
      end
      
      # 显示单个配置
      def show
        @config = DatabaseConfig.find(params[:id])
        render json: @config.as_json
      end
      
      # 创建新配置
      def create
        @config = DatabaseConfig.new(config_params)
        
        if @config.save
          render json: { success: true, config: @config.as_json }, status: :created
        else
          render json: { success: false, errors: @config.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # 更新配置
      def update
        @config = DatabaseConfig.find(params[:id])
        
        if @config.update(config_params)
          render json: { success: true, config: @config.as_json }
        else
          render json: { success: false, errors: @config.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # 删除配置
      def destroy
        @config = DatabaseConfig.find(params[:id])
        
        if @config.is_active
          render json: { success: false, message: "Cannot delete active database" }, status: :unprocessable_entity
          return
        end
        
        @config.destroy
        render json: { success: true }
      end
      
      # 测试连接
      def test_connection
        @config = DatabaseConfig.find(params[:id])
        
        begin
          result = @config.test_connection
          render json: { 
            success: true, 
            connected: result,
            message: result ? "Connection successful" : "Connection failed"
          }
        rescue StandardError => e
          render json: { 
            success: false, 
            connected: false,
            error: e.message 
          }, status: :unprocessable_entity
        end
      end
      
      # 切换数据库
      def switch
        @config = DatabaseConfig.find(params[:id])
        
        begin
          DatabaseConfig.switch_to(params[:id])
          render json: { 
            success: true, 
            message: "Switched to #{@config.name}",
            config: @config.as_json
          }
        rescue StandardError => e
          render json: { 
            success: false, 
            message: "Switch failed: #{e.message}" 
          }, status: :unprocessable_entity
        end
      end
      
      # 获取当前数据库信息
      def current
        @config = DatabaseConfig.current_config
        render json: {
          success: true,
          config: @config&.as_json || { name: "Default", adapter: "unknown" },
          size: @config&.human_size || "N/A"
        }
      end
      
      # 获取支持的适配器列表
      def adapters
        render json: {
          success: true,
          adapters: DatabaseConfig.available_adapters
        }
      end
      
      # 备份相关接口
      # 创建备份
      def create_backup
        @config = DatabaseConfig.find(params[:id])
        name = params[:name]
        compression = params[:compression] || "gzip"
        retain_days = params[:retain_days]&.to_i
        
        begin
          service = BackupService.new(@config)
          backup = service.perform_backup(
            name: name,
            compression: compression,
            retain_days: retain_days,
            auto: false
          )
          
          render json: {
            success: true,
            message: "备份已创建，正在后台执行",
            backup: backup.as_json
          }
        rescue StandardError => e
          render json: {
            success: false,
            message: "创建备份失败：#{e.message}"
          }, status: :unprocessable_entity
        end
      end
      
      # 列出备份
      def list_backups
        @config = DatabaseConfig.find(params[:id])
        backups = DatabaseBackup.where(database_config_id: @config.id)
                               .order(created_at: :desc)
                               .limit(50)
        
        render json: {
          success: true,
          backups: backups.map { |b| b.as_json.merge(human_size: b.human_size) }
        }
      end
      
      # 获取备份详情
      def show_backup
        @backup = DatabaseBackup.find(params[:backup_id])
        
        render json: {
          success: true,
          backup: @backup.as_json.merge(
            human_size: @backup.human_size,
            file_exists: @backup.file_exists?,
            checksum_valid: @backup.verify_checksum
          )
        }
      end
      
      # 下载备份
      def download_backup
        @backup = DatabaseBackup.find(params[:backup_id])
        
        unless @backup.file_exists?
          render json: { success: false, message: "备份文件不存在" }, status: :not_found
          return
        end
        
        send_file(
          @backup.backup_path,
          filename: File.basename(@backup.backup_path),
          type: "application/octet-stream",
          disposition: "attachment"
        )
      end
      
      # 删除备份
      def delete_backup
        @backup = DatabaseBackup.find(params[:backup_id])
        
        begin
          @backup.destroy_with_file
          render json: { success: true, message: "备份已删除" }
        rescue StandardError => e
          render json: {
            success: false,
            message: "删除失败：#{e.message}"
          }, status: :unprocessable_entity
        end
      end
      
      # 恢复备份
      def restore_backup
        @backup = DatabaseBackup.find(params[:backup_id])
        @config = @backup.database_config
        
        unless @backup.file_exists?
          render json: { success: false, message: "备份文件不存在" }, status: :not_found
          return
        end
        
        unless @backup.status == "completed"
          render json: { success: false, message: "备份状态异常，无法恢复" }, status: :unprocessable_entity
          return
        end
        
        begin
          service = BackupService.new(@config)
          restore = service.restore_backup(@backup.id)
          
          render json: {
            success: true,
            message: "恢复已启动，正在后台执行",
            restore: restore.as_json
          }
        rescue StandardError => e
          render json: {
            success: false,
            message: "创建恢复任务失败：#{e.message}"
          }, status: :unprocessable_entity
        end
      end
      
      # 列出恢复记录
      def list_restores
        @config = DatabaseConfig.find(params[:id])
        restores = DatabaseRestore.where(database_config_id: @config.id)
                                 .order(created_at: :desc)
                                 .limit(20)
        
        render json: {
          success: true,
          restores: restores.map { |r| r.as_json.merge(human_duration: r.human_duration) }
        }
      end
      
      # 获取备份统计
      def backup_stats
        @config = DatabaseConfig.find(params[:id])
        
        service = BackupService.new(@config)
        stats = service.backup_stats
        
        render json: {
          success: true,
          stats: stats.merge(
            total_size: number_to_human_size(stats[:total_size])
          )
        }
      end
      
      private
      
      def config_params
        params.require(:database_config).permit(
          :name, :adapter, :database, :host, :port, 
          :username, :password, :pool, :timeout, :encoding,
          connection_options: {}
        )
      end
      
      def check_admin_permission
        unless User.current.admin?
          render json: { success: false, message: "Admin permission required" }, status: :forbidden
        end
      end
    end
  end
end
