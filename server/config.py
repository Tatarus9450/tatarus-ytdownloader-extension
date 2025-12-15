"""
Configuration for Tatarus YouTube Downloader Server
"""

import os
from pathlib import Path

# Server Configuration
HOST = '127.0.0.1'
PORT = 5000
DEBUG = True

# Download Configuration
# Default download folder - uses user's Downloads folder
DOWNLOAD_FOLDER = os.path.join(Path.home(), 'Downloads')

# Create download folder if it doesn't exist
os.makedirs(DOWNLOAD_FOLDER, exist_ok=True)

# yt-dlp Default Options
YTDLP_OPTIONS = {
    'quiet': True,
    'no_warnings': True,
    'extract_flat': False,
}

# Video Quality Presets (format_id -> label)
VIDEO_QUALITY_LABELS = {
    '2160': '4K (2160p)',
    '1440': '2K (1440p)',
    '1080': 'Full HD (1080p)',
    '720': 'HD (720p)',
    '480': 'SD (480p)',
    '360': 'Low (360p)',
    '240': 'Very Low (240p)',
    '144': 'Lowest (144p)',
}

# Audio Quality Presets (kbps)
AUDIO_QUALITY_LABELS = {
    '320': '320 kbps (Best)',
    '256': '256 kbps (High)',
    '192': '192 kbps (Medium)',
    '128': '128 kbps (Standard)',
    '96': '96 kbps (Low)',
    '64': '64 kbps (Very Low)',
}
