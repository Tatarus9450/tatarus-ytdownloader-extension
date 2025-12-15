"""
Tatarus YT Downloader - Backend Server
Flask API server using yt-dlp for video/audio downloading
Auto-shutdown after 10 minutes of inactivity
"""

import os
import uuid
import threading
import time
from flask import Flask, request, jsonify
from flask_cors import CORS
import yt_dlp

app = Flask(__name__)
CORS(app)

# Auto-shutdown configuration
IDLE_TIMEOUT = 600  # 10 minutes in seconds
last_activity_time = time.time()
shutdown_timer = None

# Download folder
DOWNLOAD_FOLDER = os.path.join(os.path.expanduser('~'), 'Downloads')
os.makedirs(DOWNLOAD_FOLDER, exist_ok=True)

# Download tasks
download_tasks = {}


def update_activity():
    """Update last activity timestamp"""
    global last_activity_time
    last_activity_time = time.time()


def check_idle_shutdown():
    """Check if server should shutdown due to inactivity"""
    global shutdown_timer
    while True:
        time.sleep(60)  # Check every minute
        idle_time = time.time() - last_activity_time
        if idle_time >= IDLE_TIMEOUT:
            print(f"\n⏰ Server idle for {IDLE_TIMEOUT//60} minutes. Shutting down...")
            os._exit(0)


def get_quality_label(height):
    labels = {
        2160: '4K (2160p)',
        1440: '2K (1440p)',
        1080: 'Full HD (1080p)',
        720: 'HD (720p)',
        480: 'SD (480p)',
        360: 'Low (360p)',
    }
    return labels.get(height, f'{height}p')


def get_audio_quality_label(abr):
    labels = {
        320: '320 kbps (Best)',
        256: '256 kbps',
        192: '192 kbps',
        128: '128 kbps',
    }
    return labels.get(int(abr) if abr else 128, f'{int(abr)} kbps')


@app.route('/api/health', methods=['GET'])
def health_check():
    update_activity()
    return jsonify({'status': 'ok', 'idle_timeout': IDLE_TIMEOUT})


@app.route('/api/info', methods=['GET'])
def get_video_info():
    update_activity()
    url = request.args.get('url')
    
    if not url:
        return jsonify({'error': 'URL is required'}), 400
    
    try:
        ydl_opts = {'quiet': True, 'no_warnings': True}
        
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
        
        video_qualities = []
        audio_qualities = []
        seen_heights = set()
        seen_abrs = set()
        
        for fmt in info.get('formats', []):
            if fmt.get('vcodec') != 'none' and fmt.get('height'):
                height = fmt['height']
                if height not in seen_heights:
                    seen_heights.add(height)
                    video_qualities.append({
                        'format_id': f'bestvideo[height<={height}]+bestaudio/best[height<={height}]',
                        'height': height,
                        'label': get_quality_label(height)
                    })
            
            if fmt.get('acodec') != 'none' and fmt.get('vcodec') == 'none':
                abr = fmt.get('abr')
                if abr and int(abr) not in seen_abrs:
                    seen_abrs.add(int(abr))
                    audio_qualities.append({
                        'format_id': f'bestaudio[abr<={int(abr)}]',
                        'abr': int(abr),
                        'label': get_audio_quality_label(abr)
                    })
        
        video_qualities.sort(key=lambda x: x['height'], reverse=True)
        audio_qualities.sort(key=lambda x: x['abr'], reverse=True)
        
        if not video_qualities:
            video_qualities = [{'format_id': 'bestvideo+bestaudio/best', 'height': 1080, 'label': 'Best Available'}]
        if not audio_qualities:
            audio_qualities = [{'format_id': 'bestaudio/best', 'abr': 320, 'label': 'Best Available'}]
        
        return jsonify({
            'title': info.get('title', 'Unknown'),
            'channel': info.get('uploader', 'Unknown'),
            'duration': info.get('duration', 0),
            'thumbnail': info.get('thumbnail', ''),
            'video_qualities': video_qualities,
            'audio_qualities': audio_qualities
        })
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/download', methods=['POST'])
def download_video():
    update_activity()
    data = request.get_json()
    
    if not data:
        return jsonify({'error': 'Request body is required'}), 400
    
    url = data.get('url')
    format_type = data.get('format', 'mp4')
    quality = data.get('quality', 'best')
    
    if not url:
        return jsonify({'error': 'URL is required'}), 400
    
    task_id = str(uuid.uuid4())
    download_tasks[task_id] = {'status': 'starting', 'progress': 0, 'filename': None, 'error': None}
    
    thread = threading.Thread(target=download_worker, args=(task_id, url, format_type, quality))
    thread.daemon = True
    thread.start()
    
    return jsonify({'success': True, 'task_id': task_id})


def progress_hook(task_id):
    def hook(d):
        update_activity()
        if d['status'] == 'downloading':
            total = d.get('total_bytes') or d.get('total_bytes_estimate', 0)
            downloaded = d.get('downloaded_bytes', 0)
            if total > 0:
                download_tasks[task_id]['progress'] = (downloaded / total) * 100
                download_tasks[task_id]['status'] = 'downloading'
        elif d['status'] == 'finished':
            download_tasks[task_id]['progress'] = 100
            download_tasks[task_id]['status'] = 'processing'
    return hook


def download_worker(task_id, url, format_type, quality):
    try:
        if format_type == 'mp3':
            ydl_opts = {
                'format': 'bestaudio/best',
                'outtmpl': os.path.join(DOWNLOAD_FOLDER, '%(title)s.%(ext)s'),
                'postprocessors': [{'key': 'FFmpegExtractAudio', 'preferredcodec': 'mp3', 'preferredquality': '320'}],
                'progress_hooks': [progress_hook(task_id)],
                'quiet': True,
            }
        else:
            ydl_opts = {
                'format': quality if quality != 'best' else 'bestvideo+bestaudio/best',
                'outtmpl': os.path.join(DOWNLOAD_FOLDER, '%(title)s.%(ext)s'),
                'merge_output_format': 'mp4',
                'progress_hooks': [progress_hook(task_id)],
                'quiet': True,
            }
        
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)
            filename = ydl.prepare_filename(info)
            if format_type == 'mp3':
                filename = os.path.splitext(filename)[0] + '.mp3'
            
            download_tasks[task_id]['status'] = 'completed'
            download_tasks[task_id]['progress'] = 100
            download_tasks[task_id]['filename'] = os.path.basename(filename)
    
    except Exception as e:
        download_tasks[task_id]['status'] = 'error'
        download_tasks[task_id]['error'] = str(e)


@app.route('/api/progress/<task_id>', methods=['GET'])
def get_progress(task_id):
    update_activity()
    if task_id not in download_tasks:
        return jsonify({'error': 'Task not found'}), 404
    return jsonify(download_tasks[task_id])


if __name__ == '__main__':
    # Start idle checker thread
    idle_thread = threading.Thread(target=check_idle_shutdown, daemon=True)
    idle_thread.start()
    
    print(f"""
╔═══════════════════════════════════════════════════════════╗
║         Tatarus YT Downloader - Backend Server            ║
╠═══════════════════════════════════════════════════════════╣
║  🌐 Server: http://127.0.0.1:5000                         ║
║  📁 Downloads: ~/Downloads                                ║
║  ⏰ Auto-shutdown: {IDLE_TIMEOUT//60} minutes of inactivity              ║
╚═══════════════════════════════════════════════════════════╝
    """)
    
    app.run(host='127.0.0.1', port=5000, debug=False)
