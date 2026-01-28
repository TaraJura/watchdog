import consumer from "channels/consumer"

const notificationsChannel = consumer.subscriptions.create("NotificationsChannel", {
  connected() {
    console.log("Connected to notifications channel")
    updateConnectionStatus(true)
  },

  disconnected() {
    console.log("Disconnected from notifications channel")
    updateConnectionStatus(false)
  },

  received(data) {
    console.log("Received:", data)

    if (data.type === 'new_car') {
      handleNewCar(data)
    }
  }
})

function updateConnectionStatus(connected) {
  const statusEl = document.getElementById('connection-status')
  const statusText = document.getElementById('status-text')
  if (statusEl) {
    statusEl.className = connected ? 'status-dot connected' : 'status-dot disconnected'
  }
  if (statusText) {
    const connectedText = statusText.dataset.connected || 'Connected'
    const disconnectedText = statusText.dataset.disconnected || 'Disconnected'
    statusText.textContent = connected ? connectedText : disconnectedText
  }
}

function handleNewCar(data) {
  const car = data.car
  const source = data.source

  // Show browser notification
  showBrowserNotification(car, source)

  // Show in-page notification
  showInPageNotification(car, source)

  // Update stats
  updateStats()

  // Add car to grid if on matching tab
  addCarToGrid(car, source)
}

function showBrowserNotification(car, source) {
  if (Notification.permission === 'granted') {
    const notification = new Notification(`New car on ${source.charAt(0).toUpperCase() + source.slice(1)}`, {
      body: `${car.title}\n${car.price || 'Price on request'}`,
      icon: car.image || '/favicon.ico',
      tag: car.url,
      requireInteraction: false
    })

    notification.onclick = () => {
      window.open(car.url, '_blank')
      notification.close()
    }

    // Auto close after 10 seconds
    setTimeout(() => notification.close(), 10000)
  }
}

function showInPageNotification(car, source) {
  const container = document.getElementById('notifications-container')
  if (!container) return

  const notification = document.createElement('div')
  notification.className = `notification notification-${source}`
  notification.innerHTML = `
    <div class="notification-content">
      <span class="notification-badge">${source.toUpperCase()}</span>
      <span class="notification-title">${escapeHtml(car.title)}</span>
      <span class="notification-price">${car.price || ''}</span>
    </div>
    <a href="${car.url}" target="_blank" class="notification-link">View →</a>
  `

  container.appendChild(notification)

  // Animate in
  setTimeout(() => notification.classList.add('show'), 10)

  // Remove after 8 seconds
  setTimeout(() => {
    notification.classList.remove('show')
    setTimeout(() => notification.remove(), 300)
  }, 8000)
}

function updateStats() {
  fetch('/stats')
    .then(response => response.json())
    .then(stats => {
      const bazosCount = document.querySelector('.tab.bazos .count')
      const sautoCount = document.querySelector('.tab.sauto .count')
      const bazosToday = document.querySelector('.tab.bazos .tab-today')
      const sautoToday = document.querySelector('.tab.sauto .tab-today')

      if (bazosCount) bazosCount.textContent = stats.bazos_total
      if (sautoCount) sautoCount.textContent = stats.sauto_total

      // Use data attribute for "today" translation, fallback to "today"
      const todayLabel = bazosToday?.dataset?.todayLabel || 'today'
      if (bazosToday) bazosToday.textContent = `+${stats.bazos_today} ${todayLabel}`
      if (sautoToday) sautoToday.textContent = `+${stats.sauto_today} ${todayLabel}`
    })
    .catch(err => console.error('Failed to update stats:', err))
}

