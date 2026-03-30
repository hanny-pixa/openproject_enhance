<template>
  <div class="analytics-dashboard">
    <h2>项目统计分析</h2>
    
    <!-- 时间范围选择 -->
    <div class="filters">
      <select v-model="projectId" @change="loadAllData">
        <option value="">所有项目</option>
        <option v-for="project in projects" :key="project.id" :value="project.id">
          {{ project.name }}
        </option>
      </select>
      
      <select v-model="timeRange" @change="loadTrends">
        <option value="7">最近 7 天</option>
        <option value="30">最近 30 天</option>
        <option value="90">最近 90 天</option>
        <option value="365">最近 1 年</option>
      </select>
      
      <button @click="exportReport" class="btn-export">导出报表</button>
    </div>
    
    <!-- 概览卡片 -->
    <div class="overview-cards">
      <div class="card">
        <h3>总项目数</h3>
        <div class="value">{{ overview.total_projects }}</div>
      </div>
      <div class="card">
        <h3>总工作包</h3>
        <div class="value">{{ overview.total_work_packages }}</div>
      </div>
      <div class="card">
        <h3>完成率</h3>
        <div class="value">{{ overview.completion_rate }}%</div>
      </div>
      <div class="card">
        <h3>逾期率</h3>
        <div class="value danger">{{ overview.overdue_rate }}%</div>
      </div>
      <div class="card">
        <h3>总工时</h3>
        <div class="value">{{ timeTracking.total_hours }}h</div>
      </div>
      <div class="card">
        <h3>活跃成员</h3>
        <div class="value">{{ overview.total_members }}</div>
      </div>
    </div>
    
    <!-- 图表区域 -->
    <div class="charts-grid">
      <!-- 工作包状态分布 -->
      <div class="chart-card">
        <h3>工作包状态分布</h3>
        <pie-chart :data="workPackageStats.by_status" />
      </div>
      
      <!-- 工作包类型分布 -->
      <div class="chart-card">
        <h3>工作包类型</h3>
        <bar-chart :data="workPackageStats.by_type" />
      </div>
      
      <!-- 工时统计 -->
      <div class="chart-card full-width">
        <h3>工时统计 (按用户)</h3>
        <bar-chart :data="timeTracking.by_user" horizontal />
      </div>
      
      <!-- 趋势分析 -->
      <div class="chart-card full-width">
        <h3>工作包创建与完成趋势</h3>
        <line-chart :data="trendsData" />
      </div>
      
      <!-- 资源负载 -->
      <div class="chart-card">
        <h3>资源负载</h3>
        <bar-chart :data="workload.by_user" />
      </div>
      
      <!-- 进度分析 -->
      <div class="chart-card">
        <h3>项目进度</h3>
        <div class="progress-stats">
          <div class="progress-item">
            <span class="label">正常进行</span>
            <span class="value on-track">{{ progress.projects_on_track }}</span>
          </div>
          <div class="progress-item">
            <span class="label">有风险</span>
            <span class="value at-risk">{{ progress.projects_at_risk }}</span>
          </div>
          <div class="progress-item">
            <span class="label">已延期</span>
            <span class="value delayed">{{ progress.projects_delayed }}</span>
          </div>
        </div>
      </div>
    </div>
    
    <!-- 详细数据表 -->
    <div class="data-tables">
      <div class="table-card">
        <h3>工作包按优先级</h3>
        <table class="data-table">
          <thead>
            <tr>
              <th>优先级</th>
              <th>数量</th>
              <th>占比</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in workPackageStats.by_priority" :key="item.priority">
              <td>{{ item.priority }}</td>
              <td>{{ item.count }}</td>
              <td>{{ calculatePercentage(item.count) }}%</td>
            </tr>
          </tbody>
        </table>
      </div>
      
      <div class="table-card">
        <h3>工时 Top 10 工作包</h3>
        <table class="data-table">
          <thead>
            <tr>
              <th>工作包</th>
              <th>工时</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in timeTracking.by_work_package.slice(0, 10)" :key="item.work_package">
              <td>{{ item.work_package }}</td>
              <td>{{ item.hours }}h</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script>
// 导入图表组件 (需要使用 chartkick 或类似库)
import PieChart from './charts/pie_chart.vue'
import BarChart from './charts/bar_chart.vue'
import LineChart from './charts/line_chart.vue'

