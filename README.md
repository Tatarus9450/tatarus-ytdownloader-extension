# Tatarus YT Downloader

Chrome Extension สำหรับดาวน์โหลดวิดีโอและเพลงจาก YouTube

<div align="center">
  <img src="extension/icons/icon-128.png" alt="Extension Preview" width="300">
</div>

## ✨ Features

- 🎬 **ดาวน์โหลดวิดีโอ MP4** - รองรับหลายคุณภาพ (360p - 4K)
- 🎵 **ดาวน์โหลดเสียง MP3** - รองรับหลาย bitrate
- 📊 **Dynamic Quality** - แสดงคุณภาพที่มีจริงของแต่ละวิดีโอ
- 🎨 **UI สวยงาม** - Dark theme ทันสมัย

---

## 🚀 Installation (2 ขั้นตอน)

### ขั้นตอนที่ 1: Deploy Server (ฟรี!)

1. **สมัคร [Render.com](https://render.com)** (ฟรี, ใช้ GitHub login ได้)

2. **Fork repo นี้** ไปยัง GitHub ของคุณ

3. **สร้าง New Web Service บน Render:**
   - คลิก "New +" → "Web Service"
   - Connect GitHub repo ที่ fork
   - ตั้งค่า:
     ```
     Root Directory: server
     Build Command: pip install -r requirements.txt
     Start Command: gunicorn app:app
     Instance Type: Free
     ```
   - คลิก "Create Web Service"

4. **คัดลอก URL** ที่ได้ เช่น `https://tatarus-ytdownloader.onrender.com`

### ขั้นตอนที่ 2: ติดตั้ง Extension

1. **แก้ไขไฟล์** `extension/popup.js`:
   ```javascript
   const API_BASE_URL = 'https://YOUR-APP-NAME.onrender.com';
   // เปลี่ยนเป็น URL ที่ได้จาก Render.com
   ```

2. **ติดตั้ง Extension:**
   - เปิด `chrome://extensions/`
   - เปิด Developer mode
   - คลิก "Load unpacked" → เลือกโฟลเดอร์ `extension`

---

## 📖 วิธีใช้งาน

1. เปิดวิดีโอ YouTube
2. คลิกไอคอน Extension
3. เลือกรูปแบบ (MP4/MP3)
4. เลือกคุณภาพ
5. กดดาวน์โหลด!

---

## ⚠️ หมายเหตุ

- **Cold Start:** Render Free Tier จะ sleep หลัง 15 นาที - การเรียกครั้งแรกอาจใช้เวลา 30-60 วินาที
- วิดีโอยาวอาจใช้เวลาดาวน์โหลดนาน

## 📁 โครงสร้าง

```
├── extension/          # Chrome Extension
│   ├── manifest.json
│   ├── popup.html
│   ├── popup.css
│   └── popup.js        # ⚠️ ต้องแก้ API_BASE_URL
└── server/             # Python Backend  
    ├── app.py
    ├── requirements.txt
    └── render.yaml
```

## 📜 License

MIT License
