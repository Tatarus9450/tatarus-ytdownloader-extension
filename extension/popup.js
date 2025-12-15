/**
 * Tatarus YouTube Downloader - Popup Script
 * Handles UI interactions and communication with backend server
 */

// Configuration
const API_BASE_URL = 'http://localhost:5000/api';

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
  await loadVideoInfo();
}

// Event Listeners
function setupEventListeners() {
  // Format change
  elements.formatRadios.forEach(radio => {
    radio.addEventListener('change', handleFormatChange);
  });

  // Download button
  elements.downloadBtn.addEventListener('click', handleDownload);

  // Retry button
  elements.retryBtn.addEventListener('click', () => {
    hideError();
    loadVideoInfo();
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
  showLoading();

  try {
    const url = await getCurrentTabUrl();

    if (!isValidYouTubeUrl(url)) {
      throw new Error('กรุณาเปิดหน้าวิดีโอ YouTube แล้วลองใหม่อีกครั้ง');
    }

    // First check if server is running
    try {
      const healthCheck = await fetch(`${API_BASE_URL}/health`, {
        method: 'GET',
        signal: AbortSignal.timeout(3000)
      });
      if (!healthCheck.ok) {
        throw new Error('Server health check failed');
      }
    } catch (healthError) {
      throw new Error('🔴 Backend Server ไม่ได้รัน!\n\nกรุณารันคำสั่ง:\ncd server && python3 server.py');
    }

    const response = await fetch(`${API_BASE_URL}/info?url=${encodeURIComponent(url)}`, {
      signal: AbortSignal.timeout(30000) // 30 second timeout
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error || 'ไม่สามารถดึงข้อมูลวิดีโอได้');
    }

    const data = await response.json();

    // Check if there was an error in the response
    if (data.error) {
      throw new Error(data.error);
    }

    currentVideoInfo = data;

    displayVideoInfo(data);
    populateQualityOptions(data);
    showContent();

  } catch (error) {
    console.error('Error loading video info:', error);
    let errorMessage = error.message;

    // Handle network errors
    if (error.name === 'TypeError' && error.message === 'Failed to fetch') {
      errorMessage = '🔴 ไม่สามารถเชื่อมต่อ Server ได้\n\nกรุณารันคำสั่ง:\ncd server && python3 server.py';
    } else if (error.name === 'TimeoutError') {
      errorMessage = '⏱️ หมดเวลารอการตอบกลับจาก Server';
    }

    showError(errorMessage);
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

// Format duration (seconds to MM:SS or HH:MM:SS)
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

    // Select best quality by default (first item)
    if (index === 0) {
      option.selected = true;
    }

    elements.qualitySelect.appendChild(option);
  });
}

// Handle format change (MP4/MP3)
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
      headers: {
        'Content-Type': 'application/json'
      },
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

    // Poll for progress
    const data = await response.json();

    if (data.task_id) {
      await pollDownloadProgress(data.task_id);
    } else if (data.success) {
      setProgress(100);
      showStatus(`ดาวน์โหลดสำเร็จ! บันทึกไว้ที่: ${data.filename}`, 'success');
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
  const pollInterval = 500; // ms
  const maxAttempts = 600; // 5 minutes max
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
        showStatus(`ดาวน์โหลดสำเร็จ! บันทึกไว้ที่: ${data.filename || 'Downloads folder'}`, 'success');
        return;
      }

      if (data.status === 'error') {
        throw new Error(data.error || 'ดาวน์โหลดไม่สำเร็จ');
      }

      await sleep(pollInterval);
      attempts++;

    } catch (error) {
      throw error;
    }
  }

  throw new Error('หมดเวลาดาวน์โหลด');
}

// Utility: Sleep
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

function hideError() {
  elements.error.classList.add('hidden');
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

  // Auto hide after 5 seconds
  setTimeout(() => {
    elements.statusContainer.classList.add('hidden');
  }, 5000);
}