function addCarToGrid(car, source) {
  const currentTab = new URLSearchParams(window.location.search).get('tab') || 'bazos'
  if (currentTab !== source) return

  const grid = document.querySelector('.car-grid')
  if (!grid) return

  const cardHtml = `
    <div class="car-card new-car">
      <a href="${car.url}" target="_blank" rel="noopener">
        ${car.image ?
          `<img src="${car.image}" alt="${escapeHtml(car.title)}" class="car-image" loading="lazy">` :
          `<div class="car-image-placeholder">🚗</div>`
        }
        <div class="car-content">
          <h3 class="car-title">${escapeHtml(car.title)}</h3>
          <div class="car-price">${car.price || 'Price on request'}</div>
          <div class="car-meta">
            ${car.locality ? `<span>📍 ${escapeHtml(car.locality)}</span>` : ''}
            <span>🕐 just now</span>
          </div>
        </div>
      </a>
    </div>
  `

  grid.insertAdjacentHTML('afterbegin', cardHtml)

  // Remove "new" highlight after animation
  setTimeout(() => {
    const newCard = grid.querySelector('.new-car')
    if (newCard) newCard.classList.remove('new-car')
  }, 3000)
}

function escapeHtml(text) {
  const div = document.createElement('div')
  div.textContent = text
  return div.innerHTML
}

// Request notification permission
function requestNotificationPermission() {
  if ('Notification' in window && Notification.permission === 'default') {
    Notification.requestPermission().then(updateNotificationUI)
  }
}

// Update notification permission UI
function updateNotificationUI() {
  const icon = document.getElementById('notification-icon')
  const text = document.getElementById('notification-text')
  const btn = document.getElementById('notification-btn')
  const container = document.getElementById('notification-status')

  if (!icon || !text || !btn || !container) return

  // Get translations from data attributes
  const enabledText = text.dataset.enabled || 'Enabled'
  const disabledText = text.dataset.disabled || 'Disabled'
  const defaultText = text.dataset.default || 'Pending'
  const enableBtnText = btn.textContent.trim() || 'Enable'

  if (!('Notification' in window)) {
    icon.textContent = '🔕'
    text.textContent = disabledText
    container.className = 'notification-permission notification-disabled'
    btn.style.display = 'none'
    return
  }

  const permission = Notification.permission

  if (permission === 'granted') {
    icon.textContent = '🔔'
    text.textContent = enabledText
    container.className = 'notification-permission notification-enabled'
    btn.style.display = 'none'
  } else if (permission === 'denied') {
    icon.textContent = '🔕'
    text.textContent = disabledText
    container.className = 'notification-permission notification-disabled'
    btn.style.display = 'none'
  } else {
    icon.textContent = '🔔'
    text.textContent = defaultText
    container.className = 'notification-permission notification-default'
    btn.style.display = 'inline-block'
  }
}

// Handle notification button click
function handleNotificationBtnClick() {
  if ('Notification' in window && Notification.permission === 'default') {
    Notification.requestPermission().then(updateNotificationUI)
  }
}

// Handle fetch button click
function handleFetchBtnClick() {
  const btn = document.getElementById('fetch-btn')
  const btnText = document.getElementById('fetch-btn-text')

  if (!btn || !btnText) return

  // Get translations from data attributes
  const startText = btn.dataset.start || 'Start Fetching'
  const fetchingText = btn.dataset.fetching || 'Fetching...'

  btn.disabled = true
  btn.classList.add('fetching')
  btnText.textContent = fetchingText

  fetch('/start_fetching', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
    }
  })
    .then(response => response.json())
    .then(data => {
      btnText.textContent = fetchingText
      btn.classList.remove('fetching')
      // Keep button disabled since jobs are now running
    })
    .catch(err => {
      console.error('Failed to start fetching:', err)
      btnText.textContent = startText
      btn.disabled = false
      btn.classList.remove('fetching')
    })
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
  // Update notification UI
  updateNotificationUI()

  // Bind notification button
  const notificationBtn = document.getElementById('notification-btn')
  if (notificationBtn) {
    notificationBtn.addEventListener('click', handleNotificationBtnClick)
  }

  // Bind fetch button
  const fetchBtn = document.getElementById('fetch-btn')
  if (fetchBtn) {
    fetchBtn.addEventListener('click', handleFetchBtnClick)
  }
})

export default notificationsChannel
