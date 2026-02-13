/**
 * Tatarus YouTube Downloader - Popup Script
 * Handles UI interactions and communication with backend server
 * Supports single video and playlist downloads
 */

// Configuration
const API_BASE_URL = 'http://localhost:4321/api';
const SERVER_CHECK_TIMEOUT = 3000;

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

  playlistSection: document.getElementById('playlist-section'),
  playlistInfo: document.getElementById('playlist-info'),
  playlistCount: document.getElementById('playlist-count'),
  playlistModeRadios: document.querySelectorAll('input[name="playlist-mode"]'),

  formatRadios: document.querySelectorAll('input[name="format"]'),
  qualitySelect: document.getElementById('quality-select'),
  downloadBtn: document.getElementById('download-btn'),

  progressContainer: document.getElementById('progress-container'),
  progressFill: document.getElementById('progress-fill'),
  progressPercent: document.getElementById('progress-percent'),
  progressLabel: document.querySelector('.progress-label'),
  progressPlaylistTitle: document.getElementById('progress-playlist-title'),
  progressCurrentTitle: document.getElementById('progress-current-title'),
  cancelBtn: document.getElementById('cancel-btn'),

  statusContainer: document.getElementById('status-container'),
  statusMessage: document.getElementById('status-message')
};

// State
let currentVideoInfo = null;
let currentFormat = 'mp4';
let isDownloading = false;
let isPlaylist = false;
let downloadPlaylistMode = false;

// Initialize
document.addEventListener('DOMContentLoaded', init);

async function init() {
  setupEventListeners();

  // Check if there's an active download in progress
  const activeDownload = await checkActiveDownload();
  if (activeDownload) {
    await resumeDownloadProgress(activeDownload);
  }

  await checkServerAndLoad();
}

// Wake up server if sleeping, then load video info
async function checkServerAndLoad() {
  showLoading();

  try {
    const serverStatus = await checkServerStatus();

    if (!serverStatus.running) {
      showServerNotRunningError();
      return;
    }

    if (serverStatus.state === 'sleeping') {
      await wakeupServer();
    }

    await loadVideoInfo();

  } catch (error) {
    console.error('Init error:', error);
    showServerNotRunningError();
  }
}

// Check server status
async function checkServerStatus() {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), SERVER_CHECK_TIMEOUT);

    const response = await fetch(`${API_BASE_URL}/status`, {
      method: 'GET',
      signal: controller.signal
    });

    clearTimeout(timeoutId);

    if (response.ok) {
      const data = await response.json();
      return { running: true, state: data.state };
    }
    return { running: false, state: null };

  } catch (error) {
    return { running: false, state: null };
  }
}

// Wake up the server
async function wakeupServer() {
  try {
    const response = await fetch(`${API_BASE_URL}/wakeup`, { method: 'GET' });
    if (response.ok) {
      console.log('⚡ Server woken up!');
    }
  } catch (error) {
    console.error('Failed to wake server:', error);
  }
}

// Show server not running error with instructions
function showServerNotRunningError() {
  const isWindows = navigator.platform.toLowerCase().includes('win');
  const installer = isWindows ? 'install.bat' : './install.sh';

  const errorHtml = `
    <div style="text-align: center; max-width: 260px; margin: 0 auto;">
      <div style="color: #ff6b6b; font-weight: 600; font-size: 13px; margin-bottom: 8px;">
        ⚠️ Server Not Running
      </div>
      <div style="background: #1a2e1a; padding: 10px; border-radius: 6px; border: 1px solid #2d4a2d; text-align: left;">
        <div style="color: #4ade80; font-size: 10px; font-weight: 600; margin-bottom: 6px; text-align: center;">
          🚀 Run Installer (First time only)
        </div>
        <div style="color: #888; font-size: 10px; line-height: 1.4;">
          <div style="margin-bottom: 2px;">1. Open project folder</div>
          <div style="margin-bottom: 2px;">2. ${isWindows ? 'Double-click' : 'Run:'} <code style="color: #4ade80;">${installer}</code></div>
          <div>3. Reload this extension</div>
        </div>
      </div>
      <div style="color: #444; font-size: 8px; margin-top: 5px;">
        ✨ After install, server starts automatically
      </div>
    </div>
  `;

  const errorIcon = document.querySelector('.error-icon');
  const errorTitle = document.querySelector('.error-title');
  if (errorIcon) errorIcon.style.display = 'none';
  if (errorTitle) errorTitle.style.display = 'none';

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
  elements.retryBtn.addEventListener('click', () => checkServerAndLoad());

  // Playlist mode listener
  elements.playlistModeRadios.forEach(radio => {
    radio.addEventListener('change', (e) => {
      downloadPlaylistMode = e.target.value === 'playlist';
    });
  });

  // Cancel button listener
  if (elements.cancelBtn) {
    elements.cancelBtn.addEventListener('click', handleCancelDownload);
  }
}

