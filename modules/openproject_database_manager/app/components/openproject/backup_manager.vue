<template>
  <div class="backup-manager">
    <div class="header">
      <h2>备份与恢复</h2>
      <button @click="showBackupDialog = true" class="btn-primary">
        + 创建备份
      </button>
    </div>
    
    <!-- 备份统计 -->
    <div class="stats-cards">
      <div class="stat-card">
        <h3>总备份数</h3>
        <div class="value">{{ stats.total || 0 }}</div>
      </div>
      <div class="stat-card">
        <h3>成功备份</h3>
        <div class="value success">{{ stats.completed || 0 }}</div>
      </div>
      <div class="stat-card">
        <h3>失败备份</h3>
        <div class="value danger">{{ stats.failed || 0 }}</div>
      </div>
      <div class="stat-card">
        <h3>总大小</h3>
        <div class="value">{{ stats.total_size || '0 B' }}</div>
      </div>
    </div>
    
    <!-- 备份列表 -->
    <div class="backup-list">
      <h3>备份历史</h3>
      
      <table class="backup-table">
        <thead>
          <tr>
            <th>名称</th>
            <th>类型</th>
            <th>大小</th>
            <th>压缩</th>
            <th>状态</th>
            <th>创建时间</th>
            <th>操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="backup in backups" :key="backup.id">
            <td>{{ backup.backup_name }}</td>
            <td>{{ backup.backup_type }}</td>
            <td>{{ backup.human_size }}</td>
            <td>{{ backup.compression }}</td>
            <td>
              <span class="status-badge" :class="backup.status">
                {{ getStatusText(backup.status) }}
              </span>
            </td>
            <td>{{ formatDate(backup.created_at) }}</td>
            <td class="actions">
              <button @click="downloadBackup(backup)" :disabled="backup.status !== 'completed'">
                下载
              </button>
              <button @click="restoreBackup(backup)" 
                      :disabled="backup.status !== 'completed'" 
                      class="btn-warning">
                恢复
              </button>
              <button @click="deleteBackup(backup)" class="btn-danger">
                删除
              </button>
            </td>
          </tr>
          <tr v-if="backups.length === 0">
            <td colspan="7" class="empty">暂无备份记录</td>
          </tr>
        </tbody>
      </table>
    </div>
    
    <!-- 恢复记录 -->
    <div class="restore-history">
      <h3>恢复历史</h3>
      
      <table class="restore-table">
        <thead>
          <tr>
            <th>备份名称</th>
            <th>状态</th>
            <th>开始时间</th>
            <th>完成时间</th>
            <th>耗时</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="restore in restores" :key="restore.id">
            <td>{{ restore.backup_name }}</td>
            <td>
              <span class="status-badge" :class="restore.status">
                {{ getStatusText(restore.status) }}
              </span>
            </td>
            <td>{{ formatDate(restore.started_at) }}</td>
            <td>{{ formatDate(restore.completed_at) }}</td>
            <td>{{ restore.human_duration || '-' }}</td>
          </tr>
          <tr v-if="restores.length === 0">
            <td colspan="5" class="empty">暂无恢复记录</td>
          </tr>
        </tbody>
      </table>
    </div>
    
    <!-- 创建备份对话框 -->
    <div v-if="showBackupDialog" class="dialog-overlay">
      <div class="dialog">
        <h3>创建备份</h3>
        <form @submit.prevent="createBackup">
          <div class="form-group">
            <label>备份名称</label>
            <input v-model="backupForm.name" 
                   :placeholder="getDefaultBackupName()" />
          </div>
          
          <div class="form-group">
            <label>压缩方式</label>
            <select v-model="backupForm.compression">
              <option value="gzip">Gzip (推荐)</option>
              <option value="zip">Zip</option>
              <option value="none">不压缩</option>
            </select>
          </div>
          
          <div class="form-group">
            <label>保留天数</label>
            <input type="number" v-model="backupForm.retain_days" 
                   placeholder="0 = 永久保留" min="0" />
          </div>
          
          <div class="dialog-actions">
            <button type="button" @click="showBackupDialog = false" class="btn-secondary">
              取消
            </button>
            <button type="submit" class="btn-primary">
              创建备份
            </button>
          </div>
        </form>
      </div>
    </div>
    
    <!-- 恢复确认对话框 -->
    <div v-if="showRestoreDialog" class="dialog-overlay">
      <div class="dialog">
        <h3 class="danger">⚠️ 确认恢复</h3>
        <p class="warning-text">
          恢复操作将覆盖当前数据库！此操作不可逆。
        </p>
        <p>
          <strong>备份名称:</strong> {{ selectedBackup?.backup_name }}<br>
          <strong>备份时间:</strong> {{ formatDate(selectedBackup?.created_at) }}<br>
          <strong>备份大小:</strong> {{ selectedBackup?.human_size }}
        </p>
        <div class="dialog-actions">
          <button type="button" @click="showRestoreDialog = false" class="btn-secondary">
            取消
          </button>
          <button type="button" @click="confirmRestore" class="btn-danger">
            确认恢复
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'BackupManager',
  data() {
    return {
      configId: null,
      stats: {},
      backups: [],
      restores: [],
      showBackupDialog: false,
      showRestoreDialog: false,
      selectedBackup: null,
      backupForm: {
        name: '',
        compression: 'gzip',
        retain_days: 0
      }
    }
  },
  mounted() {
    this.configId = this.getConfigId()
    this.loadStats()
    this.loadBackups()
    this.loadRestores()
    
    // 每 10 秒刷新一次状态
    this.refreshInterval = setInterval(() => {
      this.loadBackups()
    }, 10000)
  },
  beforeDestroy() {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval)
    }
  },
  methods: {
    getConfigId() {
      // 从 URL 或 localStorage 获取当前配置的 ID
      const params = new URLSearchParams(window.location.search)
      return params.get('config_id') || localStorage.getItem('current_db_config')
    },
    async loadStats() {
      if (!this.configId) return
      
      const response = await fetch(`/database_manager/api/configs/${this.configId}/backup_stats`)
      const data = await response.json()
      if (data.success) {
        this.stats = data.stats
      }
    },
    async loadBackups() {
      if (!this.configId) return
      
      const response = await fetch(`/database_manager/api/configs/${this.configId}/list_backups`)
      const data = await response.json()
      if (data.success) {
        this.backups = data.backups
      }
    },
    async loadRestores() {
      if (!this.configId) return
      
      const response = await fetch(`/database_manager/api/restores?config_id=${this.configId}`)
      const data = await response.json()
      if (data.success) {
        this.restores = data.restores
      }
    },
    async createBackup() {
      const response = await fetch(`/database_manager/api/configs/${this.configId}/create_backup`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(this.backupForm)
      })
      
      const data = await response.json()
      if (data.success) {
        alert('备份已创建，正在后台执行')
        this.showBackupDialog = false
        this.resetForm()
        this.loadStats()
        this.loadBackups()
      } else {
        alert('创建失败：' + data.message)
      }
    },
    async downloadBackup(backup) {
      window.open(`/database_manager/api/backups/${backup.id}/download`, '_blank')
    },
    restoreBackup(backup) {
      this.selectedBackup = backup
      this.showRestoreDialog = true
    },
    async confirmRestore() {
      const response = await fetch(`/database_manager/api/backups/${this.selectedBackup.id}/restore`, {
        method: 'POST'
      })
      
      const data = await response.json()
      if (data.success) {
        alert('恢复已启动，正在后台执行')
        this.showRestoreDialog = false
        this.selectedBackup = null
        this.loadRestores()
      } else {
        alert('恢复失败：' + data.message)
      }
    },
    async deleteBackup(backup) {
      if (!confirm(`确定要删除备份 "${backup.backup_name}" 吗？`)) return
      
      const response = await fetch(`/database_manager/api/backups/${backup.id}`, {
        method: 'DELETE'
      })
      
      const data = await response.json()
      if (data.success) {
        alert('备份已删除')
        this.loadStats()
        this.loadBackups()
      } else {
        alert('删除失败：' + data.message)
      }
    },
    getStatusText(status) {
      const texts = {
        pending: '等待中',
        running: '执行中',
        completed: '已完成',
        failed: '失败'
      }
      return texts[status] || status
    },
    formatDate(dateStr) {
      if (!dateStr) return '-'
      const date = new Date(dateStr)
      return date.toLocaleString('zh-CN')
    },
    getDefaultBackupName() {
      const now = new Date()
      return `backup_${now.toISOString().replace(/[:.]/g, '-').slice(0, 19)}`
    },
    resetForm() {
      this.backupForm = {
        name: '',
        compression: 'gzip',
        retain_days: 0
      }
    }
  }
}
</script>

