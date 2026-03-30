<template>
  <div class="msproject-import-export">
    <h2>MS Project 导入/导出</h2>
    
    <!-- 导入区域 -->
    <div class="import-section">
      <h3>📥 导入项目</h3>
      
      <div class="upload-area" 
           @dragover.prevent="dragover = true" 
           @dragleave.prevent="dragover = false"
           @drop.prevent="handleDrop"
           :class="{ dragover: dragover }">
        <div class="upload-content">
          <div class="icon">📁</div>
          <p>拖拽文件到此处，或点击选择文件</p>
          <p class="hint">支持格式：XML, XLSX, XLS, CSV</p>
          <input type="file" ref="fileInput" 
                 @change="handleFileSelect"
                 accept=".xml,.xlsx,.xls,.csv"
                 style="display: none" />
          <button @click="$refs.fileInput.click()" class="btn-primary">
            选择文件
          </button>
        </div>
      </div>
      
      <div class="format-info">
        <h4>支持的导入格式：</h4>
        <ul>
          <li><strong>MS Project XML (.xml)</strong> - Microsoft Project 原生格式</li>
          <li><strong>Excel (.xlsx, .xls)</strong> - Microsoft Excel 电子表格</li>
          <li><strong>CSV (.csv)</strong> - 逗号分隔值文件</li>
        </ul>
        
        <button @click="downloadTemplate('xlsx')" class="btn-secondary">
          📋 下载 Excel 模板
        </button>
        <button @click="downloadTemplate('csv')" class="btn-secondary">
          📋 下载 CSV 模板
        </button>
      </div>
      
      <!-- 导入进度 -->
      <div v-if="importing" class="progress-section">
        <div class="progress-bar">
          <div class="progress-fill" :style="{ width: importProgress + '%' }"></div>
        </div>
        <p>{{ importStatus }}</p>
      </div>
      
      <!-- 导入结果 -->
      <div v-if="importResult" class="result-section" :class="importResult.success ? 'success' : 'error'">
        <h4>{{ importResult.success ? '✅ 导入成功' : '❌ 导入失败' }}</h4>
        <p v-if="importResult.success">
          项目 ID: {{ importResult.project_id }}<br>
          任务数：{{ importResult.tasks_count }}<br>
          资源数：{{ importResult.resources_count }}
        </p>
        <p v-else>{{ importResult.message }}</p>
      </div>
    </div>
    
    <!-- 导出区域 -->
    <div class="export-section">
      <h3>📤 导出项目</h3>
      
      <div class="export-form">
        <div class="form-group">
          <label>选择项目 *</label>
          <select v-model="selectedProjectId" class="form-control">
            <option value="">请选择项目</option>
            <option v-for="project in projects" :key="project.id" :value="project.id">
              {{ project.name }} ({{ project.identifier }})
            </option>
          </select>
        </div>
        
        <div class="form-group">
          <label>导出格式 *</label>
          <select v-model="selectedFormat" class="form-control">
            <option value="xml">MS Project XML (.xml)</option>
            <option value="xlsx">Excel (.xlsx)</option>
            <option value="csv">CSV (.csv)</option>
            <option value="json">JSON (.json)</option>
          </select>
        </div>
        
        <button @click="exportProject" 
                :disabled="!selectedProjectId || exporting" 
                class="btn-primary">
          {{ exporting ? '导出中...' : '导出项目' }}
        </button>
      </div>
      
      <div class="format-info">
        <h4>支持的导出格式：</h4>
        <ul>
          <li><strong>MS Project XML</strong> - 可在 Microsoft Project 中打开</li>
          <li><strong>Excel</strong> - 包含任务和资源两个工作表</li>
          <li><strong>CSV</strong> - 通用格式，可导入各种工具</li>
          <li><strong>JSON</strong> - 适合程序化处理</li>
        </ul>
      </div>
      
      <!-- 导出进度 -->
      <div v-if="exporting" class="progress-section">
        <div class="progress-bar">
          <div class="progress-fill" :style="{ width: exportProgress + '%' }"></div>
        </div>
        <p>{{ exportStatus }}</p>
      </div>
      
      <!-- 导出结果 -->
      <div v-if="exportResult" class="result-section" :class="exportResult.success ? 'success' : 'error'">
        <h4>{{ exportResult.success ? '✅ 导出成功' : '❌ 导出失败' }}</h4>
        <p v-if="exportResult.success">
          文件名：{{ exportResult.filename }}<br>
          文件大小：{{ formatFileSize(exportResult.size) }}<br>
          <a :href="exportResult.download_url" target="_blank" class="btn-primary">
            📥 下载文件
          </a>
        </p>
        <p v-else>{{ exportResult.message }}</p>
      </div>
    </div>
    
    <!-- 导入历史记录 -->
    <div class="history-section">
      <h3>📜 导入历史</h3>
      <table class="history-table">
        <thead>
          <tr>
            <th>时间</th>
            <th>文件名</th>
            <th>格式</th>
            <th>任务数</th>
            <th>状态</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="record in importHistory" :key="record.id">
            <td>{{ formatDate(record.created_at) }}</td>
            <td>{{ record.filename }}</td>
            <td>{{ record.format }}</td>
            <td>{{ record.tasks_count }}</td>
            <td>
              <span class="status-badge" :class="record.success ? 'success' : 'error'">
                {{ record.success ? '成功' : '失败' }}
              </span>
            </td>
          </tr>
          <tr v-if="importHistory.length === 0">
            <td colspan="5" class="empty">暂无导入记录</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script>
