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

## � การติดตั้ง

### ความต้องการ

- **Python 3.8+** - [ดาวน์โหลด](https://python.org)
- **Chrome Browser**
- **FFmpeg** (สำหรับแปลง MP3) - [ดาวน์โหลด](https://ffmpeg.org)

### ขั้นตอนที่ 1: ติดตั้ง Dependencies

**Windows:**
```batch
ดับเบิ้ลคลิก installer\install-windows.bat
```

**Mac/Linux:**
```bash
chmod +x installer/install-mac-linux.sh
./installer/install-mac-linux.sh
```

**หรือติดตั้งเอง:**
```bash
cd server
pip install -r requirements.txt
```

### ขั้นตอนที่ 2: ติดตั้ง Extension

1. เปิด Chrome → `chrome://extensions/`
2. เปิด **Developer mode** (มุมขวาบน)
3. คลิก **Load unpacked**
4. เลือกโฟลเดอร์ `extension`

---

## 📖 วิธีใช้งาน

### 1. รัน Server

**Windows:**
```batch
cd server
python app.py
```

**Mac/Linux:**
```bash
cd server
python3 app.py
```

> 💡 **Server จะปิดอัตโนมัติหลังไม่ได้ใช้งาน 10 นาที** เพื่อประหยัดทรัพยากร

### 2. ดาวน์โหลดวิดีโอ

1. 🌐 เปิดวิดีโอ YouTube
2. 🖱️ คลิกไอคอน Extension
3. 🎯 เลือก **MP4** (วิดีโอ) หรือ **MP3** (เสียง)
4. 📊 เลือกคุณภาพ
5. ⬇️ กด **ดาวน์โหลด**

ไฟล์จะถูกบันทึกที่โฟลเดอร์ **Downloads**

---

## ✨ Features

| Feature | รายละเอียด |
|---------|------------|
| 🎬 **MP4** | ดาวน์โหลดวิดีโอ 360p - 4K |
| 🎵 **MP3** | ดาวน์โหลดเสียงคุณภาพสูง 320kbps |
| 📊 **Dynamic Quality** | แสดงคุณภาพที่มีจริง |
| ⚡ **Progress Bar** | ดูความคืบหน้าแบบ Real-time |
| ⏰ **Auto-shutdown** | ปิด Server อัตโนมัติ (10 นาที) |

---

## 📁 โครงสร้างโปรเจค

```
tatarus-ytdownloader-extension/
├── extension/           # Chrome Extension
│   ├── manifest.json
│   ├── popup.html
│   ├── popup.css
│   └── popup.js
├── server/              # Python Backend
│   ├── app.py           # Flask API + Auto-shutdown
│   └── requirements.txt
└── installer/           # Installation Scripts
    ├── install-windows.bat
    └── install-mac-linux.sh
```

---

## 🔧 คำสั่งเบื้องต้น

| คำสั่ง | รายละเอียด |
|--------|------------|
| `pip install -r requirements.txt` | ติดตั้ง dependencies |
| `python app.py` | รัน server |
| `curl localhost:5000/api/health` | ตรวจสอบ server |

---

## ⚠️ แก้ไขปัญหา

| ปัญหา | วิธีแก้ |
|-------|--------|
| Server ไม่รัน | ตรวจสอบว่าติดตั้ง Python แล้ว |
| ดาวน์โหลด MP3 ไม่ได้ | ติดตั้ง FFmpeg |
| Extension ไม่เห็น Server | รัน `python app.py` ก่อน |

---

## 📜 License

MIT License © 2024 Tatarus
