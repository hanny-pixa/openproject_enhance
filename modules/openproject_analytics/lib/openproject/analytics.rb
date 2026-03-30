# frozen_string_literal: true

module OpenProject
  module Analytics
    # 统计分析模块
    class Engine < ::Rails::Engine
      isolate_namespace OpenProject::Analytics
      
      # 注册路由
      initializer "analytics.routes" do
        Rails.application.routes.append do
          mount OpenProject::Analytics::Engine => "/analytics"
        end
      end
      
      # 注册权限
      initializer "analytics.permissions" do
        Permission.add_manager_module :analytics,
          read: [:view_analytics, :view_reports],
          write: [:export_reports]
      end
    end
  end
end
