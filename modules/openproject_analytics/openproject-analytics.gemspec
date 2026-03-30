# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __FILE__))

Gem::Specification.new do |s|
  s.name = "openproject-analytics"
  s.version = "1.0.0"
  s.summary = "Analytics and Reporting for OpenProject"
  s.description = "Generate various project management reports and statistics"
  s.authors = ["OpenProject Analytics Team"]
  s.email = ["support@example.com"]
  s.homepage = "https://github.com/opf/openproject"
  s.license = "GPL-3.0"
  
  s.files = Dir["{app,config,db,lib}/**/*", "LICENSE", "README.md"]
  s.require_path = "lib"
  
  # 依赖
  s.add_dependency "chartkick", "~> 5.0"
  s.add_dependency "groupdate", "~> 6.4"
  s.add_dependency "spreadsheet_architect", "~> 5.0"
  
  # OpenProject 核心依赖
  s.add_dependency "openproject-core", ">= 15.0.0"
end
