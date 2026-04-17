# Build Instructions: OSDM SKP Filler (Windows)

Panduan lengkap step-by-step untuk build aplikasi Flutter Windows ini dari nol.

---

## Prerequisites

### 1. Windows 10/11 (64-bit)

Pastikan Windows kamu 64-bit. Cek: `Settings > System > About`

### 2. Install Flutter SDK

#### Option A: Winget (Recommended) — PowerShell as Administrator

```powershell
winget install FlutterSDK.Flutter
```

#### Option B: Manual Install

1. Buka [https://docs.flutter.dev/get-started/install/windows](https://docs.flutter.dev/get-started/install/windows)
2. Download Flutter SDK (.zip)
3. Extract ke `C:\src\flutter` (buat folder `src` jika belum ada)
4. Tambahkan ke PATH:
   ```
   C:\src\flutter\bin
   ```

#### Verifikasi Install

Buka **PowerShell baru** (atau Command Prompt):

```powershell
flutter --version
```

Output пример:
```
Flutter 3.22.0 • channel stable • https://github.com/flutter/flutter.git
```

---

## Step-by-Step Build

### Step 1: Clone Repository

```powershell
# Buka PowerShell / Command Prompt
cd C:\projects

# Clone repo (ganti URL sesuai repo kamu)
git clone https://github.com/username/osdm-skp-filler.git
cd osdm-skp-filler
```

Atau download ZIP langsung dari GitHub → Extract.

### Step 2: Enable Windows Desktop

```powershell
flutter config --enable-windows-desktop
```

### Step 3: Install Dependencies

```powershell
flutter pub get
```

Ini akan mendownload semua package dari `pubspec.yaml`.

### Step 4: Check Environment

```powershell
flutter doctor
```

Pastikan semua checkmarks hijau (✅). Minimal perlu:
- ✅ Flutter SDK
- ✅ Windows toolchain
- ✅ Visual Studio Build Tools (atau ✅ Visual Studio Community)

### Step 5: Build Release

```powershell
flutter build windows --release
```

**Estimasi waktu:** 3-10 menit (tergantung spek PC).

---

## Output Location

```
osdm-skp-filler/
└── build/
    └── windows/
        └── x64/
            └── runner/
                └── Release/
                    ├── osdm_skp_filler.exe   ← Executable utama
                    ├── flutter_windows.dll
                    └── data/
```

---

## Run / Test

### Development Mode (Debug)

```powershell
flutter run -d windows
```

### Release Mode (Production)

```powershell
# Jalankan exe langsung
start build\windows\x64\runner\Release\osdm_skp_filler.exe

# Atau double-click file .exe di File Explorer
```

---

## Troubleshooting Build

### Error: `Visual Studio Build Tools not found`

**Solusi:**

1. Download Visual Studio Build Tools:
   [https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022)

2. Install dengan pilihan:
   - **Workloads** → "Desktop development with C++"
   - **Individual components** → Centang:
     - Windows 10 SDK
     - C++ ATL for latest builds

3. Retry: `flutter build windows --release`

### Error: `The number of CPUs less than minimum required`

**Solusi:**

```powershell
flutter config --no-analytics
flutter doctor -v
```

### Error: `Network timeout` saat pub get

**Solusi:**

```powershell
# Pakai mirror
flutter pub get --pub https://pub.flutter-io.cn
```

Atau setting global mirror:

```powershell
flutter config --global pub https://pub.flutter-io.cn
```

### Error: `Path too long` (Windows)

**Solusi:**

```powershell
# Clone ke directory pendek
cd C:\
git clone https://github.com/username/osdm-skp-filler.git
```

---

## Visual Studio Code (Optional)

Jika pakai VS Code:

1. Install extensions:
   - Flutter (Dart-Code.flutter)
   - Dart

2. Open project folder:
   ```
   File > Open Folder > C:\projects\osdm-skp-filler
   ```

3. Run:
   - Tekan `F5` untuk Debug
   - `Ctrl+Shift+P` → `Flutter: Run`

---

## File Size

| Component | Size |
|-----------|------|
| Total Release Build | ~200-400 MB |
| Standalone .exe | ~20-50 MB |
| (Plus Flutter runtime DLLs) | |

---

## Build untuk Distribusi

Jika mau bikin installer:

```powershell
# Install flutter_installer
dart pub global activate flutter_installer

# Buat installer
flutter_installer build windows
```

Atau pakai tools lain seperti:
- **Inno Setup** (free)
- **NSIS** (free)
- **WiX Toolset** (free, advanced)

---

## Quick Command Reference

```powershell
# Setup
flutter config --enable-windows-desktop

# Development
flutter run -d windows              # Run debug
flutter build windows --release     # Build release
flutter clean                       # Clear build cache
flutter pub get                     # Fetch dependencies
flutter doctor                      # Check environment
```

---

## Butuh Bantuan?

Kalau stuck, catat error message yang muncul dan hubungi saya.

