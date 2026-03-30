# frozen_string_literal: true

module OpenProject
  module MsprojectImport
    # 导出服务 - 支持 MS Project XML/Excel/CSV 格式
    class ExportService
      attr_reader :project, :options
      
      def initialize(project_id, options = {})
        @project = Project.find(project_id)
        @options = options
        @work_packages = load_work_packages
      end
      
      # 导出到文件
      def export_to_file(format, output_path)
        case format.to_s.downcase
        when 'xml', 'msp'
          export_to_xml(output_path)
        when 'xlsx', 'excel'
          export_to_excel(output_path)
        when 'csv'
          export_to_csv(output_path)
        when 'json'
          export_to_json(output_path)
        else
          raise "不支持的导出格式：#{format}"
        end
        
        output_path
      end
      
      # 导出为 MS Project XML
      def export_to_xml(output_path)
        require 'nokogiri'
        
        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml.Project('xmlns': 'http://schemas.microsoft.com/project') do
            # 项目信息
            xml.SaveVersion '14'
            xml.Title @project.name
            xml.StartDate @project.start_date&.iso8601
            xml.FinishDate @project.due_date&.iso8601
            xml.CurrentDate Time.now.iso8601
            xml.MinutesPerDay 480
            xml.MinutesPerWeek 2400
            xml.DaysPerMonth 20
            xml.CurrencySymbol '$'
            xml.CurrencySymbolPosition 0
            
            # 日历
            xml.Calendars do
              xml.Calendar do
                xml.UID 1
                xml.Name 'Standard'
                xml.IsBaseCalendar 1
                xml.WeekDays do
                  # 周一到周五
                  (2..6).each do |day_type|
                    xml.WeekDay do
                      xml.DayType day_type
                      xml.DayWorking 1
                      xml.WorkingTimes do
                        xml.WorkingTime do
                          xml.FromTime '08:00:00'
                          xml.ToTime '12:00:00'
                        end
                        xml.WorkingTime do
                          xml.FromTime '13:00:00'
                          xml.ToTime '17:00:00'
                        end
                      end
                    end
                  end
                  # 周末
                  [1, 7].each do |day_type|
                    xml.WeekDay do
                      xml.DayType day_type
                      xml.DayWorking 0
                    end
                  end
                end
              end
            end
            
            # 任务
            xml.Tasks do
              # 项目摘要任务
              xml.Task do
                xml.UID 0
                xml.ID 0
                xml.Name @project.name
                xml.Type 0
                xml.IsNull 0
                xml.WBS '0'
                xml.OutlineNumber '0'
                xml.OutlineLevel 0
                xml.Start @project.start_date&.iso8601 || Time.now.iso8601
                xml.Finish @project.due_date&.iso8601 || Time.now.iso8601
                xml.Duration "PT#{@work_packages.sum(:estimated_hours) || 0}H0M0S"
                xml.Milestone 0
                xml.Summary 1
                xml.Critical 0
                xml.Active 1
              end
              
              # 工作包任务
              @work_packages.each_with_index do |wp, index|
                xml.Task do
                  xml.UID wp.id
                  xml.ID index + 1
                  xml.Name wp.subject
                  xml.Type 0
                  xml.IsNull 0
                  xml.WBS wp.id.to_s
                  xml.OutlineNumber (index + 1).to_s
                  xml.OutlineLevel 1
                  xml.Start wp.start_date&.iso8601 || Time.now.iso8601
                  xml.Finish wp.due_date&.iso8601 || Time.now.iso8601
                  xml.Duration "PT#{wp.estimated_hours || 8}H0M0S"
                  xml.PercentComplete wp.percent_complete || 0
                  xml.Milestone (wp.type&.name == 'Milestone' ? 1 : 0)
                  xml.Summary 0
                  xml.Critical 0
                  xml.Active 1
                  xml.Manual 0
                  xml.Notes wp.description if wp.description
                  
                  # 前置任务关系
                  if wp.relations&.any?
                    wp.relations.each do |relation|
                      xml.PredecessorLink do
                        xml.PredecessorUID relation.predecessor_id
                        xml.Type 1 # FS
                        xml.CrossProject 0
                      end
                    end
                  end
                end
              end
            end
            
            # 资源
            xml.Resources do
              @work_packages.map(&:assigned_to).compact.uniq.each_with_index do |user, index|
                xml.Resource do
                  xml.UID user.id
                  xml.ID index + 1
                  xml.Name user.name
                  xml.Type 1 # Work
                  xml.EmailAddress user.email if user.email
                  xml.MaxUnits 1
                  xml.CanLevel 0
                end
              end
            end
            
            # 分配
            xml.Assignments do
              @work_packages.each do |wp|
                next unless wp.assigned_to
                
                xml.Assignment do
                  xml.UID "#{wp.id}-#{wp.assigned_to_id}"
                  xml.TaskUID wp.id
                  xml.ResourceUID wp.assigned_to_id
                  xml.Units 1
                  xml.Work "PT#{wp.estimated_hours || 8}H0M0S"
                  xml.PercentWorkComplete wp.percent_complete || 0
                end
              end
            end
          end
        end
        
        File.write(output_path, builder.to_xml(indent: 2))
        output_path
      end
      
      # 导出到 Excel
      def export_to_excel(output_path)
        require 'spreadsheet'
        
        workbook = Spreadsheet::Workbook.new
        
        # Tasks 工作表
        tasks_sheet = workbook.create_worksheet(name: 'Tasks')
        tasks_sheet.row(0).concat([
          'UID', 'ID', 'Name', 'WBS', 'OutlineLevel',
          'Start', 'Finish', 'Duration', 'PercentComplete',
          'Milestone', 'Summary', 'Priority', 'Notes', 'Predecessors', 'ResourceNames'
        ])
        
        @work_packages.each_with_index do |wp, index|
          row = index + 1
          tasks_sheet.row(row).concat([
            wp.id,
            wp.id,
            wp.subject,
            wp.id.to_s,
            1,
            wp.start_date&.strftime('%Y-%m-%d %H:%M:%S') || '',
            wp.due_date&.strftime('%Y-%m-%d %H:%M:%S') || '',
            "#{wp.estimated_hours || 8}h",
            wp.percent_complete || 0,
            (wp.type&.name == 'Milestone' ? 1 : 0),
            0,
            wp.priority || 500,
            wp.description || '',
            wp.relations&.map { |r| r.predecessor_id }&.join(';') || '',
            wp.assigned_to&.name || ''
          ])
        end
        
        # Resources 工作表
        resources_sheet = workbook.create_worksheet(name: 'Resources')
        resources_sheet.row(0).concat([
          'UID', 'Name', 'Type', 'EmailAddress', 'MaxUnits', 'StandardRate'
        ])
        
        @work_packages.map(&:assigned_to).compact.uniq.each_with_index do |user, index|
          row = index + 1
          resources_sheet.row(row).concat([
            user.id,
            user.name,
            1, # Work
            user.email || '',
            1,
            0
          ])
        end
        
        workbook.write(output_path)
        output_path
      end
      
      # 导出到 CSV
      def export_to_csv(output_path)
        require 'csv'
        
        CSV.open(output_path, 'w', headers: true) do |csv|
          # 写入表头
          csv << [
            'UID', 'ID', 'Name', 'WBS', 'OutlineLevel',
            'Start', 'Finish', 'Duration', 'PercentComplete',
            'Milestone', 'Summary', 'Priority', 'Notes', 'Predecessors', 'ResourceNames'
          ]
          
          # 写入数据
          @work_packages.each do |wp|
            csv << [
              wp.id,
              wp.id,
              wp.subject,
              wp.id.to_s,
              1,
              wp.start_date&.strftime('%Y-%m-%d %H:%M:%S') || '',
              wp.due_date&.strftime('%Y-%m-%d %H:%M:%S') || '',
              "#{wp.estimated_hours || 8}h",
              wp.percent_complete || 0,
              (wp.type&.name == 'Milestone' ? 1 : 0),
              0,
              wp.priority || 500,
              wp.description || '',
              wp.relations&.map { |r| r.predecessor_id }&.join(';') || '',
              wp.assigned_to&.name || ''
            ]
          end
        end
        
        output_path
      end
      
      # 导出到 JSON
      def export_to_json(output_path)
        data = {
          project: {
            name: @project.name,
            start_date: @project.start_date,
            due_date: @project.due_date
          },
          tasks: @work_packages.map do |wp|
            {
              uid: wp.id,
              id: wp.id,
              name: wp.subject,
              wbs: wp.id.to_s,
              start: wp.start_date,
              finish: wp.due_date,
              duration: wp.estimated_hours || 8,
              percent_complete: wp.percent_complete || 0,
              is_milestone: (wp.type&.name == 'Milestone' ? 1 : 0),
              notes: wp.description,
              predecessors: wp.relations&.map { |r| r.predecessor_id } || [],
              resources: [wp.assigned_to&.name].compact
            }
          end,
          resources: @work_packages.map(&:assigned_to).compact.uniq.map do |user|
            {
              uid: user.id,
              name: user.name,
              email: user.email,
              type: 1
            }
          end
        }
        
        File.write(output_path, JSON.pretty_generate(data))
        output_path
      end
      
      # 获取所有导出格式
      def self.supported_formats
        {
          xml: { extension: '.xml', mime: 'application/xml', name: 'MS Project XML' },
          msp: { extension: '.msp', mime: 'application/xml', name: 'MS Project' },
          xlsx: { extension: '.xlsx', mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', name: 'Excel' },
          csv: { extension: '.csv', mime: 'text/csv', name: 'CSV' },
          json: { extension: '.json', mime: 'application/json', name: 'JSON' }
        }
      end
      
      private
      
      # 加载工作包
      def load_work_packages
        @project.work_packages
                .includes(:assigned_to, :type, :status, :relations)
                .order(:id)
      end
    end
  end
end
