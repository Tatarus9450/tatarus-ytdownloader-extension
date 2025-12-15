"""
Tatarus YT Downloader - Backend Server
Flask API server with Sleep/Wake functionality
- Starts in SLEEPING mode (minimal resources)
- Wakes up on /api/wakeup call from extension
- Auto-sleeps after 10 minutes of inactivity
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

# Server State Management
class ServerState:
    SLEEPING = "sleeping"
    AWAKE = "awake"

server_state = ServerState.SLEEPING
last_activity_time = time.time()
IDLE_TIMEOUT = 180  #3 minutes

# Download folder
DOWNLOAD_FOLDER = os.path.join(os.path.expanduser('~'), 'Downloads')
os.makedirs(DOWNLOAD_FOLDER, exist_ok=True)

# Download tasks
download_tasks = {}


def update_activity():
    """Update last activity timestamp"""
    global last_activity_time
    last_activity_time = time.time()


def check_idle_and_sleep():
    """Background thread to check idle time and put server to sleep"""
    global server_state
    while True:
        time.sleep(60)  # Check every minute
        if server_state == ServerState.AWAKE:
            idle_time = time.time() - last_activity_time
            if idle_time >= IDLE_TIMEOUT:
                server_state = ServerState.SLEEPING
                print(f"\n💤 Server going to SLEEP after {IDLE_TIMEOUT//60} min idle...")


def require_awake(f):
    """Decorator to require AWAKE state for endpoints"""
    def wrapper(*args, **kwargs):
        if server_state == ServerState.SLEEPING:
            return jsonify({
                'error': 'Server is sleeping',
                'state': server_state,
                'message': 'Call /api/wakeup first'
            }), 503
        return f(*args, **kwargs)
    wrapper.__name__ = f.__name__
    return wrapper


# =============================================================================
# Core Endpoints
# =============================================================================

@app.route('/api/status', methods=['GET'])
def get_status():
    """Get server status - always available"""
    return jsonify({
        'state': server_state,
        'idle_timeout': IDLE_TIMEOUT
    })


@app.route('/api/wakeup', methods=['GET', 'POST'])
def wakeup():
    """Wake up the server - always available"""
    global server_state
    server_state = ServerState.AWAKE
    update_activity()
    print("⚡ Server AWAKE!")
    return jsonify({
        'state': server_state,
        'message': 'Server is now awake'
    })


@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check - always available"""
    return jsonify({
        'status': 'ok',
        'state': server_state
    })


# =============================================================================
# Protected Endpoints (require AWAKE state)
# =============================================================================

@app.route('/api/info', methods=['GET'])
@require_awake
def get_video_info():
    """Get video information - requires AWAKE"""
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
@require_awake
def download_video():
    """Start download - requires AWAKE"""
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


@app.route('/api/progress/<task_id>', methods=['GET'])
@require_awake
def get_progress(task_id):
    """Get download progress - requires AWAKE"""
    update_activity()
    if task_id not in download_tasks:
        return jsonify({'error': 'Task not found'}), 404
    return jsonify(download_tasks[task_id])


# =============================================================================
# Helper Functions
# =============================================================================

def get_quality_label(height):
    labels = {2160: '4K (2160p)', 1440: '2K (1440p)', 1080: 'Full HD (1080p)',
              720: 'HD (720p)', 480: 'SD (480p)', 360: 'Low (360p)'}
    return labels.get(height, f'{height}p')


def get_audio_quality_label(abr):
    labels = {320: '320 kbps (Best)', 256: '256 kbps', 192: '192 kbps', 128: '128 kbps'}
    return labels.get(int(abr) if abr else 128, f'{int(abr)} kbps')


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


# =============================================================================
# Main
# =============================================================================

if __name__ == '__main__':
    # Start idle checker thread
    idle_thread = threading.Thread(target=check_idle_and_sleep, daemon=True)
    idle_thread.start()
    
    print(f"""
╔═══════════════════════════════════════════════════════════╗
║         Tatarus YT Downloader - Backend Server            ║
╠═══════════════════════════════════════════════════════════╣
║  🌐 Server: http://127.0.0.1:5000                         ║
║  📁 Downloads: ~/Downloads                                ║
║  💤 State: SLEEPING (waiting for wakeup signal)           ║
║  ⏰ Auto-sleep: {IDLE_TIMEOUT//60} min of inactivity                     ║
╚═══════════════════════════════════════════════════════════╝
    """)
    
    app.run(host='127.0.0.1', port=5000, debug=False, threaded=True)
