# Tatarus YT Downloader

Chrome Extension สำหรับดาวน์โหลดวิดีโอและเพลงจาก YouTube ด้วย yt-dlp

![Extension Preview](extension/icons/icon-128.png)

## ✨ Features

- 🎬 **ดาวน์โหลดวิดีโอ MP4** - รองรับหลายคุณภาพ (144p - 4K)
- 🎵 **ดาวน์โหลดเสียง MP3** - รองรับหลาย bitrate (64kbps - 320kbps)
- 📊 **เลือกคุณภาพ** - Dropdown ให้เลือกคุณภาพตามต้องการ
- 🎨 **UI สวยงาม** - Dark theme ทันสมัย พร้อม animations
- 📥 **Progress Bar** - แสดงความคืบหน้าการดาวน์โหลด

## 📋 Requirements

- Python 3.8+
- Google Chrome / Chromium-based Browser
- FFmpeg (สำหรับแปลงไฟล์เสียง MP3)

## 🚀 Installation

### 1. ติดตั้ง Python Dependencies

```bash
cd server
pip install -r requirements.txt
```

### 2. ติดตั้ง FFmpeg (ถ้ายังไม่มี)

**Ubuntu/Debian:**
```bash
sudo apt update && sudo apt install ffmpeg
```

**macOS:**
```bash
brew install ffmpeg
```

**Windows:**
ดาวน์โหลดจาก [ffmpeg.org](https://ffmpeg.org/download.html)

### 3. รัน Backend Server

```bash
cd server
python server.py
```

Server จะรันที่ `http://localhost:5000`

### 4. ติดตั้ง Chrome Extension

1. เปิด Chrome และไปที่ `chrome://extensions/`
2. เปิด **Developer mode** (มุมขวาบน)
3. คลิก **Load unpacked**
4. เลือกโฟลเดอร์ `extension` จากโปรเจคนี้

## 📖 วิธีใช้งาน

1. **เปิดวิดีโอ YouTube** ที่ต้องการดาวน์โหลด
2. **คลิกที่ไอคอน Extension** บน toolbar
3. **เลือกรูปแบบ** (MP4 หรือ MP3)
4. **เลือกคุณภาพ** จาก dropdown
5. **กดปุ่ม Download** และรอจนเสร็จ

ไฟล์จะถูกบันทึกไว้ที่โฟลเดอร์ **Downloads** ของคุณ

## 📁 โครงสร้างโปรเจค

```
tatarus-ytdownloader-extension/
├── README.md
├── extension/              # Chrome Extension
│   ├── manifest.json       # Extension manifest
│   ├── popup.html          # Popup UI
│   ├── popup.css           # Styles
│   ├── popup.js            # Frontend logic
│   └── icons/              # Extension icons
│       ├── icon-16.png
│       ├── icon-48.png
│       └── icon-128.png
└── server/                 # Python Backend
    ├── requirements.txt    # Python dependencies
    ├── config.py           # Configuration
    └── server.py           # Flask API server
```

## 🔧 Configuration

แก้ไขไฟล์ `server/config.py` เพื่อเปลี่ยนการตั้งค่า:

```python
# เปลี่ยนโฟลเดอร์สำหรับบันทึกไฟล์
DOWNLOAD_FOLDER = '/path/to/your/folder'

# เปลี่ยน port
PORT = 5000
```

## 🛠 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/info?url=...` | ดึงข้อมูลวิดีโอ |
| POST | `/api/download` | เริ่มดาวน์โหลด |
| GET | `/api/progress/<task_id>` | ดูความคืบหน้า |
| GET | `/api/health` | Health check |

## ⚠️ หมายเหตุ

- ต้องรัน Python server ไว้เบื้องหลังตลอดเวลาที่ใช้งาน
- Extension ใช้งานได้เฉพาะกับ YouTube URLs
- การดาวน์โหลดวิดีโอคุณภาพสูงอาจใช้เวลานาน

## 📜 License

MIT License

---

**Powered by [yt-dlp](https://github.com/yt-dlp/yt-dlp)** 🚀
