# Whisper Voice Notes

> 📱 本地語音筆記 App，支援 Whisper 離線語音辨識  
> ✨ Capture ideas instantly. Offline. Private. Whisper-powered.

---

## 🎯 專案簡介

本專案是一款 Flutter 架構的語音筆記 App，採用 [whisper.cpp](https://github.com/ggml-org/whisper.cpp) 實現完全本地的語音轉文字功能。無需網路連線，保護隱私，即時轉錄。

### 🏗️ 技術架構
- **前端**: Flutter (Dart)
- **中介層**: Kotlin/Java (Android)
- **核心引擎**: whisper.cpp (C++) via Git Submodule
- **通訊方式**: JNI Bridge + MethodChannel
- **平台支援**: Android (未來擴展至 iOS)

---

## ✅ 目前進度

### 🔥 **第一階段：JNI 橋接 (✅ 已完成)**
- ✅ **Flutter → Kotlin → JNI → C++ 完整打通**
- ✅ **MethodChannel 通訊測試成功**
- ✅ **JNI 函式 `runWhisper` 正常運作**
- ✅ **資料傳遞和回傳驗證完成**
- ✅ **Android Studio 編譯通過**

### 🎉 **第二階段：官方 whisper.cpp 整合 (✅ 已完成)**
- ✅ **Git Submodule 整合** - 使用官方推薦方式
- ✅ **CMakeLists.txt 重構** - 基於官方 Android 範例
- ✅ **GGML 自動依賴管理** - FetchContent 自動處理
- ✅ **ARM 優化啟用** - NEON, FMA, OpenMP 全部啟用
- ✅ **whisper.h API 可用** - 可以呼叫完整 whisper 功能

#### 📊 **整合成功驗證：**
```log
I/WhisperJNI: Whisper system info: WHISPER : COREML = 0 | OPENVINO = 0 | 
CPU : NEON = 1 | ARM_FMA = 1 | OPENMP = 1 | REPACK = 1 |
✅ NEON = 1     - ARM NEON 加速已啟用
✅ ARM_FMA = 1  - ARM FMA 優化啟用 
✅ OPENMP = 1   - 多執行緒支援啟用
✅ REPACK = 1   - 記憶體優化啟用
```

### 📁 **目前專案結構**
```
whisper_voice_notes/
├── android/app/src/main/
│   ├── cpp/                    # JNI 橋接層
│   │   ├── native-lib.cpp      # JNI 實作 (含 whisper.h)
│   │   └── CMakeLists.txt      # 官方標準編譯設定
│   └── kotlin/com/jovicheer/whisper_voice_notes/
│       └── MainActivity.kt     # MethodChannel 處理
├── lib/
│   └── main.dart               # Flutter UI + 測試介面
├── third_party/
│   └── whisper.cpp/            # Git Submodule (官方源碼)
├── README.md                   # 本檔案
└── DEVELOPMENT_NOTES.md        # 開發技術筆記
```

---

## 🚀 **下一步開發計劃**

### 🎯 **第三階段：基礎語音辨識 (即將開始)**

#### **A. 模型載入機制 (優先級：🔥🔥🔥)**
- [ ] **下載測試模型**
  ```bash
  # 下載 ggml-base.bin (148MB) 到 assets/models/
  curl -o assets/models/ggml-base.bin https://huggingface.co/ggml-org/whisper.cpp/blob/main/ggml-base.bin
  ```
- [ ] **Asset 管理系統**
  - 從 `assets/models/` 複製模型到內部儲存
  - 實作模型檔案完整性檢查
  - 快取機制避免重複複製
- [ ] **模型載入 JNI 函式**
  ```cpp
  // 參考官方範例實作
  JNIEXPORT jlong JNICALL initWhisperContext(JNIEnv *env, jobject thiz, jstring modelPath)
  JNIEXPORT void JNICALL freeWhisperContext(JNIEnv *env, jobject thiz, jlong contextPtr)
  ```

#### **B. 音檔轉錄功能 (優先級：🔥🔥)**
- [ ] **實作真正的語音辨識**
  ```cpp
  // 基於官方 fullTranscribe 實作
  JNIEXPORT jstring JNICALL transcribeAudioFile(JNIEnv *env, jobject thiz, 
      jlong contextPtr, jstring audioPath, jint numThreads)
  ```
- [ ] **音檔格式支援**
  - WAV 16kHz mono (優先)
  - 其他格式轉換 (使用 FFmpeg 或內建轉換)
- [ ] **分段處理長音檔**
  - 自動切分超過 30 秒的音檔
  - 避免記憶體不足問題

#### **C. Flutter 端整合 (優先級：🔥)**
- [ ] **MethodChannel 擴展**
  ```dart
  class WhisperService {
    Future<String> initModel(String modelName);
    Future<String> transcribeFile(String audioPath);
    Future<void> releaseModel();
  }
  ```
- [ ] **錯誤處理與使用者體驗**
  - 載入進度指示器
  - 轉錄進度回報
  - 友善的錯誤訊息

### 🎙️ **第四階段：錄音功能整合 (下週目標)**

#### **A. 錄音插件整合**
- [ ] **選擇錄音插件**
  - `flutter_sound` vs `audio_recorder2` 評估
  - 確保輸出 16kHz mono WAV 格式
- [ ] **錄音 UI 設計**
  - 大型錄音按鈕
  - 實時音量波形顯示
  - 錄音時間計時器

#### **B. 錄音品質優化**
- [ ] **音訊預處理**
  - 噪音抑制
  - 音量正規化
  - 靜音檢測與自動停止

### ⚡ **第五階段：性能優化 (未來 2 週)**

#### **A. VAD 語音活動檢測**
- [ ] **Silero-VAD 整合**
  ```bash
  # 下載 VAD 模型
  ./third_party/whisper.cpp/models/download-vad-model.sh silero-v5.1.2
  ```
- [ ] **智慧分段轉錄**
  - 只轉錄有語音的片段
  - 可提升 60-80% 效能

#### **B. 即時轉錄功能**
- [ ] **參考 whisper-stream 範例**
- [ ] **邊錄邊轉實作**
- [ ] **分段結果合併**

### 🎨 **第六階段：UI/UX 完善 (未來 1 個月)**

#### **A. 現代化界面**
- [ ] **Material Design 3**
- [ ] **深色模式支援**  
- [ ] **動畫與轉場效果**

#### **B. 筆記管理**
- [ ] **筆記列表與搜尋**
- [ ] **分類與標籤系統**
- [ ] **匯出功能 (文字/音檔)**

---

## 🛠️ **技術債務與優化**

### 📊 **已知限制**
- **模型檔案大小**: base 模型 148MB，會增加 APK 體積
- **記憶體使用**: 模型載入需要 ~210MB RAM
- **初次載入時間**: 模型複製需要 3-5 秒

### 💡 **計劃的解決方案**
- **App Bundle**: 使用 Android App Bundle 動態分發
- **模型下載**: 首次啟動時從網路下載模型
- **記憶體管理**: 實作模型載入/釋放生命週期管理

---

## 🧪 **測試與驗證**

### ✅ **目前可測試功能**
1. **JNI 橋接測試**: 點擊 App 中的「測試 Whisper JNI」按鈕
2. **Whisper 整合驗證**: 檢查系統資訊顯示 ARM 優化啟用
3. **編譯穩定性**: `flutter clean && flutter run` 成功編譯

### 📋 **下階段測試計劃**
- [ ] **模型載入測試**: 不同大小模型的載入時間
- [ ] **轉錄準確度測試**: 中英文語音測試樣本
- [ ] **性能基準測試**: 記憶體使用量和 CPU 負載
- [ ] **多設備相容性**: 不同 Android 版本和硬體

---

## 🤝 **貢獻指南**

1. Fork 此專案
2. 建立特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交變更 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 開啟 Pull Request

---

## 📄 **授權條款**

本專案採用 MIT 授權條款。詳見 [LICENSE](LICENSE) 檔案。

---

## 🙏 **致謝**

- [whisper.cpp](https://github.com/ggml-org/whisper.cpp) - 提供優秀的 C++ Whisper 實作
- [OpenAI Whisper](https://openai.com/research/whisper) - 原始語音辨識模型
- Flutter 和 Android 開發社群的豐富資源

---

**🎯 目標：打造最好用的本地語音筆記 App！** 
**🔥 當前狀態：whisper.cpp 官方整合完成，準備實作真正的語音辨識功能！**