export default {
  name: 'MsProjectImportExport',
  data() {
    return {
      projects: [],
      selectedProjectId: '',
      selectedFormat: 'xml',
      dragover: false,
      importing: false,
      exporting: false,
      importProgress: 0,
      exportProgress: 0,
      importStatus: '',
      exportStatus: '',
      importResult: null,
      exportResult: null,
      importHistory: []
    }
  },
  mounted() {
    this.loadProjects()
    this.loadImportHistory()
  },
  methods: {
    async loadProjects() {
      try {
        const response = await fetch('/api/v3/projects')
        if (response.ok) {
          const data = await response.json()
          this.projects = data
        }
      } catch (error) {
        console.error('Failed to load projects:', error)
      }
    },
    
    loadImportHistory() {
      // 从 localStorage 加载历史记录
      const history = localStorage.getItem('msproject_import_history')
      if (history) {
        this.importHistory = JSON.parse(history)
      }
    },
    
    handleDrop(e) {
      this.dragover = false
      const files = e.dataTransfer.files
      if (files.length > 0) {
        this.importFile(files[0])
      }
    },
    
    handleFileSelect(e) {
      const files = e.target.files
      if (files.length > 0) {
        this.importFile(files[0])
      }
    },
    
    async importFile(file) {
      this.importing = true
      this.importProgress = 0
      this.importStatus = '准备导入...'
      this.importResult = null
      
      const formData = new FormData()
      formData.append('file', file)
      
      // 根据文件扩展名选择接口
      const ext = file.name.split('.').pop().toLowerCase()
      const endpoint = ext === 'xml' 
        ? '/msproject_import/api/import/xml'
        : '/msproject_import/api/import/excel'
      
      try {
        // 模拟进度
        const progressInterval = setInterval(() => {
          if (this.importProgress < 90) {
            this.importProgress += 10
          }
        }, 200)
        
        const response = await fetch(endpoint, {
          method: 'POST',
          body: formData
        })
        
        clearInterval(progressInterval)
        this.importProgress = 100
        
        const result = await response.json()
        this.importResult = result
        
        // 保存到历史记录
        if (result.success) {
          this.addToHistory({
            filename: file.name,
            format: ext.toUpperCase(),
            tasks_count: result.tasks_count,
            success: true,
            created_at: new Date().toISOString()
          })
        }
        
        this.importStatus = result.success ? '导入完成' : '导入失败'
      } catch (error) {
        this.importResult = {
          success: false,
          message: error.message
        }
        this.importStatus = '导入失败'
      } finally {
        this.importing = false
        setTimeout(() => {
          this.importProgress = 0
        }, 1000)
      }
    },
    
    async exportProject() {
      if (!this.selectedProjectId) return
      
      this.exporting = true
      this.exportProgress = 0
      this.exportStatus = '准备导出...'
      this.exportResult = null
      
      try {
        // 模拟进度
        const progressInterval = setInterval(() => {
          if (this.exportProgress < 90) {
            this.exportProgress += 10
          }
        }, 200)
        
        const response = await fetch(
          `/msproject_import/api/export?project_id=${this.selectedProjectId}&format=${this.selectedFormat}`
        )
        
        clearInterval(progressInterval)
        this.exportProgress = 100
        
        const result = await response.json()
        this.exportResult = result
        this.exportStatus = result.success ? '导出完成' : '导出失败'
      } catch (error) {
        this.exportResult = {
          success: false,
          message: error.message
        }
        this.exportStatus = '导出失败'
      } finally {
        this.exporting = false
        setTimeout(() => {
          this.exportProgress = 0
        }, 1000)
      }
    },
    
    async downloadTemplate(format) {
      try {
        const response = await fetch(
          `/msproject_import/api/template?format=${format}`,
          { method: 'GET' }
        )
        
        if (response.ok) {
          const blob = await response.blob()
          const url = window.URL.createObjectURL(blob)
          const a = document.createElement('a')
          a.href = url
          a.download = `msproject_import_template.${format}`
          document.body.appendChild(a)
          a.click()
          document.body.removeChild(a)
          window.URL.revokeObjectURL(url)
        }
      } catch (error) {
        alert('下载模板失败：' + error.message)
      }
    },
    
    addToHistory(record) {
      record.id = Date.now()
      this.importHistory.unshift(record)
      
      // 只保留最近 20 条记录
      if (this.importHistory.length > 20) {
        this.importHistory = this.importHistory.slice(0, 20)
      }
      
      localStorage.setItem('msproject_import_history', JSON.stringify(this.importHistory))
    },
    
    formatDate(dateStr) {
      if (!dateStr) return '-'
      const date = new Date(dateStr)
      return date.toLocaleString('zh-CN')
    },
    
    formatFileSize(bytes) {
      if (!bytes) return '0 B'
      const k = 1024
      const sizes = ['B', 'KB', 'MB', 'GB']
      const i = Math.floor(Math.log(bytes) / Math.log(k))
      return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i]
    }
  }
}
</script>

