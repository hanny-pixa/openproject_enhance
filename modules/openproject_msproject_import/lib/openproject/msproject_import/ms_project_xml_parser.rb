# frozen_string_literal: true

module OpenProject
  module MsprojectImport
    # MS Project XML 解析器
    class MsProjectXmlParser
      NAMESPACE = "http://schemas.microsoft.com/project"
      
      attr_reader :xml_path, :project_data
      
      def initialize(xml_path)
        @xml_path = xml_path
        @project_data = {}
      end
      
      def parse
        doc = Nokogiri::XML(File.read(xml_path))
        doc.remove_namespaces!
        
        @project_data = {
          project: parse_project_info(doc),
          tasks: parse_tasks(doc),
          resources: parse_resources(doc),
          assignments: parse_assignments(doc),
          calendars: parse_calendars(doc)
        }
        
        @project_data
      end
      
      private
      
      def parse_project_info(doc)
        {
          title: find_text(doc, "Title"),
          start_date: parse_date(find_text(doc, "StartDate")),
          finish_date: parse_date(find_text(doc, "FinishDate")),
          current_date: parse_date(find_text(doc, "CurrentDate")),
          minutes_per_day: (find_text(doc, "MinutesPerDay") || 480).to_i,
          currency_symbol: find_text(doc, "CurrencySymbol"),
          schedule_from_start: find_text(doc, "ScheduleFromStart") == "1"
        }
      end
      
      def parse_tasks(doc)
        tasks_elem = doc.at_xpath("//Tasks")
        return [] unless tasks_elem
        
        tasks_elem.xpath("Task").map do |task_elem|
          {
            uid: find_int(task_elem, "UID"),
            id: find_int(task_elem, "ID"),
            name: find_text(task_elem, "Name"),
            wbs: find_text(task_elem, "WBS"),
            outline_level: find_int(task_elem, "OutlineLevel"),
            outline_number: find_text(task_elem, "OutlineNumber"),
            start: parse_date(find_text(task_elem, "Start")),
            finish: parse_date(find_text(task_elem, "Finish")),
            duration: parse_duration(find_text(task_elem, "Duration")),
            remaining_duration: parse_duration(find_text(task_elem, "RemainingDuration")),
            percent_complete: find_float(task_elem, "PercentComplete"),
            percent_work_complete: find_float(task_elem, "PercentWorkComplete"),
            is_milestone: find_int(task_elem, "Milestone"),
            is_summary: find_int(task_elem, "Summary"),
            is_critical: find_int(task_elem, "Critical"),
            is_active: find_int(task_elem, "Active"),
            is_manual: find_int(task_elem, "Manual"),
            priority: find_int(task_elem, "Priority"),
            notes: find_text(task_elem, "Notes"),
            constraint_type: find_int(task_elem, "ConstraintType"),
            manual_start: parse_date(find_text(task_elem, "ManualStart")),
            manual_finish: parse_date(find_text(task_elem, "ManualFinish")),
            manual_duration: parse_duration(find_text(task_elem, "ManualDuration")),
            predecessors: parse_predecessors(task_elem)
          }
        end
      end
      
      def parse_predecessors(task_elem)
        predecessors = []
        task_elem.xpath("PredecessorLink").each do |pred_elem|
          predecessors << {
            predecessor_uid: find_int(pred_elem, "PredecessorUID"),
            link_type: find_int(pred_elem, "Type") || 1, # 1=FS, 2=SS, 3=FF, 4=SF
            cross_project: find_int(pred_elem, "CrossProject") == 1
          }
        end
        predecessors
      end
      
      def parse_resources(doc)
        resources_elem = doc.at_xpath("//Resources")
        return [] unless resources_elem
        
        resources_elem.xpath("Resource").map do |res_elem|
          {
            uid: find_int(res_elem, "UID"),
            id: find_int(res_elem, "ID"),
            name: find_text(res_elem, "Name"),
            type: find_int(res_elem, "Type"), # 1=Work, 2=Material, 3=Cost
            email: find_text(res_elem, "EmailAddress"),
            max_units: find_float(res_elem, "MaxUnits"),
            standard_rate: find_float(res_elem, "StandardRate"),
            overtime_rate: find_float(res_elem, "OvertimeRate"),
            can_level: find_int(res_elem, "CanLevel") == 1,
            is_generic: find_int(res_elem, "IsGeneric") == 1,
            is_inactive: find_int(res_elem, "IsInactive") == 1
          }
        end
      end
      
      def parse_assignments(doc)
        assignments_elem = doc.at_xpath("//Assignments")
        return [] unless assignments_elem
        
        assignments_elem.xpath("Assignment").map do |assign_elem|
          {
            uid: find_int(assign_elem, "UID"),
            task_uid: find_int(assign_elem, "TaskUID"),
            resource_uid: find_int(assign_elem, "ResourceUID"),
            units: find_float(assign_elem, "Units"),
            work: parse_duration(find_text(assign_elem, "Work")),
            remaining_work: parse_duration(find_text(assign_elem, "RemainingWork")),
            actual_work: parse_duration(find_text(assign_elem, "ActualWork")),
            percent_work_complete: find_float(assign_elem, "PercentWorkComplete"),
            start: parse_date(find_text(assign_elem, "Start")),
            finish: parse_date(find_text(assign_elem, "Finish"))
          }
        end
      end
      
      def parse_calendars(doc)
        calendars_elem = doc.at_xpath("//Calendars")
        return [] unless calendars_elem
        
        calendars_elem.xpath("Calendar").map do |cal_elem|
          {
            uid: find_int(cal_elem, "UID"),
            name: find_text(cal_elem, "Name"),
            is_base_calendar: find_int(cal_elem, "IsBaseCalendar") == 1,
            week_days: parse_week_days(cal_elem)
          }
        end
      end
      
      def parse_week_days(cal_elem)
        week_days = []
        cal_elem.xpath("WeekDays/WeekDay").each do |day_elem|
          week_days << {
            day_type: find_int(day_elem, "DayType"), # 1=Exception, 2-7=Mon-Sun
            day_working: find_int(day_elem, "DayWorking") == 1,
            working_times: parse_working_times(day_elem)
          }
        end
        week_days
      end
      
      def parse_working_times(day_elem)
        working_times = []
        day_elem.xpath("WorkingTimes/WorkingTime").each do |time_elem|
          working_times << {
            from_time: parse_time(find_text(time_elem, "FromTime")),
            to_time: parse_time(find_text(time_elem, "ToTime"))
          }
        end
        working_times
      end
      
      # 辅助方法
      
      def find_text(elem, xpath)
        node = elem.at_xpath(xpath)
        node ? node.text&.strip : nil
      end
      
      def find_int(elem, xpath)
        text = find_text(elem, xpath)
        text ? text.to_i : nil
      end
      
      def find_float(elem, xpath)
        text = find_text(elem, xpath)
        text ? text.to_f : nil
      end
      
      def parse_date(date_str)
        return nil if date_str.blank?
        
        # 处理 ISO 8601 格式
        begin
          DateTime.parse(date_str).to_time
        rescue ArgumentError
          nil
        end
      end
      
      def parse_time(time_str)
        return nil if time_str.blank?
        
        # 处理 HH:MM:SS 格式
        parts = time_str.split(":")
        return nil if parts.length < 2
        
        {
          hour: parts[0].to_i,
          minute: parts[1].to_i,
          second: parts[2].to_i rescue 0
        }
      end
      
      def parse_duration(duration_str)
        return 0 if duration_str.blank?
        
        # ISO 8601 持续时间格式: PTxxHyyMzzS
        match = duration_str.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/)
        return 0 unless match
        
        hours = (match[1] || 0).to_i
        minutes = (match[2] || 0).to_i
        seconds = (match[3] || 0).to_i
        
        hours + minutes / 60.0 + seconds / 3600.0
      end
    end
  end
end
