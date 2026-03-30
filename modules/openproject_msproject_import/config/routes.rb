# frozen_string_literal: true

module OpenProject
  module MsprojectImport
    class Engine < ::Rails::Engine
      isolate_namespace OpenProject::MsprojectImport
      
      # 注册路由
      initializer "msproject_import.routes" do
        Rails.application.routes.append do
          namespace :msproject_import do
            # API 路由
            namespace :api do
              # 导入
              post 'import/xml', to: 'api#import_xml'
              post 'import/excel', to: 'api#import_excel'
              
              # 导出
              get 'export', to: 'api#export'
              get 'export/download/:filename', to: 'api#download_export'
              
              # 其他
              get 'formats', to: 'api#supported_formats'
              get 'template', to: 'api#import_template'
            end
            
            # UI 路由
            get "(/page)", to: "dashboard#index"
          end
        end
      end
      
      # 注册权限
      initializer "msproject_import.permissions" do
        Permission.add_manager_module :msproject_import,
          read: [:view_msproject_import],
          write: [:import_msproject, :export_msproject]
      end
    end
  end
end
