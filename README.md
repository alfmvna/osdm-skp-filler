# OSDM SKP Filler

Aplikasi Desktop Windows untuk mengisi **Log Harian SKP** di sistem [OSDM Kemdikti Saintek](https://osdm.kemdiktisaintek.go.id/skp) dengan lebih mudah dan cepat.

> Dibuat untuk mendukung Teknisi Laboratorium IT Politeknik Negeri Batam dalam memenuhi kewajiban pengisian log harian SKP.

---

## 🎯 Fitur

### Core Features
- **Login OSDM** — Authenticate dengan NIP dan Password (support "Ingat saya")
- **Dashboard Kalender** — Lihat status log per tanggal dengan color coding
- **Multi-Date Selection** — Pilih beberapa tanggal sekaligus untuk diisi
- **Auto-Random SKP Indicator** — Pilih grup SKP → random indikator dari grup tersebut
- **Template System** — Simpan dan load aktivitas favorit dari local storage
- **Batch Submit** — Kirim log untuk multiple tanggal dalam satu proses
- **Progress Tracking** — Lihat progress pengiriman per tanggal
- **Log Viewer** — Lihat semua log yang sudah terisi per bulan

### SKP Groups
Aplikasi menyediakan 6 grup indikator SKP:
1. **Pengadaan Barang & Jasa**
2. **Laboratorium & Sarana**
3. **Inventaris & Aset**
4. **Website & Digital**
5. **Monitoring & Evaluasi**
6. **Penugasan Umum**

---

## 📷 Screenshot

```
┌─────────────────────────────────────────┐
│  OSDM SKP Filler                        │
├─────────────────────────────────────────┤
│  Log Harian - April 2026                │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │  Terisi    : 13  Belum : 9      │    │
│  │  Libur     :  8                 │    │
│  └─────────────────────────────────┘    │
│                                         │
│  [Kalender Mini - Color Coded]           │
│                                         │
│  [🟢 Terisi] [⬜ Belum] [🔴 Libur]      │
│                                         │
│  [+ Isi Log Baru]  [Lihat Log]          │
│                                         │
└─────────────────────────────────────────┘
```

---

## 💻 Requirements

- **OS:** Windows 10/11 (64-bit)
- **Flutter SDK:** 3.2.0 or later
- **Disk Space:** ~500 MB

---

## 🔧 Build dari Source (Windows)

### Step 1: Install Flutter SDK

```powershell
# Download Flutter SDK
# https://docs.flutter.dev/get-started/install/windows

# Extract ke C:\src\flutter
# ATAU gunakan winget (PowerShell Admin):
winget install FlutterSDK.Flutter

# Restart terminal
```

### Step 2: Enable Windows Desktop

```powershell
flutter config --enable-windows-desktop
```

### Step 3: Clone Project

```powershell
cd C:\projects
git clone https://github.com/username/osdm-skp-filler.git
cd osdm-skp-filler
```

### Step 4: Install Dependencies

```powershell
flutter pub get
```

### Step 5: Build Release

```powershell
flutter build windows --release
```

### Step 6: Run

```powershell
# Executable ada di:
# build\windows\x64\runner\Release\osdm_skp_filler.exe

# Jalankan langsung:
start build\windows\x64\runner\Release\osdm_skp_filler.exe
```

---

## 📁 Project Structure

```
osdm_skp_filler/
├── lib/
│   ├── main.dart                    # Entry point
│   ├── app.dart                     # App routing
│   ├── core/
│   │   ├── api_client.dart          # Dio HTTP + CSRF handler
│   │   ├── constants.dart           # SKP groups & indicators
│   │   └── storage.dart             # Encrypted local storage
│   ├── features/
│   │   ├── auth/                    # Login screen + cubit
│   │   ├── dashboard/               # Calendar dashboard
│   │   ├── date_select/             # Multi-date picker
│   │   ├── log_entry/               # Log entry form + confirmation
│   │   └── log_viewer/              # View existing logs
│   └── shared/theme/                # App theme
├── pubspec.yaml
├── README.md
└── BUILD_WINDOWS.md
```

---

## 🔒 Keamanan

- **Credential Storage:** Di-encrypt menggunakan AES-32 sebelum disimpan ke SharedPreferences
- **Session:** Menggunakan cookie-based session (sama seperti web OSDM)
- **CSRF:** Auto-refresh CSRF token sebelum setiap POST request
- **No External Transmission:** Data login tidak dikirim ke server manapun selain OSDM

---

## ⚠️ Catatan Penting

1. **Akun OSDM** — Gunakan NIP dan Password yang sama dengan login di [osdm.kemdiktisaintek.go.id](https://osdm.kemdiktisaintek.go.id/skp)
2. **Log Masa Lalu** — Log hanya bisa diisi untuk tanggal hari ini atau sebelumnya
3. **Weekend/Holiday** — Tanggal merah dan weekend tidak dapat diisi
4. **Random Indicator** — Indikator di-random dari grup yang dipilih; user bisa re-random atau pilih manual

---

## 🛠️ Troubleshooting

### Build Error: `Visual Studio Build Tools not found`
```powershell
# Install Visual Studio Build Tools
# Pilih "Desktop development with C++" workload
```

### Run Error: `API error 500`
```powershell
# Kemungkinan CSRF token expired
# Tutup aplikasi, buka lagi, login ulang
```

### Network Error
```powershell
# Pastikan terhubung ke internet
# Cek firewall/ proxy jika pakai jaringan kampus
```

---

## 📝 License

Private project untuk penggunaan personal Allif Maulana — Politeknik Negeri Batam.

---

## 👤 Author

**Allif Maulana, S.Tr.Kom.**
Teknisi Laboratorium IT
Politeknik Negeri Batam