<style scoped>
.backup-manager {
  padding: 20px;
  max-width: 1400px;
  margin: 0 auto;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 30px;
}

.stats-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 20px;
  margin-bottom: 30px;
}

.stat-card {
  background: white;
  padding: 20px;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.stat-card h3 {
  margin: 0 0 10px 0;
  font-size: 0.9em;
  color: #666;
}

.stat-card .value {
  font-size: 2em;
  font-weight: bold;
  color: #333;
}

.stat-card .value.success {
  color: #28a745;
}

.stat-card .value.danger {
  color: #dc3545;
}

.backup-list, .restore-history {
  background: white;
  padding: 20px;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  margin-bottom: 20px;
}

.backup-list h3, .restore-history h3 {
  margin: 0 0 20px 0;
  color: #333;
}

.backup-table, .restore-table {
  width: 100%;
  border-collapse: collapse;
}

.backup-table th, .backup-table td,
.restore-table th, .restore-table td {
  padding: 12px;
  text-align: left;
  border-bottom: 1px solid #eee;
}

.backup-table th, .restore-table th {
  background: #f8f9fa;
  font-weight: 600;
}

.backup-table .empty, .restore-table .empty {
  text-align: center;
  color: #999;
  padding: 40px !important;
}

.status-badge {
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 0.85em;
}

.status-badge.pending {
  background: #ffc107;
  color: #333;
}

.status-badge.running {
  background: #17a2b8;
  color: white;
}

.status-badge.completed {
  background: #28a745;
  color: white;
}

.status-badge.failed {
  background: #dc3545;
  color: white;
}

.actions {
  display: flex;
  gap: 8px;
}

.dialog-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0,0,0,0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.dialog {
  background: white;
  padding: 30px;
  border-radius: 8px;
  min-width: 400px;
  max-width: 500px;
}

.dialog h3.danger {
  color: #dc3545;
}

.warning-text {
  background: #fff3cd;
  border-left: 4px solid #ffc107;
  padding: 12px;
  margin: 15px 0;
  color: #856404;
}

.form-group {
  margin-bottom: 15px;
}

.form-group label {
  display: block;
  margin-bottom: 5px;
  font-weight: 500;
}

.form-group input, .form-group select {
  width: 100%;
  padding: 8px;
  border: 1px solid #ddd;
  border-radius: 4px;
}

.dialog-actions {
  display: flex;
  gap: 10px;
  justify-content: flex-end;
  margin-top: 20px;
}

.btn-primary {
  background: #007bff;
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 4px;
  cursor: pointer;
}

.btn-secondary {
  background: #6c757d;
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 4px;
  cursor: pointer;
}

.btn-warning {
  background: #ffc107;
  color: #333;
  border: none;
  padding: 8px 16px;
  border-radius: 4px;
  cursor: pointer;
}

.btn-danger {
  background: #dc3545;
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 4px;
  cursor: pointer;
}

button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>
