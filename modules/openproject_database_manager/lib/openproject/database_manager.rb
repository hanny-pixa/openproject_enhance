# frozen_string_literal: true

module OpenProject
  module DatabaseManager
    # 数据库配置管理模块
    class Engine < ::Rails::Engine
      isolate_namespace OpenProject::DatabaseManager
      
      # 注册路由
      initializer "database_manager.routes" do
        Rails.application.routes.append do
          mount OpenProject::DatabaseManager::Engine => "/database_manager"
        end
      end
      
      # 注册权限
      initializer "database_manager.permissions" do
        Permission.add_manager_module :database_manager,
          read: [:view_database_settings],
          write: [:manage_database_settings]
      end
    end
  end
end
