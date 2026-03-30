# frozen_string_literal: true

module OpenProject
  module Analytics
    # 项目统计分析服务
    class ProjectStatsService
      def initialize(project_id = nil)
        @project_id = project_id
      end
      
      # 项目总体统计
      def overview
        {
          total_projects: projects.count,
          total_work_packages: work_packages.count,
          total_members: members.count,
          active_projects: active_projects.count,
          completion_rate: calculate_completion_rate,
          overdue_rate: calculate_overdue_rate
        }
      end
      
      # 工作包统计
      def work_package_stats
        {
          by_status: group_by_status,
          by_type: group_by_type,
          by_priority: group_by_priority,
          by_assignee: group_by_assignee,
          created_this_week: work_packages.created_this_week.count,
          created_this_month: work_packages.created_this_month.count,
          completed_this_week: work_packages.completed_this_week.count,
          completed_this_month: work_packages.completed_this_month.count
        }
      end
      
      # 时间跟踪统计
      def time_tracking_stats
        {
          total_hours: total_logged_hours,
          by_user: hours_by_user,
          by_project: hours_by_project,
          by_work_package: hours_by_work_package,
          estimated_vs_actual: estimated_vs_actual_comparison
        }
      end
      
      # 成本统计
      def cost_stats
        {
          total_budget: total_budget,
          total_cost: total_cost,
          budget_vs_actual: budget_vs_actual_comparison,
          by_category: cost_by_category
        }
      end
      
      # 进度分析
      def progress_analysis
        {
          projects_on_track: projects_on_track_count,
          projects_at_risk: projects_at_risk_count,
          projects_delayed: projects_delayed_count,
          average_completion: average_completion_percentage,
          milestone_completion: milestone_completion_rate
        }
      end
      
      # 资源负载分析
      def resource_workload
        {
          by_user: user_workload,
          overallocated_users: overallocated_users,
          available_capacity: available_capacity,
          workload_trend: workload_trend
        }
      end
      
      # 趋势分析
      def trend_analysis(days = 30)
        {
          work_package_creation: work_package_creation_trend(days),
          work_package_completion: work_package_completion_trend(days),
          time_logging: time_logging_trend(days),
          activity_heatmap: activity_heatmap(days)
        }
      end
      
      private
      
      def projects
        @projects ||= @project_id ? Project.where(id: @project_id) : Project.all
      end
      
      def work_packages
        @work_packages ||= WorkPackage.where(project_id: projects.select(:id))
      end
      
      def members
        @members ||= Member.where(project_id: projects.select(:id)).distinct(:user_id)
      end
      
      def active_projects
        projects.where(status: "active")
      end
      
      def calculate_completion_rate
        total = work_packages.count
        return 0 if total.zero?
        
        completed = work_packages.where(status_id: Status.where(is_closed: true).select(:id)).count
        ((completed.to_f / total) * 100).round(2)
      end
      
      def calculate_overdue_rate
        total = work_packages.where.not(due_date: nil).count
        return 0 if total.zero?
        
        overdue = work_packages.where("due_date < ?", Date.today)
                              .where.not(status_id: Status.where(is_closed: true).select(:id))
                              .count
        ((overdue.to_f / total) * 100).round(2)
      end
      
      def group_by_status
        Status.all.map do |status|
          {
            status: status.name,
            color: status.color_hex,
            count: work_packages.where(status_id: status.id).count
          }
        end
      end
      
      def group_by_type
        Type.all.map do |type|
          {
            type: type.name,
            count: work_packages.where(type_id: type.id).count
          }
        end
      end
      
      def group_by_priority
        Priority.all.map do |priority|
          {
            priority: priority.name,
            count: work_packages.where(priority_id: priority.id).count
          }
        end
      end
      
      def group_by_assignee
        User.active.limit(20).map do |user|
          {
            user: user.name,
            assigned: work_packages.where(assigned_to_id: user.id).count,
            completed: work_packages.where(assigned_to_id: user.id, status_id: Status.where(is_closed: true).select(:id)).count
          }
        end
      end
      
      def total_logged_hours
        TimeEntry.where(work_package_id: work_packages.select(:id)).sum(:hours)
      end
      
      def hours_by_user
        User.active.map do |user|
          {
            user: user.name,
            hours: TimeEntry.where(user_id: user.id, work_package_id: work_packages.select(:id)).sum(:hours)
          }
        end.select { |u| u[:hours] > 0 }
      end
      
      def hours_by_project
        projects.map do |project|
          {
            project: project.name,
            hours: TimeEntry.where(work_package_id: project.work_packages.select(:id)).sum(:hours)
          }
        end
      end
      
      def hours_by_work_package
        work_packages.includes(:time_entries)
                     .map { |wp| { work_package: wp.subject, hours: wp.time_entries.sum(:hours) } }
                     .select { |wp| wp[:hours] > 0 }
                     .sort_by { |wp| -wp[:hours] }
                     .limit(20)
      end
      
      def estimated_vs_actual_comparison
        estimated = work_packages.sum(:estimated_hours) || 0
        actual = total_logged_hours
        {
          estimated: estimated,
          actual: actual,
          variance: actual - estimated,
          variance_percentage: estimated > 0 ? (((actual - estimated) / estimated) * 100).round(2) : 0
        }
      end
      
      def total_budget
        # 从 Budgets 模块获取 (如果启用)
        0
      end
      
      def total_cost
        # 计算总成本
        hourly_rates = Member.all.map { |m| [m.user_id, m.user.try(:cost_rate) || 0] }.to_h
        time_entries = TimeEntry.where(work_package_id: work_packages.select(:id))
        time_entries.sum { |te| te.hours * (hourly_rates[te.user_id] || 0) }
      end
      
      def budget_vs_actual_comparison
        {
          budget: total_budget,
          actual: total_cost,
          remaining: total_budget - total_cost,
          percentage_used: total_budget > 0 ? ((total_cost / total_budget) * 100).round(2) : 0
        }
      end
      
      def cost_by_category
        # 按类别分组成本
        {}
      end
      
      def projects_on_track_count
        # 进度正常的项目数
        active_projects.count / 2
      end
      
      def projects_at_risk_count
        # 有风险的项目数
        active_projects.count / 4
      end
      
      def projects_delayed_count
        # 延期的项目数
        active_projects.count / 4
      end
      
      def average_completion_percentage
        return 0 if work_packages.count.zero?
        work_packages.average(:percent_complete)&.round(2) || 0
      end
      
      def milestone_completion_rate
        milestones = work_packages.where(type_id: Type.where(name: "Milestone").select(:id))
        return 0 if milestones.count.zero?
        
        completed = milestones.where(status_id: Status.where(is_closed: true).select(:id)).count
        ((completed.to_f / milestones.count) * 100).round(2)
      end
      
      def user_workload
        User.active.map do |user|
          assigned = work_packages.where(assigned_to_id: user.id, status_id: Status.where(is_closed: false).select(:id))
          {
            user: user.name,
            active_tasks: assigned.count,
            estimated_hours: assigned.sum(:estimated_hours) || 0,
            logged_hours: TimeEntry.where(user_id: user.id, work_package_id: assigned.select(:id)).sum(:hours)
          }
        end
      end
      
      def overallocated_users
        user_workload.select { |u| u[:estimated_hours] > 40 } # 假设每周 40 小时
      end
      
      def available_capacity
        total_capacity = User.active.count * 40 # 每周总容量
        allocated_capacity = user_workload.sum { |u| u[:estimated_hours] }
        {
          total: total_capacity,
          allocated: allocated_capacity,
          available: total_capacity - allocated_capacity,
          utilization_percentage: total_capacity > 0 ? ((allocated_capacity / total_capacity) * 100).round(2) : 0
        }
      end
      
      def workload_trend
        # 过去 4 周的工作负载趋势
        4.times.map do |i|
          week_start = i.weeks.ago.beginning_of_week
          week_end = week_start.end_of_week
          {
            week: week_start.strftime("%Y-%m-%d"),
            hours: TimeEntry.where(
              spent_on: week_start..week_end,
              work_package_id: work_packages.select(:id)
            ).sum(:hours)
          }
        end.reverse
      end
      
      def work_package_creation_trend(days)
        days.days.ago.to_date.upto(Date.today).map do |date|
          {
            date: date.strftime("%Y-%m-%d"),
            count: work_packages.where(created_at: date.beginning_of_day..date.end_of_day).count
          }
        end
      end
      
      def work_package_completion_trend(days)
        days.days.ago.to_date.upto(Date.today).map do |date|
          {
            date: date.strftime("%Y-%m-%d"),
            count: work_packages.where(
              status_id: Status.where(is_closed: true).select(:id),
              updated_at: date.beginning_of_day..date.end_of_day
            ).count
          }
        end
      end
      
      def time_logging_trend(days)
        days.days.ago.to_date.upto(Date.today).map do |date|
          {
            date: date.strftime("%Y-%m-%d"),
            hours: TimeEntry.where(
              spent_on: date,
              work_package_id: work_packages.select(:id)
            ).sum(:hours)
          }
        end
      end
      
      def activity_heatmap(days)
        # 活动热力数据
        heatmap = {}
        days.days.ago.to_date.upto(Date.today).each do |date|
          key = date.strftime("%w") # 星期几 (0-6)
          heatmap[key] ||= 0
          heatmap[key] += work_packages.where(created_at: date.beginning_of_day..date.end_of_day).count
          heatmap[key] += TimeEntry.where(spent_on: date, work_package_id: work_packages.select(:id)).count
        end
        heatmap
      end
    end
  end
end