export default {
  name: 'AnalyticsDashboard',
  components: {
    PieChart,
    BarChart,
    LineChart
  },
  data() {
    return {
      projectId: '',
      timeRange: '30',
      projects: [],
      overview: {},
      workPackageStats: {},
      timeTracking: {},
      progress: {},
      workload: {},
      trends: {},
      trendsData: []
    }
  },
  mounted() {
    this.loadProjects()
    this.loadAllData()
  },
  methods: {
    async loadProjects() {
      const response = await fetch('/api/v3/projects')
      const data = await response.json()
      this.projects = data
    },
    async loadAllData() {
      await Promise.all([
        this.loadOverview(),
        this.loadWorkPackageStats(),
        this.loadTimeTracking(),
        this.loadProgress(),
        this.loadWorkload(),
        this.loadTrends()
      ])
    },
    async loadOverview() {
      const url = this.projectId 
        ? `/analytics/api/overview?project_id=${this.projectId}`
        : '/analytics/api/overview'
      const response = await fetch(url)
      const data = await response.json()
      this.overview = data.data || {}
    },
    async loadWorkPackageStats() {
      const url = this.projectId 
        ? `/analytics/api/work_packages?project_id=${this.projectId}`
        : '/analytics/api/work_packages'
      const response = await fetch(url)
      const data = await response.json()
      this.workPackageStats = data.data || {}
    },
    async loadTimeTracking() {
      const url = this.projectId 
        ? `/analytics/api/time_tracking?project_id=${this.projectId}`
        : '/analytics/api/time_tracking'
      const response = await fetch(url)
      const data = await response.json()
      this.timeTracking = data.data || {}
    },
    async loadProgress() {
      const url = this.projectId 
        ? `/analytics/api/progress?project_id=${this.projectId}`
        : '/analytics/api/progress'
      const response = await fetch(url)
      const data = await response.json()
      this.progress = data.data || {}
    },
    async loadWorkload() {
      const url = this.projectId 
        ? `/analytics/api/workload?project_id=${this.projectId}`
        : '/analytics/api/workload'
      const response = await fetch(url)
      const data = await response.json()
      this.workload = data.data || {}
    },
    async loadTrends() {
      const url = this.projectId 
        ? `/analytics/api/trends?project_id=${this.projectId}&days=${this.timeRange}`
        : `/analytics/api/trends?days=${this.timeRange}`
      const response = await fetch(url)
      const data = await response.json()
      this.trends = data.data || {}
      this.processTrendsData()
    },
    processTrendsData() {
      // 处理趋势数据用于图表显示
      const creation = this.trends.work_package_creation || []
      const completion = this.trends.work_package_completion || []
      
      this.trendsData = [
        { name: '创建', data: creation.map(i => [i.date, i.count]) },
        { name: '完成', data: completion.map(i => [i.date, i.count]) }
      ]
    },
    calculatePercentage(count) {
      const total = this.workPackageStats.by_priority?.reduce((sum, i) => sum + i.count, 0) || 0
      return total > 0 ? ((count / total) * 100).toFixed(1) : 0
    },
    async exportReport() {
      const format = prompt('导出格式 (pdf/excel/csv):', 'pdf')
      if (!format) return
      
      const url = `/analytics/api/export?format=${format}&project_id=${this.projectId || ''}`
      const response = await fetch(url)
      const data = await response.json()
      
      if (data.success) {
        alert('报表已生成：' + data.url)
        window.open(data.url, '_blank')
      } else {
        alert('导出失败：' + data.message)
      }
    }
  }
}
</script>

<style scoped>
.analytics-dashboard {
  padding: 20px;
  max-width: 1400px;
  margin: 0 auto;
}

.filters {
  display: flex;
  gap: 15px;
  margin-bottom: 30px;
  align-items: center;
}

.filters select {
  padding: 8px 12px;
  border: 1px solid #ddd;
  border-radius: 4px;
  min-width: 150px;
}

.btn-export {
  background: #28a745;
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 4px;
  cursor: pointer;
  margin-left: auto;
}

.overview-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 20px;
  margin-bottom: 30px;
}

.card {
  background: white;
  padding: 20px;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.card h3 {
  margin: 0 0 10px 0;
  font-size: 0.9em;
  color: #666;
}

.card .value {
  font-size: 2em;
  font-weight: bold;
  color: #333;
}

.card .value.danger {
  color: #dc3545;
}

.charts-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
  gap: 20px;
  margin-bottom: 30px;
}

.chart-card {
  background: white;
  padding: 20px;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.chart-card.full-width {
  grid-column: 1 / -1;
}

.chart-card h3 {
  margin: 0 0 20px 0;
  color: #333;
}

.data-tables {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(500px, 1fr));
  gap: 20px;
}

.table-card {
  background: white;
  padding: 20px;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.table-card h3 {
  margin: 0 0 15px 0;
  color: #333;
}

.data-table {
  width: 100%;
  border-collapse: collapse;
}

.data-table th, .data-table td {
  padding: 10px;
  text-align: left;
  border-bottom: 1px solid #eee;
}

.data-table th {
  background: #f8f9fa;
  font-weight: 600;
}

.progress-stats {
  display: flex;
  flex-direction: column;
  gap: 15px;
}

.progress-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px;
  background: #f8f9fa;
  border-radius: 4px;
}

.progress-item .label {
  color: #666;
}

.progress-item .value {
  font-weight: bold;
  padding: 4px 12px;
  border-radius: 4px;
}

.progress-item .value.on-track {
  background: #28a745;
  color: white;
}

.progress-item .value.at-risk {
  background: #ffc107;
  color: #333;
}

.progress-item .value.delayed {
  background: #dc3545;
  color: white;
}
</style>
