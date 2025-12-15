# 🎬 Tatarus YT Downloader

<div align="center">
  <img src="extension/icons/icon-128.png" alt="Tatarus YT Downloader" width="128">
  <br><br>
  <strong>Chrome Extension สำหรับดาวน์โหลดวิดีโอและเพลงจาก YouTube</strong>
  <br><br>
  
  [![License: MIT](https://img.shields.io/badge/License-MIT-red.svg)](LICENSE)
  [![Python 3.8+](https://img.shields.io/badge/Python-3.8+-blue.svg)](https://python.org)
  [![yt-dlp](https://img.shields.io/badge/Powered%20by-yt--dlp-green.svg)](https://github.com/yt-dlp/yt-dlp)
</div>

---

## 📖 เกี่ยวกับโปรเจค

**Tatarus YT Downloader** เป็น Chrome Extension ที่ช่วยให้คุณดาวน์โหลดวิดีโอและเพลงจาก YouTube ได้อย่างง่ายดาย โดยใช้ `yt-dlp` เป็น backend สำหรับประมวลผล

### ✨ Features

| Feature | Description |
|---------|-------------|
| 🎬 **วิดีโอ MP4** | ดาวน์โหลดวิดีโอคุณภาพ 360p - 4K |
| 🎵 **เสียง MP3** | ดาวน์โหลดเพลงคุณภาพสูงถึง 320kbps |
| 📊 **Dynamic Quality** | แสดงคุณภาพที่มีจริงของแต่ละวิดีโอ |
| 🎨 **Dark UI** | หน้าตาสวยงาม ทันสมัย |
| ⚡ **Progress Bar** | ติดตามความคืบหน้าแบบ Real-time |

---

## � โครงสร้างโปรเจค

```
tatarus-ytdownloader-extension/
├── extension/           # Chrome Extension
│   ├── manifest.json    # Extension configuration
│   ├── popup.html       # UI หลัก
│   ├── popup.css        # Styles
│   ├── popup.js         # Logic
│   └── icons/           # Extension icons
└── server/              # Python Backend
    ├── app.py           # Flask API server
    ├── requirements.txt # Python dependencies
    └── render.yaml      # Deployment config
```

---

## 🚀 วิธีใช้งาน

### 1. ติดตั้ง Dependencies

```bash
cd server
pip install -r requirements.txt
```

### 2. รัน Backend Server

```bash
cd server
python app.py
```

Server จะรันที่ `http://localhost:5000`

### 3. ติดตั้ง Extension

1. เปิด `chrome://extensions/`
2. เปิด **Developer mode**
3. คลิก **Load unpacked**
4. เลือกโฟลเดอร์ `extension`

### 4. ดาวน์โหลดวิดีโอ

1. เปิดวิดีโอ YouTube
2. คลิกไอคอน Extension
3. เลือก MP4 หรือ MP3
4. เลือกคุณภาพ
5. กด **ดาวน์โหลด**

---

## 🔧 คำสั่งเบื้องต้น

| คำสั่ง | รายละเอียด |
|--------|------------|
| `pip install -r requirements.txt` | ติดตั้ง dependencies |
| `python app.py` | รัน server |
| `curl http://localhost:5000/api/health` | ตรวจสอบ server |

---

## 📜 License

MIT License © 2024 Tatarus
