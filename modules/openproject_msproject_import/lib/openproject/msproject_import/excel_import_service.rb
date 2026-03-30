# frozen_string_literal: true

module OpenProject
  module MsprojectImport
    # Excel/CSV导入服务
    class ExcelImportService
      attr_reader :file_path, :data
      
      def initialize(file_path)
        @file_path = file_path
        @data = {
          project: {},
          tasks: [],
          resources: [],
          assignments: []
        }
      end
      
      # 导入文件
      def import
        extension = File.extname(file_path).downcase
        
        case extension
        when '.csv'
          import_csv
        when '.xlsx', '.xls'
          import_excel
        else
          raise "不支持的文件格式：#{extension}"
        end
        
        @data
      end
      
      private
      
      # 导入 CSV
      def import_csv
        require 'csv'
        
        CSV.foreach(file_path, headers: true, encoding: 'UTF-8') do |row|
          parse_task_row(row.to_h)
        end
      end
      
      # 导入 Excel
      def import_excel
        require 'roo'
        
        spreadsheet = open_spreadsheet(file_path)
        
        # 读取 Tasks 工作表
        if spreadsheet.sheet('Tasks') || spreadsheet.sheet('任务')
          sheet_name = spreadsheet.sheet('Tasks') ? 'Tasks' : '任务'
          spreadsheet.default_sheet = sheet_name
          
          header = nil
          spreadsheet.each do |row|
            if header.nil?
              header = row.map(&:to_s)
              next
            end
            
            row_hash = Hash[[header, row].transpose]
            parse_task_row(row_hash)
          end
        end
        
        # 读取 Resources 工作表
        if spreadsheet.sheet('Resources') || spreadsheet.sheet('资源')
          sheet_name = spreadsheet.sheet('Resources') ? 'Resources' : '资源'
          spreadsheet.default_sheet = sheet_name
          
          header = nil
          spreadsheet.each do |row|
            if header.nil?
              header = row.map(&:to_s)
              next
            end
            
            row_hash = Hash[[header, row].transpose]
            parse_resource_row(row_hash)
          end
        end
      end
      
      # 解析任务行
      def parse_task_row(row)
        task = {
          uid: row['UID'] || row['uid'] || generate_uid,
          id: row['ID'] || row['id'],
          name: row['Name'] || row['name'] || row['任务名称'] || 'Unnamed Task',
          wbs: row['WBS'] || row['wbs'],
          outline_level: (row['OutlineLevel'] || row['outline_level'] || 1).to_i,
          start: parse_date(row['Start'] || row['start'] || row['开始时间']),
          finish: parse_date(row['Finish'] || row['finish'] || row['完成时间']),
          duration: parse_duration(row['Duration'] || row['duration'] || row['工期']),
          percent_complete: (row['PercentComplete'] || row['percent_complete'] || row['完成率'] || 0).to_f,
          is_milestone: (row['Milestone'] || row['milestone'] || row['里程碑'] || 0).to_i,
          is_summary: (row['Summary'] || row['summary'] || row['摘要'] || 0).to_i,
          priority: (row['Priority'] || row['priority'] || row['优先级'] || 500).to_i,
          notes: row['Notes'] || row['notes'] || row['备注'],
          predecessor_uids: parse_predecessors(row['Predecessors'] || row['predecessors'] || row['前置任务']),
          resource_names: parse_resources(row['ResourceNames'] || row['resource_names'] || row['资源名称'])
        }
        
        @data[:tasks] << task
      end
      
      # 解析资源行
      def parse_resource_row(row)
        resource = {
          uid: row['UID'] || row['uid'] || generate_uid,
          name: row['Name'] || row['name'] || row['资源名称'] || 'Unnamed Resource',
          type: (row['Type'] || row['type'] || row['资源类型'] || 1).to_i,
          email: row['EmailAddress'] || row['email_address'] || row['邮箱'],
          max_units: (row['MaxUnits'] || row['max_units'] || row['最大单位'] || 1).to_f,
          standard_rate: (row['StandardRate'] || row['standard_rate'] || row['标准费率'] || 0).to_f
        }
        
        @data[:resources] << resource
      end
      
      # 解析前置任务
      def parse_predecessors(predecessor_str)
        return [] if predecessor_str.blank?
        
        predecessor_str.to_s.split(';').map do |pred|
          pred.strip.split(':').first # 支持 "123FS" 或 "123" 格式
        end.compact
      end
      
      # 解析资源名称
      def parse_resources(resource_str)
        return [] if resource_str.blank?
        
        resource_str.to_s.split(';').map(&:strip).compact
      end
      
      # 解析日期
      def parse_date(date_str)
        return nil if date_str.blank?
        
        case date_str
        when Time
          date_str
        when Date
          date_str.to_time
        when String
          # 尝试多种日期格式
          formats = [
            '%Y-%m-%d %H:%M:%S',
            '%Y-%m-%d',
            '%Y/%m/%d %H:%M:%S',
            '%Y/%m/%d',
            '%d-%m-%Y %H:%M:%S',
            '%d-%m-%Y',
            '%m/%d/%Y %H:%M:%S',
            '%m/%d/%Y'
          ]
          
          formats.each do |format|
            begin
              return Time.strptime(date_str, format)
            rescue ArgumentError
              next
            end
          end
          
          # 最后尝试 DateTime.parse
          DateTime.parse(date_str).to_time
        else
          nil
        end
      rescue StandardError
        nil
      end
      
      # 解析工期
      def parse_duration(duration_str)
        return 0 if duration_str.blank?
        
        duration_str = duration_str.to_s.strip
        
        # 处理 "3 days", "2 weeks" 等格式
        if duration_str.match(/(\d+)\s*(day|days|d)/i)
          return $1.to_i * 8 # 假设每天 8 小时
        elsif duration_str.match(/(\d+)\s*(week|weeks|w)/i)
          return $1.to_i * 40 # 假设每周 40 小时
        elsif duration_str.match(/(\d+)\s*(hour|hours|h)/i)
          return $1.to_f
        elsif duration_str.match(/(\d+)\s*(minute|minutes|m)/i)
          return $1.to_f / 60
        end
        
        # 处理数字格式 (小时)
        duration_str.to_f
      end
      
      # 生成 UID
      def generate_uid
        @last_uid ||= 0
        @last_uid += 1
        @last_uid
      end
      
      # 打开电子表格
      def open_spreadsheet(file_path)
        case File.extname(file_path).downcase
        when '.csv'
          Roo::CSV.new(file_path)
        when '.xls'
          Roo::Excel.new(file_path)
        when '.xlsx'
          Roo::Excelx.new(file_path)
        else
          raise "Unknown file type: #{File.extname(file_path)}"
        end
      end
    end
  end
end
