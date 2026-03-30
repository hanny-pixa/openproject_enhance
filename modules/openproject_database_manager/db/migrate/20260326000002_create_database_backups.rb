# frozen_string_literal: true

# 数据库备份模型
class CreateDatabaseBackups < ActiveRecord::Migration[8.0]
  def change
    create_table :database_backups do |t|
      t.references :database_config, null: false, foreign_key: { to_table: :database_configs }
      t.string :backup_name, null: false
      t.string :backup_path, null: false
      t.string :backup_type, default: "full" # full/incremental
      t.integer :backup_size, default: 0 # bytes
      t.string :compression, default: "gzip" # none/gzip/zip
      t.string :status, default: "pending" # pending/running/completed/failed
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :expires_at
      t.boolean :is_auto_backup, default: false
      t.string :checksum # MD5/SHA256
      t.text :metadata, default: {} # 额外元数据 (JSON)
      
      t.timestamps
    end
    
    add_index :database_backups, :status
    add_index :database_backups, :is_auto_backup
    add_index :database_backups, [:database_config_id, :created_at]
    add_index :database_backups, :expires_at
  end
end