// Get current YouTube URL from active tab
async function getCurrentTabUrl() {
  return new Promise((resolve, reject) => {
    chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
      if (tabs[0] && tabs[0].url) {
        resolve(tabs[0].url);
      } else {
        reject(new Error('Cannot get URL from current tab'));
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
      throw new Error('Please open a YouTube video and try again');
    }

    const response = await fetch(`${API_BASE_URL}/info?url=${encodeURIComponent(url)}`, {
      signal: AbortSignal.timeout(30000)
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error || 'Failed to get video information');
    }

    const data = await response.json();

    if (data.error) {
      throw new Error(data.error);
    }

    currentVideoInfo = data;
    isPlaylist = data.is_playlist || false;

    displayVideoInfo(data);
    displayPlaylistInfo(data);
    populateQualityOptions(data);
    showContent();

  } catch (error) {
    console.error('Error loading video info:', error);
    if (error.name === 'TimeoutError') {
      showError('⏱️ Server response timeout');
    } else {
      showError(error.message);
    }
  }
}

// Display video information
function displayVideoInfo(info) {
  elements.thumbnail.src = info.thumbnail || '';
  elements.thumbnail.alt = info.title || 'Video Thumbnail';
  elements.videoTitle.textContent = info.title || 'Unknown Title';
  elements.videoChannel.textContent = info.channel || 'Unknown Channel';
  elements.duration.textContent = formatDuration(info.duration || 0);
}

// Display playlist information
function displayPlaylistInfo(info) {
  if (info.is_playlist && info.playlist_count > 0) {
    elements.playlistSection.classList.remove('hidden');
    elements.playlistInfo.textContent = `${info.playlist_title} (${info.playlist_count} videos)`;
    elements.playlistCount.textContent = info.playlist_count;
  } else {
    elements.playlistSection.classList.add('hidden');
  }
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
    option.textContent = 'No quality available';
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

// Get cookies for the current URL
async function getCookies(url) {
  if (!chrome.cookies) return [];

  try {
    const urlObj = new URL(url);
    const domain = urlObj.hostname;

    // Get cookies for the domain
    const cookies = await new Promise((resolve) => {
      chrome.cookies.getAll({ domain: domain }, resolve);
    });

    return cookies;
  } catch (error) {
    console.error('Error getting cookies:', error);
    return [];
  }
}

// Handle download
async function handleDownload() {
  if (isDownloading || !currentVideoInfo) return;

  const selectedQuality = elements.qualitySelect.value;
  if (!selectedQuality) {
    showStatus('Please select a quality first', 'warning');
    return;
  }

  isDownloading = true;
  elements.downloadBtn.disabled = true;
  showProgress();

  try {
    const url = await getCurrentTabUrl();
    const cookies = await getCookies(url);

    const response = await fetch(`${API_BASE_URL}/download`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        url: url,
        format: currentFormat,
        quality: selectedQuality,
        download_playlist: isPlaylist && downloadPlaylistMode,
        cookies: cookies
      })
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error || 'Download failed');
    }

    const data = await response.json();
    if (data.task_id) {
      // Save task_id for cancel and resume functionality
      currentTaskId = data.task_id;
      await saveActiveDownload(data.task_id);
      await pollDownloadProgress(data.task_id);
    }

  } catch (error) {
    console.error('Download error:', error);
    showStatus(error.message, 'error');
  } finally {
    isDownloading = false;
    elements.downloadBtn.disabled = false;
    await clearActiveDownload();
    setTimeout(hideProgress, 2000);
  }
}

// Poll download progress
async function pollDownloadProgress(taskId) {
  const maxAttempts = 1800; // 15 minutes for playlist
  let attempts = 0;

  while (attempts < maxAttempts) {
    try {
      const response = await fetch(`${API_BASE_URL}/progress/${taskId}`);
      const data = await response.json();

      // Update progress info
      if (data.progress !== undefined) {
        setProgress(data.progress);
      }

      // Update playlist and current song titles
      if (data.is_playlist) {
        if (data.playlist_title && elements.progressPlaylistTitle) {
          elements.progressPlaylistTitle.textContent = `📋 ${data.playlist_title}`;
        }
        if (data.current_title && elements.progressCurrentTitle) {
          elements.progressCurrentTitle.textContent = `🎵 ${data.current_title}`;
        }
        if (data.current && data.total && elements.progressLabel) {
          elements.progressLabel.textContent = `Downloading ${data.current}/${data.total}...`;
        }
      }

      if (data.status === 'completed') {
        setProgress(100);
        showStatus(`✅ Download complete! ${data.filename || 'Files saved to Downloads'}`, 'success');
        return;
      }

      if (data.status === 'error') {
        throw new Error(data.error || 'Download failed');
      }

      if (data.status === 'cancelled') {
        showStatus(`⚠️ Download cancelled`, 'warning');
        return;
      }

      await sleep(500);
      attempts++;

    } catch (error) {
      throw error;
    }
  }

  throw new Error('Download timeout');
}

