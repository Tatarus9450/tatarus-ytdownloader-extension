/**
 * Tatarus YouTube Downloader - Popup Script
 * Handles UI interactions and communication with backend server
 * Server auto-shutdowns after 10 minutes of inactivity
 */

// Configuration
const API_BASE_URL = 'http://localhost:5000/api';
const SERVER_CHECK_TIMEOUT = 3000; // 3 seconds

// DOM Elements
const elements = {
  loading: document.getElementById('loading'),
  error: document.getElementById('error'),
  content: document.getElementById('content'),
  errorMessage: document.getElementById('error-message'),
  retryBtn: document.getElementById('retry-btn'),

  thumbnail: document.getElementById('thumbnail'),
  duration: document.getElementById('duration'),
  videoTitle: document.getElementById('video-title'),
  videoChannel: document.getElementById('video-channel'),

  formatRadios: document.querySelectorAll('input[name="format"]'),
  qualitySelect: document.getElementById('quality-select'),
  downloadBtn: document.getElementById('download-btn'),

  progressContainer: document.getElementById('progress-container'),
  progressFill: document.getElementById('progress-fill'),
  progressPercent: document.getElementById('progress-percent'),

  statusContainer: document.getElementById('status-container'),
  statusMessage: document.getElementById('status-message')
};

// State
let currentVideoInfo = null;
let currentFormat = 'mp4';
let isDownloading = false;

// Initialize
document.addEventListener('DOMContentLoaded', init);

async function init() {
  setupEventListeners();
  await checkServerAndLoad();
}

// Check if server is running, show instructions if not
async function checkServerAndLoad() {
  showLoading();

  try {
    // Check server health
    const isServerRunning = await checkServerHealth();

    if (!isServerRunning) {
      showServerNotRunningError();
      return;
    }

    // Server is running, load video info
    await loadVideoInfo();

  } catch (error) {
    console.error('Init error:', error);
    showServerNotRunningError();
  }
}

// Check if server is running
async function checkServerHealth() {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), SERVER_CHECK_TIMEOUT);

    const response = await fetch(`${API_BASE_URL}/health`, {
      method: 'GET',
      signal: controller.signal
    });

    clearTimeout(timeoutId);
    return response.ok;

  } catch (error) {
    return false;
  }
}

// Show server not running error with instructions
function showServerNotRunningError() {
  const platform = navigator.platform.toLowerCase();
  let command = '';

  if (platform.includes('win')) {
    command = 'cd server && python app.py';
  } else {
    command = 'cd server && python3 app.py';
  }

  const errorHtml = `
    <div style="text-align: left; font-size: 12px;">
      <div style="color: #ff6b6b; font-weight: bold; margin-bottom: 8px;">
        🔴 Backend Server ไม่ได้รัน!
      </div>
      <div style="color: #888; margin-bottom: 12px;">
        กรุณารันคำสั่งนี้ใน Terminal:
      </div>
      <div style="background: #1a1a1a; padding: 10px; border-radius: 6px; font-family: monospace; margin-bottom: 12px; word-break: break-all;">
        ${command}
      </div>
      <div style="color: #666; font-size: 11px;">
        💡 Server จะปิดอัตโนมัติหลังไม่ได้ใช้งาน 10 นาที
      </div>
    </div>
  `;

  elements.loading.classList.add('hidden');
  elements.content.classList.add('hidden');
  elements.error.classList.remove('hidden');
  elements.errorMessage.innerHTML = errorHtml;
}

// Event Listeners
function setupEventListeners() {
  elements.formatRadios.forEach(radio => {
    radio.addEventListener('change', handleFormatChange);
  });

  elements.downloadBtn.addEventListener('click', handleDownload);

  elements.retryBtn.addEventListener('click', () => {
    checkServerAndLoad();
  });
}

// Get current YouTube URL from active tab
async function getCurrentTabUrl() {
  return new Promise((resolve, reject) => {
    chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
      if (tabs[0] && tabs[0].url) {
        resolve(tabs[0].url);
      } else {
        reject(new Error('ไม่สามารถดึง URL ของแท็บปัจจุบันได้'));
      }
    });
  });
}

// Validate YouTube URL
function isValidYouTubeUrl(url) {
  const patterns = [
    /^https?:\/\/(www\.)?youtube\.com\/watch\?v=[\w-]+/,
    /^https?:\/\/youtu\.be\/[\w-]+/,
    /^https?:\/\/(www\.)?youtube\.com\/shorts\/[\w-]+/
  ];
  return patterns.some(pattern => pattern.test(url));
}

// Load video information
async function loadVideoInfo() {
  try {
    const url = await getCurrentTabUrl();

    if (!isValidYouTubeUrl(url)) {
      throw new Error('กรุณาเปิดหน้าวิดีโอ YouTube แล้วลองใหม่อีกครั้ง');
    }

    const response = await fetch(`${API_BASE_URL}/info?url=${encodeURIComponent(url)}`, {
      signal: AbortSignal.timeout(30000)
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error || 'ไม่สามารถดึงข้อมูลวิดีโอได้');
    }

    const data = await response.json();

    if (data.error) {
      throw new Error(data.error);
    }

    currentVideoInfo = data;
    displayVideoInfo(data);
    populateQualityOptions(data);
    showContent();

  } catch (error) {
    console.error('Error loading video info:', error);

    if (error.name === 'TimeoutError') {
      showError('⏱️ หมดเวลารอการตอบกลับจาก Server');
    } else {
      showError(error.message);
    }
  }
}

