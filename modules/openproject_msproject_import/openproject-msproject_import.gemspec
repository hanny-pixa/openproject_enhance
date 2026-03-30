# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __FILE__))

Gem::Specification.new do |s|
  s.name = "openproject-msproject_import"
  s.version = "1.1.0"
  s.summary = "MS Project Import/Export for OpenProject"
  s.description = "Import Microsoft Project XML/Excel/CSV files and export to various formats"
  s.authors = ["OpenProject Team"]
  s.email = ["support@example.com"]
  s.homepage = "https://github.com/opf/openproject"
  s.license = "GPL-3.0"
  
  s.files = Dir["{app,config,db,lib}/**/*", "LICENSE", "README.md"]
  s.require_path = "lib"
  
  # 依赖
  s.add_dependency "nokogiri", "~> 1.16"
  s.add_dependency "roo", "~> 2.10"        # Excel/CSV 读取
  s.add_dependency "spreadsheet", "~> 1.3" # Excel 写入
  s.add_dependency "csv"                    # CSV 处理
  
  # OpenProject 核心依赖
  s.add_dependency "openproject-core", ">= 15.0.0"
end
