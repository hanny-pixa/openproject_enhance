# frozen_string_literal: true

module OpenProject
  module MsprojectImport
    class ApiController < ApplicationController
      before_action :authenticate_user!
      
      # XML 导入
      def import_xml
        unless params[:file]
          render json: { success: false, message: "请上传文件" }, status: :bad_request
          return
        end
        
        begin
          # 保存上传文件
          temp_file = Tempfile.new(['import', '.xml'])
          temp_file.binmode
          temp_file.write(params[:file].read)
          temp_file.rewind
          
          # 解析 XML
          parser = MsProjectXmlParser.new(temp_file.path)
          data = parser.parse
          
          # 创建项目和工作包 (简化示例)
          project = create_project_from_data(data)
          
          temp_file.close
          temp_file.unlink
          
          render json: {
            success: true,
            message: "导入成功",
            project_id: project&.id,
            tasks_count: data[:tasks]&.count || 0,
            resources_count: data[:resources]&.count || 0
          }
        rescue StandardError => e
          render json: {
            success: false,
            message: "导入失败：#{e.message}"
          }, status: :unprocessable_entity
        end
      end
      
      # Excel/CSV 导入
      def import_excel
        unless params[:file]
          render json: { success: false, message: "请上传文件" }, status: :bad_request
          return
        end
        
        begin
          # 保存上传文件
          temp_file = Tempfile.new(['import', File.extname(params[:file].original_filename)])
          temp_file.binmode
          temp_file.write(params[:file].read)
          temp_file.rewind
          
          # 解析 Excel/CSV
          service = ExcelImportService.new(temp_file.path)
          data = service.import
          
          # 创建项目和工作包
          project = create_project_from_data(data)
          
          temp_file.close
          temp_file.unlink
          
          render json: {
            success: true,
            message: "导入成功",
            project_id: project&.id,
            tasks_count: data[:tasks]&.count || 0,
            resources_count: data[:resources]&.count || 0
          }
        rescue StandardError => e
          render json: {
            success: false,
            message: "导入失败：#{e.message}"
          }, status: :unprocessable_entity
        end
      end
      
      # 导出项目
      def export
        project_id = params[:project_id]
        format = params[:format] || 'xml'
        
        unless project_id
          render json: { success: false, message: "请指定项目 ID" }, status: :bad_request
          return
        end
        
        begin
          project = Project.find(project_id)
          
          # 检查权限
          unless authorize_project_export(project)
            render json: { success: false, message: "无权限导出该项目" }, status: :forbidden
            return
          end
          
          # 导出
          service = ExportService.new(project_id)
          output_path = Rails.root.join('tmp', "export_#{project_id}_#{Time.now.to_i}.#{format}")
          service.export_to_file(format, output_path)
          
          # 返回下载链接
          render json: {
            success: true,
            message: "导出成功",
            download_url: "/msproject_import/api/export/download/#{File.basename(output_path)}",
            filename: File.basename(output_path),
            format: format,
            size: File.size(output_path)
          }
        rescue ActiveRecord::RecordNotFound
          render json: {
            success: false,
            message: "项目不存在"
          }, status: :not_found
        rescue StandardError => e
          render json: {
            success: false,
            message: "导出失败：#{e.message}"
          }, status: :unprocessable_entity
        end
      end
      
      # 下载导出文件
      def download_export
        filename = params[:filename]
        file_path = Rails.root.join('tmp', filename)
        
        unless File.exist?(file_path)
          render json: { success: false, message: "文件不存在" }, status: :not_found
          return
        end
        
        send_file(file_path, disposition: 'attachment')
      end
      
      # 获取支持的格式
      def supported_formats
        render json: {
          success: true,
          import_formats: {
            xml: { extension: '.xml', name: 'MS Project XML' },
            xlsx: { extension: '.xlsx', name: 'Excel' },
            xls: { extension: '.xls', name: 'Excel 97-2003' },
            csv: { extension: '.csv', name: 'CSV' }
          },
          export_formats: ExportService.supported_formats
        }
      end
      
      # 获取导入模板
      def import_template
        format = params[:format] || 'xlsx'
        
        case format
        when 'xlsx', 'xls'
          send_data generate_excel_template, 
                    filename: 'msproject_import_template.xlsx',
                    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                    disposition: 'attachment'
        when 'csv'
          send_data generate_csv_template,
                    filename: 'msproject_import_template.csv',
                    type: 'text/csv',
                    disposition: 'attachment'
        else
          render json: { success: false, message: "不支持的格式" }, status: :bad_request
        end
      end
      
      private
      
      # 从数据创建项目
      def create_project_from_data(data)
        # 这里简化处理，实际需要根据数据创建完整的项目结构
        project = Project.new(
          name: data[:project][:title] || "Imported Project #{Time.now.to_i}",
          status: 'active',
          start_date: data[:project][:start_date],
          due_date: data[:project][:finish_date]
        )
        
        # 保存项目
        if project.save
          # 创建工作包
          data[:tasks]&.each do |task_data|
            WorkPackage.create!(
              project: project,
              subject: task_data[:name],
              start_date: task_data[:start],
              due_date: task_data[:finish],
              estimated_hours: task_data[:duration],
              percent_complete: task_data[:percent_complete],
              description: task_data[:notes]
            )
          end
          
          project
        else
          nil
        end
      end
      
      # 授权检查
      def authorize_project_export(project)
        # 简化权限检查
        User.current.admin? || project.members.exists?(user_id: User.current.id)
      end
      
      # 生成 Excel 模板
      def generate_excel_template
        require 'spreadsheet'
        
        workbook = Spreadsheet::Workbook.new
        
        # Tasks 工作表
        tasks_sheet = workbook.create_worksheet(name: 'Tasks')
        tasks_sheet.row(0).concat([
          'UID', 'ID', 'Name', 'WBS', 'OutlineLevel',
          'Start', 'Finish', 'Duration', 'PercentComplete',
          'Milestone', 'Summary', 'Priority', 'Notes', 'Predecessors', 'ResourceNames'
        ])
        
        # 示例数据
        tasks_sheet.row(1).concat([
          1, 1, 'Task 1', '1', 1,
          '2026-01-01 08:00:00', '2026-01-05 17:00:00', '40h',
          0, 0, 0, 500, 'Example task', '', ''
        ])
        
        # Resources 工作表
        resources_sheet = workbook.create_worksheet(name: 'Resources')
        resources_sheet.row(0).concat([
          'UID', 'Name', 'Type', 'EmailAddress', 'MaxUnits', 'StandardRate'
        ])
        
        # 示例数据
        resources_sheet.row(1).concat([
          1, 'John Doe', 1, 'john@example.com', 1, 0
        ])
        
        # 写入临时文件
        temp_file = Tempfile.new(['template', '.xlsx'])
        workbook.write(temp_file.path)
        data = File.read(temp_file.path)
        temp_file.close
        temp_file.unlink
        
        data
      end
      
      # 生成 CSV 模板
      def generate_csv_template
        require 'csv'
        
        CSV.generate(headers: true) do |csv|
          # 表头
          csv << [
            'UID', 'ID', 'Name', 'WBS', 'OutlineLevel',
            'Start', 'Finish', 'Duration', 'PercentComplete',
            'Milestone', 'Summary', 'Priority', 'Notes', 'Predecessors', 'ResourceNames'
          ]
          
          # 示例数据
          csv << [
            1, 1, 'Task 1', '1', 1,
            '2026-01-01 08:00:00', '2026-01-05 17:00:00', '40h',
            0, 0, 0, 500, 'Example task', '', ''
          ]
        end
      end
    end
  end
end
