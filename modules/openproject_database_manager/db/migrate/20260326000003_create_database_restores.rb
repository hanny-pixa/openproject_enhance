# frozen_string_literal: true

# 数据库恢复记录表
class CreateDatabaseRestores < ActiveRecord::Migration[8.0]
  def change
    create_table :database_restores do |t|
      t.references :database_config, null: false, foreign_key: { to_table: :database_configs }
      t.references :backup, null: false, foreign_key: { to_table: :database_backups }
      t.string :status, default: "pending" # pending/running/completed/failed
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.boolean :rollback_available, default: false
      t.string :rollback_backup_path
      
      t.timestamps
    end
    
    add_index :database_restores, :status
    add_index :database_restores, [:database_config_id, :created_at]
  end
end