<style scoped>
.msproject-import-export {
  padding: 20px;
  max-width: 1200px;
  margin: 0 auto;
}

.import-section, .export-section, .history-section {
  background: white;
  padding: 25px;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  margin-bottom: 20px;
}

h2 {
  color: #333;
  margin-bottom: 20px;
}

h3 {
  color: #555;
  margin-bottom: 15px;
}

.upload-area {
  border: 2px dashed #ddd;
  border-radius: 8px;
  padding: 40px;
  text-align: center;
  transition: all 0.3s;
  cursor: pointer;
}

.upload-area.dragover {
  border-color: #007bff;
  background: #f0f7ff;
}

.upload-content .icon {
  font-size: 3em;
  margin-bottom: 15px;
}

.hint {
  color: #999;
  font-size: 0.9em;
  margin: 10px 0;
}

.format-info {
  margin-top: 20px;
  padding: 15px;
  background: #f8f9fa;
  border-radius: 4px;
}

.format-info h4 {
  margin-bottom: 10px;
  color: #555;
}

.format-info ul {
  margin: 10px 0;
  padding-left: 20px;
}

.format-info li {
  margin: 5px 0;
  color: #666;
}

.export-form {
  margin-bottom: 20px;
}

.form-group {
  margin-bottom: 15px;
}

.form-group label {
  display: block;
  margin-bottom: 5px;
  font-weight: 600;
  color: #555;
}

.form-control {
  width: 100%;
  padding: 10px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 1em;
}

.progress-section {
  margin-top: 20px;
}

.progress-bar {
  height: 20px;
  background: #e9ecef;
  border-radius: 10px;
  overflow: hidden;
  margin-bottom: 10px;
}

.progress-fill {
  height: 100%;
  background: linear-gradient(90deg, #007bff, #0056b3);
  transition: width 0.3s;
}

.result-section {
  margin-top: 20px;
  padding: 15px;
  border-radius: 4px;
}

.result-section.success {
  background: #d4edda;
  border: 1px solid #c3e6cb;
  color: #155724;
}

.result-section.error {
  background: #f8d7da;
  border: 1px solid #f5c6cb;
  color: #721c24;
}

.history-table {
  width: 100%;
  border-collapse: collapse;
}

.history-table th, .history-table td {
  padding: 12px;
  text-align: left;
  border-bottom: 1px solid #eee;
}

.history-table th {
  background: #f8f9fa;
  font-weight: 600;
}

.history-table .empty {
  text-align: center;
  color: #999;
  padding: 40px !important;
}

.status-badge {
  padding: 4px 12px;
  border-radius: 20px;
  font-size: 0.85em;
  font-weight: 600;
}

.status-badge.success {
  background: #28a745;
  color: white;
}

.status-badge.error {
  background: #dc3545;
  color: white;
}

.btn-primary {
  background: #007bff;
  color: white;
  border: none;
  padding: 10px 20px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 1em;
}

.btn-primary:hover {
  background: #0056b3;
}

.btn-primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-secondary {
  background: #6c757d;
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 4px;
  cursor: pointer;
  margin-right: 10px;
}

.btn-secondary:hover {
  background: #5a6268;
}
</style>
