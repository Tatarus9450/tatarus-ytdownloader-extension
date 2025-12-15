"""
Tatarus YouTube Downloader - Backend Server
Flask API server using yt-dlp for video/audio downloading
"""

import os
import uuid
import threading
from flask import Flask, request, jsonify
from flask_cors import CORS
import yt_dlp

from config import (
    HOST, PORT, DEBUG,
    DOWNLOAD_FOLDER,
    VIDEO_QUALITY_LABELS,
    AUDIO_QUALITY_LABELS
)

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Store download tasks progress
download_tasks = {}


def get_quality_label(height):
    """Get human-readable quality label from video height"""
    height_str = str(height)
    return VIDEO_QUALITY_LABELS.get(height_str, f'{height}p')


def get_audio_quality_label(abr):
    """Get human-readable audio quality label from audio bitrate"""
    abr_str = str(int(abr)) if abr else '128'
    return AUDIO_QUALITY_LABELS.get(abr_str, f'{abr_str} kbps')


@app.route('/api/info', methods=['GET'])
def get_video_info():
    """
    Get video information including available qualities
    Query params:
        - url: YouTube video URL
    """
    url = request.args.get('url')
    
    if not url:
        return jsonify({'error': 'URL is required'}), 400
    
    try:
        ydl_opts = {
            'quiet': True,
            'no_warnings': True,
            'extract_flat': False,
        }
        
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
        
        # Extract video qualities
        video_qualities = []
        audio_qualities = []
        seen_heights = set()
        seen_abrs = set()
        
        formats = info.get('formats', [])
        
        for fmt in formats:
            # Video formats
            if fmt.get('vcodec') != 'none' and fmt.get('height'):
                height = fmt.get('height')
                if height and height not in seen_heights:
                    seen_heights.add(height)
                    video_qualities.append({
                        'format_id': f'bestvideo[height<={height}]+bestaudio/best[height<={height}]',
                        'height': height,
                        'label': get_quality_label(height)
                    })
            
            # Audio formats
            if fmt.get('acodec') != 'none' and fmt.get('vcodec') == 'none':
                abr = fmt.get('abr')
                if abr and int(abr) not in seen_abrs:
                    seen_abrs.add(int(abr))
                    audio_qualities.append({
                        'format_id': f'bestaudio[abr<={int(abr)}]',
                        'abr': int(abr),
                        'label': get_audio_quality_label(abr)
                    })
        
        # Sort by quality (highest first)
        video_qualities.sort(key=lambda x: x['height'], reverse=True)
        audio_qualities.sort(key=lambda x: x['abr'], reverse=True)
        
        # If no specific qualities found, add defaults
        if not video_qualities:
            video_qualities = [
                {'format_id': 'bestvideo+bestaudio/best', 'height': 1080, 'label': 'Best Available'},
                {'format_id': 'best[height<=720]', 'height': 720, 'label': 'HD (720p)'},
                {'format_id': 'best[height<=480]', 'height': 480, 'label': 'SD (480p)'},
            ]
        
        if not audio_qualities:
            audio_qualities = [
                {'format_id': 'bestaudio/best', 'abr': 320, 'label': 'Best Available'},
                {'format_id': 'bestaudio[abr<=192]', 'abr': 192, 'label': '192 kbps'},
                {'format_id': 'bestaudio[abr<=128]', 'abr': 128, 'label': '128 kbps'},
            ]
        
        response = {
            'title': info.get('title', 'Unknown'),
            'channel': info.get('uploader', info.get('channel', 'Unknown')),
            'duration': info.get('duration', 0),
            'thumbnail': info.get('thumbnail', ''),
            'video_qualities': video_qualities,
            'audio_qualities': audio_qualities
        }
        
        return jsonify(response)
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/download', methods=['POST'])
def download_video():
    """
    Start downloading a video/audio
    Request body:
        - url: YouTube video URL
        - format: 'mp4' or 'mp3'
        - quality: format_id string
    """
    data = request.get_json()
    
    if not data:
        return jsonify({'error': 'Request body is required'}), 400
    
    url = data.get('url')
    format_type = data.get('format', 'mp4')
    quality = data.get('quality', 'best')
    
    if not url:
        return jsonify({'error': 'URL is required'}), 400
    
    # Generate task ID
    task_id = str(uuid.uuid4())
    download_tasks[task_id] = {
        'status': 'starting',
        'progress': 0,
        'filename': None,
        'error': None
    }
    
    # Start download in background thread
    thread = threading.Thread(
        target=download_worker,
        args=(task_id, url, format_type, quality)
    )
    thread.daemon = True
    thread.start()
    
    return jsonify({
        'success': True,
        'task_id': task_id,
        'message': 'Download started'
    })


