# frozen_string_literal: true

require "openproject/msproject_import/version"

module OpenProject
  module MsprojectImport
    class Engine < ::Rails::Engine
      isolate_namespace OpenProject::MsprojectImport
      
      # 注册插件路由
      initializer "msproject_import.routes" do
        Rails.application.routes.append do
          mount OpenProject::MsprojectImport::Engine => "/msproject_import"
        end
      end
      
      # 注册权限
      initializer "msproject_import.permissions" do
        Permission.add_manager_module :msproject_import,
          read: [:view_msproject_import],
          write: [:import_msproject]
      end
    end
  end
end
