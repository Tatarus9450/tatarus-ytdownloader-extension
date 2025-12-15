# 🎬 Tatarus YT Downloader

<div align="center">
  <img src="icons/icon-128.png" alt="Tatarus YT Downloader" width="100">
  <br><br>
  <strong>Chrome Extension for downloading YouTube videos and audio</strong><br>
  <strong>Chrome Extension สำหรับดาวน์โหลดวิดีโอและเพลงจาก YouTube</strong>
  <br><br>
  
  [![License: MIT](https://img.shields.io/badge/License-MIT-red.svg)](LICENSE)
  [![Python 3.8+](https://img.shields.io/badge/Python-3.8+-blue.svg)](https://python.org)
</div>

---

## 🚀 Installation | การติดตั้ง

### Requirements | ความต้องการ
- Python 3.8+ ([Download](https://python.org))
- Chrome Browser
- FFmpeg ([Download](https://ffmpeg.org)) - for MP3 | สำหรับ MP3

### Step 1: Load Extension | โหลด Extension
1. Open `chrome://extensions/` | เปิด `chrome://extensions/`
2. Enable **Developer mode** | เปิด **Developer mode**
3. **Load unpacked** → Select this folder | เลือกโฟลเดอร์นี้

### Step 2: Install Server (One-Time) | ติดตั้ง Server (ครั้งเดียว)

| Platform | Command |
|----------|---------|
| **Windows** | Double-click `install.bat` |
| **Mac/Linux** | `./install.sh` |

**After installation | หลังติดตั้ง:**
- ✅ Server starts automatically with PC | เริ่มอัตโนมัติเมื่อเปิด PC
- 💤 Starts in **Sleep mode** | เริ่มใน Sleep mode (ใช้ทรัพยากรน้อย)
- ⚡ Wakes when Extension opens | ตื่นเมื่อเปิด Extension
- ⏰ Auto-sleeps after 10 min idle | หลับหลังไม่ใช้ 10 นาที

---

## 📖 How to Use | วิธีใช้

1. 🌐 Open YouTube video | เปิดวิดีโอ YouTube
2. 🖱️ Click Extension icon | คลิกไอคอน Extension
3. 🎯 Select **MP4** or **MP3** | เลือก MP4 หรือ MP3
4. 📊 Choose quality | เลือกคุณภาพ
5. ⬇️ Click **Download** | กด Download

Files saved to **Downloads** folder | ไฟล์บันทึกที่โฟลเดอร์ Downloads

---

## ✨ Features | คุณสมบัติ

| Feature | Description |
|---------|-------------|
| 🎬 MP4 | Video 360p - 4K |
| 🎵 MP3 | Audio 320kbps |
| 💤 Sleep/Wake | Low resources when idle | ใช้ทรัพยากรน้อยเมื่อไม่ใช้ |
| ⏰ Auto-startup | Runs with PC | รันอัตโนมัติ |

---

## 📁 Project Structure | โครงสร้าง

```
├── manifest.json, popup.html/css/js
├── icons/
├── server/app.py
├── install.bat / install.sh   ← Installer (once) | ติดตั้ง (ครั้งเดียว)
└── start-server.sh            ← Manual start | รันเอง (optional)
```

---

## 🗑️ Uninstall | ถอนการติดตั้ง

**Windows:** Delete | ลบ `%APPDATA%\...\Startup\Tatarus-Server.bat`

**Mac:** `launchctl unload ~/Library/LaunchAgents/com.tatarus.ytdownloader.plist`

**Linux:** `systemctl --user disable tatarus-server.service`

---

MIT License © 2025 Tatarus
