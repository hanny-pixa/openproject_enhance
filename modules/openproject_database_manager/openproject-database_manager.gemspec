# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __FILE__))

Gem::Specification.new do |s|
  s.name = "openproject-database_manager"
  s.version = "1.0.0"
  s.summary = "Database Source Manager for OpenProject"
  s.description = "Manage multiple database backends and switch between them"
  s.authors = ["OpenProject SQLite Adapter Team"]
  s.email = ["support@example.com"]
  s.homepage = "https://github.com/opf/openproject"
  s.license = "GPL-3.0"
  
  s.files = Dir["{app,config,db,lib}/**/*", "LICENSE", "README.md"]
  s.require_path = "lib"
  
  # 依赖
  s.add_dependency "nokogiri", "~> 1.16"
  s.add_dependency "pg", "~> 1.6.2"
  s.add_dependency "sqlite3", "~> 1.7.0"
  s.add_dependency "mysql2", "~> 0.5.5"
  
  # OpenProject 核心依赖
  s.add_dependency "openproject-core", ">= 15.0.0"
end
