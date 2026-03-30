# frozen_string_literal: true

# 数据库配置管理表
class CreateDatabaseConfigs < ActiveRecord::Migration[8.0]
  def change
    create_table :database_configs do |t|
      t.string :name, null: false
      t.string :adapter, null: false
      t.string :database, null: false
      t.string :host
      t.integer :port
      t.string :username
      t.string :password
      t.integer :pool, default: 5
      t.integer :timeout, default: 5000
      t.string :encoding, default: "utf8"
      t.text :connection_options
      t.boolean :is_active, default: false
      t.boolean :is_tested, default: false
      t.datetime :last_tested_at
      t.datetime :last_connected_at
      
      t.timestamps
    end
    
    add_index :database_configs, :name, unique: true
    add_index :database_configs, :is_active
    add_index :database_configs, :adapter
  end
end
