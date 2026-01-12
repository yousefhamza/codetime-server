import { Controller } from "@hotwired/stimulus"
import "chart.js/auto"

// Color palette for different languages
const COLORS = [
  '#3B82F6', // blue
  '#10B981', // emerald
  '#F59E0B', // amber
  '#EF4444', // red
  '#8B5CF6', // violet
  '#EC4899', // pink
  '#06B6D4', // cyan
  '#84CC16', // lime
]

export default class extends Controller {
  static values = {
    data: Array
  }

  connect() {
    this.renderChart()
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }

  renderChart() {
    const data = this.dataValue

    if (!data || data.length === 0) {
      this.element.innerHTML = '<p class="text-slate-400 text-center">No data available</p>'
      return
    }

    // Extract unique languages from all data points
    const languagesSet = new Set()
    data.forEach(entry => {
      Object.keys(entry.data || {}).forEach(lang => languagesSet.add(lang))
    })
    const languages = Array.from(languagesSet)

    // Prepare labels (dates)
    const labels = data.map(entry => {
      const date = new Date(entry.date)
      return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
    })

    // Create datasets for each language
    const datasets = languages.map((language, index) => {
      const color = COLORS[index % COLORS.length]
      return {
        label: language,
        data: data.map(entry => (entry.data && entry.data[language]) || 0),
        backgroundColor: this.hexToRgba(color, 0.6),
        borderColor: color,
        borderWidth: 2,
        fill: true,
        tension: 0.3,
        pointRadius: 3,
        pointHoverRadius: 5,
      }
    })

    // Create canvas element
    const canvas = document.createElement('canvas')
    this.element.innerHTML = ''
    this.element.appendChild(canvas)

    // Create the chart (Chart is available globally from chart.js/auto)
    this.chart = new window.Chart(canvas, {
      type: 'line',
      data: {
        labels: labels,
        datasets: datasets
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: 'index',
          intersect: false,
        },
        plugins: {
          legend: {
            position: 'bottom',
            labels: {
              usePointStyle: true,
              padding: 20,
              font: {
                size: 12
              }
            }
          },
          tooltip: {
            backgroundColor: 'rgba(15, 23, 42, 0.9)',
            titleColor: '#fff',
            bodyColor: '#fff',
            borderColor: 'rgba(255, 255, 255, 0.1)',
            borderWidth: 1,
            padding: 12,
            displayColors: true,
            callbacks: {
              label: function(context) {
                const value = context.parsed.y
                const hours = Math.floor(value / 60)
                const mins = value % 60
                if (hours > 0) {
                  return `${context.dataset.label}: ${hours}h ${mins}m`
                }
                return `${context.dataset.label}: ${mins}m`
              }
            }
          }
        },
        scales: {
          x: {
            grid: {
              display: false
            },
            ticks: {
              font: {
                size: 11
              },
              color: '#64748b'
            }
          },
          y: {
            stacked: true,
            beginAtZero: true,
            grid: {
              color: 'rgba(148, 163, 184, 0.1)'
            },
            ticks: {
              font: {
                size: 11
              },
              color: '#64748b',
              callback: function(value) {
                const hours = Math.floor(value / 60)
                const mins = value % 60
                if (hours > 0) {
                  return `${hours}h ${mins}m`
                }
                return `${mins}m`
              }
            },
            title: {
              display: true,
              text: 'Coding Time',
              color: '#64748b',
              font: {
                size: 12
              }
            }
          }
        }
      }
    })
  }

  hexToRgba(hex, alpha) {
    const r = parseInt(hex.slice(1, 3), 16)
    const g = parseInt(hex.slice(3, 5), 16)
    const b = parseInt(hex.slice(5, 7), 16)
    return `rgba(${r}, ${g}, ${b}, ${alpha})`
  }
}