// Handle cancel download
let currentTaskId = null;

async function handleCancelDownload() {
  if (!currentTaskId) return;

  try {
    const response = await fetch(`${API_BASE_URL}/cancel/${currentTaskId}`, {
      method: 'POST'
    });

    if (response.ok) {
      showStatus('⚠️ Cancelling download...', 'warning');
    }
  } catch (error) {
    console.error('Failed to cancel:', error);
  }
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

  // Show error icon and title for regular errors
  const errorIcon = document.querySelector('.error-icon');
  const errorTitle = document.querySelector('.error-title');
  if (errorIcon) errorIcon.style.display = '';
  if (errorTitle) errorTitle.style.display = '';
}

function showContent() {
  elements.loading.classList.add('hidden');
  elements.error.classList.add('hidden');
  elements.content.classList.remove('hidden');
}

function showProgress() {
  elements.progressContainer.classList.remove('hidden');
  if (elements.progressLabel) {
    elements.progressLabel.textContent = 'Downloading...';
  }
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
  setTimeout(() => elements.statusContainer.classList.add('hidden'), 5000);
}

// =============================================================================
// Download State Persistence
// =============================================================================

// Save active download to storage
function saveActiveDownload(taskId) {
  return new Promise((resolve) => {
    chrome.storage.local.set({ activeDownload: { taskId, startTime: Date.now() } }, resolve);
  });
}

// Clear active download from storage
function clearActiveDownload() {
  return new Promise((resolve) => {
    chrome.storage.local.remove(['activeDownload'], resolve);
  });
}

// Check if there's an active download
function checkActiveDownload() {
  return new Promise((resolve) => {
    chrome.storage.local.get(['activeDownload'], (result) => {
      if (result.activeDownload) {
        // Check if download is less than 30 minutes old
        const age = Date.now() - result.activeDownload.startTime;
        if (age < 30 * 60 * 1000) {
          resolve(result.activeDownload.taskId);
        } else {
          clearActiveDownload();
          resolve(null);
        }
      } else {
        resolve(null);
      }
    });
  });
}

// Resume download progress from saved task_id
async function resumeDownloadProgress(taskId) {
  try {
    // First hide loading spinner
    elements.loading.classList.add('hidden');
    elements.error.classList.add('hidden');

    const response = await fetch(`${API_BASE_URL}/progress/${taskId}`);
    const data = await response.json();

    if (data.status === 'completed') {
      showStatus(`✅ Download complete! ${data.filename || 'Files saved'}`, 'success');
      await clearActiveDownload();
      return;
    }

    if (data.status === 'error') {
      showStatus(`❌ ${data.error || 'Download failed'}`, 'error');
      await clearActiveDownload();
      return;
    }

    // Still downloading - show dedicated progress UI
    if (data.status === 'downloading' || data.status === 'starting' || data.status === 'processing') {
      isDownloading = true;

      // Show content but hide video card and options
      elements.content.classList.remove('hidden');

      // Hide video card and options while resuming
      const videoCard = document.querySelector('.video-card');
      const formatSection = document.querySelector('.format-section');
      const qualitySection = document.querySelector('.quality-section');
      const playlistSection = elements.playlistSection;

      if (videoCard) videoCard.style.display = 'none';
      if (formatSection) formatSection.style.display = 'none';
      if (qualitySection) qualitySection.style.display = 'none';
      if (playlistSection) playlistSection.style.display = 'none';

      elements.downloadBtn.style.display = 'none';
      showProgress();

      // Update progress label
      if (data.is_playlist && data.current && data.total) {
        if (elements.progressLabel) {
          elements.progressLabel.textContent = `Downloading ${data.current}/${data.total}...`;
        }
      } else {
        if (elements.progressLabel) {
          elements.progressLabel.textContent = 'Resuming download...';
        }
      }

      setProgress(data.progress || 0);

      // Poll progress until complete
      await pollDownloadProgress(taskId);

      // Restore UI after download completes
      if (videoCard) videoCard.style.display = '';
      if (formatSection) formatSection.style.display = '';
      if (qualitySection) qualitySection.style.display = '';
      if (playlistSection) playlistSection.style.display = '';
      elements.downloadBtn.style.display = '';

      isDownloading = false;
      elements.downloadBtn.disabled = false;
      await clearActiveDownload();
    }
  } catch (error) {
    console.error('Failed to resume download:', error);
    await clearActiveDownload();
  }
}
