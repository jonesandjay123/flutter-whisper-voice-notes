# Whisper 語音筆記 📱🎙️

一個基於 Flutter 的本地語音轉文字應用，整合 OpenAI Whisper.cpp 實現離線語音識別。

## 功能特色 ✨

### 📱 雙功能介面
- **語音錄音器**：錄製語音並生成 WAV 檔案
- **Whisper JNI 測試**：測試 C++ 與 Dart 之間的連接

### 🎙️ 語音錄音功能
- ✅ 實時錄音與播放
- ✅ 固定檔案路徑（自動覆蓋）
- ✅ WAV 格式輸出（16kHz, 單聲道）
- ✅ 錄音時間顯示
- ✅ 權限管理

### 🔧 技術整合
- ✅ Whisper.cpp 官方整合
- ✅ JNI (Java Native Interface) 連接
- ✅ C++ 與 Dart 通信
- ✅ Android NDK 27 支援

## 技術架構 🏗️

```
Flutter (Dart)
      ↓
MethodChannel
      ↓  
Android (Kotlin)
      ↓
JNI Bridge
      ↓
C++ (whisper.cpp)
```

## 專案結構 📁

```
lib/
├── main.dart                 # 應用入口
├── pages/
│   ├── home_page.dart        # 主選單頁面
│   ├── voice_recorder_page.dart  # 語音錄音器
│   └── whisper_test_page.dart    # JNI 測試頁面
android/
├── app/src/main/
│   ├── kotlin/.../MainActivity.kt  # Android 主活動
│   └── cpp/
│       ├── native-lib.cpp     # JNI 實作
│       └── CMakeLists.txt     # 編譯配置
third_party/
└── whisper.cpp/              # Whisper.cpp 官方源碼
```

## 安裝需求 📋

### 開發環境
- Flutter SDK 3.32.4+
- Android Studio
- Android NDK 27.0.12077973
- Dart 3.8.1+

### Android 需求
- minSdkVersion: 23
- targetSdkVersion: 34
- 麥克風權限
- 存儲權限

## 快速開始 🚀

### 1. 克隆專案
```bash
git clone [repository-url]
cd whisper_voice_notes
```

### 2. 安裝依賴
```bash
flutter pub get
```

### 3. 設定 Android NDK
確保 Android Studio 中安裝了 NDK 27.0.12077973

### 4. 運行應用
```bash
flutter run
```

## 使用指南 📖

### 語音錄音器
1. 點擊「語音錄音器」進入錄音界面
2. 點擊「開始錄音」開始錄製
3. 說話進行錄音（會顯示錄音時間）
4. 點擊「停止錄音」結束錄製
5. 點擊「播放錄音」測試錄製結果

### JNI 測試
1. 點擊「Whisper JNI 測試」進入測試界面
2. 點擊「測試模型載入」查看模型資訊
3. 點擊「測試 Whisper JNI」驗證 C++ 連接

## 技術細節 🔬

### 錄音設定
- **格式**：WAV
- **採樣率**：16kHz
- **聲道**：單聲道 (Mono)
- **位深**：16-bit
- **檔案位置**：`/data/data/app/files/voice_recording.wav`

### JNI 介面
```cpp
// 主要 JNI 方法
extern "C" JNIEXPORT jstring JNICALL
Java_com_jovicheer_whisper_1voice_1notes_MainActivity_runWhisper(
    JNIEnv *env, jobject, jstring audioPath);
```

### 依賴套件
```yaml
dependencies:
  record: ^6.0.0           # 錄音功能
  audioplayers: ^6.0.0     # 音頻播放
  path_provider: ^2.1.4    # 檔案路徑
  permission_handler: ^11.3.1  # 權限管理
```

## 開發狀態 🚧

### ✅ 已完成
- [x] Flutter 專案架構
- [x] Whisper.cpp 整合
- [x] JNI 橋接實作
- [x] 錄音功能
- [x] WAV 檔案生成
- [x] 雙功能 UI 界面
- [x] 權限管理

### 🔄 進行中
- [ ] 模型載入機制
- [ ] 語音識別整合
- [ ] 錯誤處理優化

### 📅 計劃中
- [ ] 多模型支援
- [ ] 轉錄結果顯示
- [ ] 音檔格式轉換
- [ ] 批次處理功能

## 疑難排解 🔧

### 常見問題

**Q: 編譯失敗，NDK 版本錯誤？**
A: 確保 `android/app/build.gradle.kts` 中設定 `ndkVersion = "27.0.12077973"`

**Q: 錄音權限被拒絕？**
A: 檢查 `AndroidManifest.xml` 中是否有 `RECORD_AUDIO` 權限

**Q: JNI 連接失敗？**
A: 確認 whisper.cpp 子模組正確初始化

### 日誌查看
```bash
flutter logs  # 查看 Flutter 日誌
adb logcat | grep whisper  # 查看 Android 日誌
```

## 貢獻指南 🤝

1. Fork 專案
2. 建立功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 開啟 Pull Request

## 授權條款 📄

本專案使用 MIT 授權條款 - 詳見 [LICENSE](LICENSE) 檔案

## 致謝 🙏

- [OpenAI Whisper](https://github.com/openai/whisper) - 語音識別模型
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) - C++ 實作
- [Flutter](https://flutter.dev) - 跨平台 UI 框架

---

**專案狀態**：積極開發中 🚧  
**版本**：v0.1.0  
**最後更新**：2024年12月

![Flutter](https://img.shields.io/badge/Flutter-3.32.4-blue)
![Android](https://img.shields.io/badge/Android-API%2023+-green)
![Whisper](https://img.shields.io/badge/Whisper.cpp-integrated-orange)