// Display video information
function displayVideoInfo(info) {
  elements.thumbnail.src = info.thumbnail || '';
  elements.thumbnail.alt = info.title || 'Video Thumbnail';
  elements.videoTitle.textContent = info.title || 'ไม่ทราบชื่อ';
  elements.videoChannel.textContent = info.channel || 'ไม่ทราบช่อง';
  elements.duration.textContent = formatDuration(info.duration || 0);
}

// Format duration
function formatDuration(seconds) {
  const hrs = Math.floor(seconds / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  const secs = Math.floor(seconds % 60);

  if (hrs > 0) {
    return `${hrs}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }
  return `${mins}:${secs.toString().padStart(2, '0')}`;
}

// Populate quality dropdown
function populateQualityOptions(info) {
  elements.qualitySelect.innerHTML = '';

  const qualities = currentFormat === 'mp4' ? info.video_qualities : info.audio_qualities;

  if (!qualities || qualities.length === 0) {
    const option = document.createElement('option');
    option.value = '';
    option.textContent = 'ไม่มีคุณภาพที่รองรับ';
    elements.qualitySelect.appendChild(option);
    return;
  }

  qualities.forEach((quality, index) => {
    const option = document.createElement('option');
    option.value = quality.format_id;
    option.textContent = quality.label;
    if (index === 0) option.selected = true;
    elements.qualitySelect.appendChild(option);
  });
}

// Handle format change
function handleFormatChange(event) {
  currentFormat = event.target.value;
  if (currentVideoInfo) {
    populateQualityOptions(currentVideoInfo);
  }
}

// Handle download
async function handleDownload() {
  if (isDownloading || !currentVideoInfo) return;

  const selectedQuality = elements.qualitySelect.value;
  if (!selectedQuality) {
    showStatus('กรุณาเลือกคุณภาพก่อนดาวน์โหลด', 'warning');
    return;
  }

  isDownloading = true;
  elements.downloadBtn.disabled = true;
  showProgress();

  try {
    const url = await getCurrentTabUrl();

    const response = await fetch(`${API_BASE_URL}/download`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        url: url,
        format: currentFormat,
        quality: selectedQuality
      })
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error || 'ดาวน์โหลดไม่สำเร็จ');
    }

    const data = await response.json();

    if (data.task_id) {
      await pollDownloadProgress(data.task_id);
    }

  } catch (error) {
    console.error('Download error:', error);
    showStatus(error.message, 'error');
  } finally {
    isDownloading = false;
    elements.downloadBtn.disabled = false;
    setTimeout(hideProgress, 2000);
  }
}

// Poll download progress
async function pollDownloadProgress(taskId) {
  const maxAttempts = 600;
  let attempts = 0;

  while (attempts < maxAttempts) {
    try {
      const response = await fetch(`${API_BASE_URL}/progress/${taskId}`);
      const data = await response.json();

      if (data.progress !== undefined) {
        setProgress(data.progress);
      }

      if (data.status === 'completed') {
        setProgress(100);
        showStatus(`✅ ดาวน์โหลดสำเร็จ! ไฟล์: ${data.filename || 'Downloads'}`, 'success');
        return;
      }

      if (data.status === 'error') {
        throw new Error(data.error || 'ดาวน์โหลดไม่สำเร็จ');
      }

      await sleep(500);
      attempts++;

    } catch (error) {
      throw error;
    }
  }

  throw new Error('หมดเวลาดาวน์โหลด');
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// UI State Management
function showLoading() {
  elements.loading.classList.remove('hidden');
  elements.error.classList.add('hidden');
  elements.content.classList.add('hidden');
}

function showError(message) {
  elements.loading.classList.add('hidden');
  elements.error.classList.remove('hidden');
  elements.content.classList.add('hidden');
  elements.errorMessage.textContent = message;
}

function showContent() {
  elements.loading.classList.add('hidden');
  elements.error.classList.add('hidden');
  elements.content.classList.remove('hidden');
}

function showProgress() {
  elements.progressContainer.classList.remove('hidden');
  setProgress(0);
}

function hideProgress() {
  elements.progressContainer.classList.add('hidden');
}

function setProgress(percent) {
  elements.progressFill.style.width = `${percent}%`;
  elements.progressPercent.textContent = `${Math.round(percent)}%`;
}

function showStatus(message, type = 'success') {
  elements.statusContainer.classList.remove('hidden', 'success', 'error', 'warning');
  elements.statusContainer.classList.add(type);
  elements.statusMessage.textContent = message;

  setTimeout(() => {
    elements.statusContainer.classList.add('hidden');
  }, 5000);
}
