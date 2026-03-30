# frozen_string_literal: true

module OpenProject
  module DatabaseManager
    class Engine < ::Rails::Engine
      isolate_namespace OpenProject::DatabaseManager
      
      # 注册路由
      initializer "database_manager.routes" do
        Rails.application.routes.append do
          namespace :database_manager do
            # API 路由
            namespace :api do
              # 数据库配置
              resources :configs do
                member do
                  post :test
                  post :switch
                end
                # 备份相关
                member do
                  post :create_backup
                  get :list_backups
                  get :backup_stats
                end
              end
              
              # 备份资源
              resources :backups, only: [:show, :destroy] do
                member do
                  get :download
                  post :restore
                end
              end
              
              # 恢复记录
              resources :restores, only: [:index]
              
              # 通用接口
              get :current, to: "api#current"
              get :adapters, to: "api#adapters"
            end
            
            # UI 路由
            get "(/page)", to: "dashboard#index"
          end
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
