<template>
  <div class="database-manager">
    <h2>数据库管理</h2>
    
    <!-- 当前数据库信息 -->
    <div class="current-db-card">
      <h3>当前数据库</h3>
      <div class="db-info">
        <span class="db-name">{{ currentConfig.name }}</span>
        <span class="db-adapter">{{ currentConfig.adapter }}</span>
        <span class="db-size">{{ currentConfig.size }}</span>
      </div>
    </div>
    
    <!-- 数据库列表 -->
    <div class="db-list">
      <div class="toolbar">
        <button @click="showAddDialog = true" class="btn-primary">
          + 添加数据库
        </button>
        <button @click="refreshList" class="btn-secondary">
          刷新
        </button>
      </div>
      
      <table class="db-table">
        <thead>
          <tr>
            <th>名称</th>
            <th>类型</th>
            <th>数据库</th>
            <th>主机</th>
            <th>状态</th>
            <th>大小</th>
            <th>操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="config in configs" :key="config.id" :class="{ active: config.is_active }">
            <td>{{ config.name }}</td>
            <td>{{ getAdapterName(config.adapter) }}</td>
            <td>{{ config.database }}</td>
            <td>{{ config.host || '本地' }}</td>
            <td>
              <span class="status-badge" :class="config.is_active ? 'active' : 'inactive'">
                {{ config.is_active ? '使用中' : '未激活' }}
              </span>
            </td>
            <td>{{ config.human_size || 'N/A' }}</td>
            <td class="actions">
              <button @click="testConnection(config)" :disabled="config.is_active">
                测试连接
              </button>
              <button @click="switchDatabase(config)" :disabled="config.is_active" class="btn-warning">
                切换
              </button>
              <button @click="editConfig(config)" :disabled="config.is_active">
                编辑
              </button>
              <button @click="deleteConfig(config)" :disabled="config.is_active" class="btn-danger">
                删除
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    
    <!-- 添加/编辑对话框 -->
    <div v-if="showAddDialog || showEditDialog" class="dialog-overlay">
      <div class="dialog">
        <h3>{{ showEditDialog ? '编辑数据库' : '添加数据库' }}</h3>
        <form @submit.prevent="saveConfig">
          <div class="form-group">
            <label>名称 *</label>
            <input v-model="formData.name" required />
          </div>
          
          <div class="form-group">
            <label>数据库类型 *</label>
            <select v-model="formData.adapter" required>
              <option value="sqlite3">SQLite</option>
              <option value="postgresql">PostgreSQL</option>
              <option value="mysql2">MySQL</option>
            </select>
          </div>
          
          <div class="form-group">
            <label>数据库文件/名称 *</label>
            <input v-model="formData.database" required 
                   :placeholder="formData.adapter === 'sqlite3' ? 'db/production.sqlite3' : 'database_name'" />
          </div>
          
          <div class="form-row">
            <div class="form-group">
              <label>主机</label>
              <input v-model="formData.host" placeholder="localhost" />
            </div>
            <div class="form-group">
              <label>端口</label>
              <input v-model="formData.port" 
                     :placeholder="getDefaultPort(formData.adapter)" />
            </div>
          </div>
          
          <div class="form-row">
            <div class="form-group">
              <label>用户名</label>
              <input v-model="formData.username" />
            </div>
            <div class="form-group">
              <label>密码</label>
              <input type="password" v-model="formData.password" />
            </div>
          </div>
          
          <div class="form-row">
            <div class="form-group">
              <label>连接池</label>
              <input type="number" v-model="formData.pool" default="5" />
            </div>
            <div class="form-group">
              <label>超时 (ms)</label>
              <input type="number" v-model="formData.timeout" default="5000" />
            </div>
          </div>
          
          <div class="dialog-actions">
            <button type="button" @click="closeDialog" class="btn-secondary">取消</button>
            <button type="submit" class="btn-primary">保存</button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'DatabaseManager',
  data() {
    return {
      configs: [],
      currentConfig: {},
      showAddDialog: false,
      showEditDialog: false,
      formData: {
        name: '',
        adapter: 'sqlite3',
        database: '',
        host: '',
        port: '',
        username: '',
        password: '',
        pool: 5,
        timeout: 5000,
        encoding: 'utf8'
      }
    }
  },
  mounted() {
    this.loadConfigs()
    this.loadCurrentConfig()
  },
  methods: {
    async loadConfigs() {
      const response = await fetch('/database_manager/api/configs')
      const data = await response.json()
      this.configs = data
    },
    async loadCurrentConfig() {
      const response = await fetch('/database_manager/api/current')
      const data = await response.json()
      this.currentConfig = data.config
    },
    async testConnection(config) {
      const response = await fetch(`/database_manager/api/configs/${config.id}/test`, {
        method: 'POST'
      })
      const data = await response.json()
      alert(data.connected ? '连接成功!' : '连接失败：' + data.error)
    },
    async switchDatabase(config) {
      if (!confirm(`确定要切换到 ${config.name} 吗？系统将重启数据库连接。`)) return
      
      const response = await fetch(`/database_manager/api/configs/${config.id}/switch`, {
        method: 'POST'
      })
      const data = await response.json()
      if (data.success) {
        alert('切换成功!')
        this.loadConfigs()
        this.loadCurrentConfig()
      } else {
        alert('切换失败：' + data.message)
      }
    },
    async saveConfig() {
      const url = this.showEditDialog 
        ? `/database_manager/api/configs/${this.formData.id}`
        : '/database_manager/api/configs'
      
      const method = this.showEditDialog ? 'PUT' : 'POST'
      
      const response = await fetch(url, {
        method: method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ database_config: this.formData })
      })
      
      const data = await response.json()
      if (data.success) {
        this.closeDialog()
        this.loadConfigs()
        alert('保存成功!')
      } else {
        alert('保存失败：' + data.errors.join(', '))
      }
    },
    editConfig(config) {
      this.formData = { ...config }
      this.showEditDialog = true
    },
    async deleteConfig(config) {
      if (!confirm(`确定要删除 ${config.name} 吗？此操作不可恢复。`)) return
      
      const response = await fetch(`/database_manager/api/configs/${config.id}`, {
        method: 'DELETE'
      })
      const data = await response.json()
      if (data.success) {
        this.loadConfigs()
        alert('删除成功!')
      } else {
        alert('删除失败：' + data.message)
      }
    },
    closeDialog() {
      this.showAddDialog = false
      this.showEditDialog = false
      this.formData = {
        name: '', adapter: 'sqlite3', database: '', host: '',
        port: '', username: '', password: '', pool: 5, timeout: 5000, encoding: 'utf8'
      }
    },
    getAdapterName(adapter) {
      const names = {
        sqlite3: 'SQLite',
        postgresql: 'PostgreSQL',
        mysql2: 'MySQL'
      }
      return names[adapter] || adapter
    },
    getDefaultPort(adapter) {
      const ports = {
        sqlite3: '',
        postgresql: '5432',
        mysql2: '3306'
      }
      return ports[adapter] || ''
    },
    refreshList() {
      this.loadConfigs()
      this.loadCurrentConfig()
    }
  }
}
</script>

<style scoped>
.database-manager {
  padding: 20px;
  max-width: 1200px;
  margin: 0 auto;
}

.current-db-card {
  background: #f5f5f5;
  padding: 20px;
  border-radius: 8px;
  margin-bottom: 20px;
}

.db-info {
  display: flex;
  gap: 20px;
  margin-top: 10px;
}

.db-name {
  font-weight: bold;
  font-size: 1.2em;
}

.db-adapter, .db-size {
  color: #666;
}

.toolbar {
  display: flex;
  gap: 10px;
  margin-bottom: 20px;
}

.db-table {
  width: 100%;
  border-collapse: collapse;
}

.db-table th, .db-table td {
  padding: 12px;
  text-align: left;
  border-bottom: 1px solid #ddd;
}

.db-table tr.active {
  background: #e3f2fd;
}

.status-badge {
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 0.85em;
}

.status-badge.active {
  background: #4caf50;
  color: white;
}

.status-badge.inactive {
  background: #9e9e9e;
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
  min-width: 500px;
  max-width: 600px;
}

.form-group {
  margin-bottom: 15px;
}

.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 15px;
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