def progress_hook(task_id):
    """Create a progress hook function for yt-dlp"""
    def hook(d):
        if d['status'] == 'downloading':
            total = d.get('total_bytes') or d.get('total_bytes_estimate', 0)
            downloaded = d.get('downloaded_bytes', 0)
            if total > 0:
                progress = (downloaded / total) * 100
                download_tasks[task_id]['progress'] = progress
                download_tasks[task_id]['status'] = 'downloading'
        
        elif d['status'] == 'finished':
            download_tasks[task_id]['progress'] = 100
            download_tasks[task_id]['status'] = 'processing'
            download_tasks[task_id]['filename'] = d.get('filename', '')
    
    return hook


def download_worker(task_id, url, format_type, quality):
    """Background worker for downloading video/audio"""
    try:
        # Configure yt-dlp options
        if format_type == 'mp3':
            ydl_opts = {
                'format': quality if 'bestaudio' in quality else 'bestaudio/best',
                'outtmpl': os.path.join(DOWNLOAD_FOLDER, '%(title)s.%(ext)s'),
                'postprocessors': [{
                    'key': 'FFmpegExtractAudio',
                    'preferredcodec': 'mp3',
                    'preferredquality': '320',
                }],
                'progress_hooks': [progress_hook(task_id)],
                'quiet': True,
                'no_warnings': True,
            }
        else:  # mp4
            ydl_opts = {
                'format': quality if quality != 'best' else 'bestvideo+bestaudio/best',
                'outtmpl': os.path.join(DOWNLOAD_FOLDER, '%(title)s.%(ext)s'),
                'merge_output_format': 'mp4',
                'progress_hooks': [progress_hook(task_id)],
                'quiet': True,
                'no_warnings': True,
            }
        
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)
            
            # Get final filename
            if format_type == 'mp3':
                filename = ydl.prepare_filename(info)
                filename = os.path.splitext(filename)[0] + '.mp3'
            else:
                filename = ydl.prepare_filename(info)
            
            download_tasks[task_id]['status'] = 'completed'
            download_tasks[task_id]['progress'] = 100
            download_tasks[task_id]['filename'] = os.path.basename(filename)
    
    except Exception as e:
        download_tasks[task_id]['status'] = 'error'
        download_tasks[task_id]['error'] = str(e)


@app.route('/api/progress/<task_id>', methods=['GET'])
def get_progress(task_id):
    """Get download progress for a task"""
    if task_id not in download_tasks:
        return jsonify({'error': 'Task not found'}), 404
    
    task = download_tasks[task_id]
    return jsonify({
        'status': task['status'],
        'progress': task['progress'],
        'filename': task['filename'],
        'error': task['error']
    })


@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'ok',
        'download_folder': DOWNLOAD_FOLDER
    })


if __name__ == '__main__':
    print(f"""
╔═══════════════════════════════════════════════════════════╗
║     Tatarus YouTube Downloader - Backend Server           ║
╠═══════════════════════════════════════════════════════════╣
║  Server running at: http://{HOST}:{PORT}                    ║
║  Download folder:   {DOWNLOAD_FOLDER[:35]}...  ║
║                                                           ║
║  Endpoints:                                               ║
║    GET  /api/info?url=...     - Get video info            ║
║    POST /api/download         - Start download            ║
║    GET  /api/progress/<id>    - Get download progress     ║
║    GET  /api/health           - Health check              ║
╚═══════════════════════════════════════════════════════════╝
    """)
    app.run(host=HOST, port=PORT, debug=DEBUG)
