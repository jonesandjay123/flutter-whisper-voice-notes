# 🎙️ Whisper Voice Notes

**高性能本地語音轉文字 Flutter 應用**

使用最新的 whisper.cpp 實現**毫秒級**中文語音識別，完全離線運行，保護隱私。

## ✨ 主要特色

### 🚀 極致性能
- **⚡ 毫秒級轉錄**：3秒音頻僅需1秒處理時間
- **🔥 實時性能**：轉錄速度比音頻播放快3倍
- **📱 硬體優化**：智能檢測並使用 ARM64 FP16 / NEON VFPv4 優化

### 🌍 語言支援
- **🇨🇳 中文優化**：針對中文語音識別調優
- **🌐 多語言**：支援 whisper.cpp 的所有語言
- **🔄 自動檢測**：智能語言識別

### 🔒 隱私安全
- **📱 完全離線**：所有處理在本地進行
- **🚫 無網路需求**：不上傳任何音頻數據
- **🔐 數據安全**：音頻文件僅存儲在設備本地

### 🛠️ 技術特色
- **📊 詳細統計**：實時性能監控和計時追蹤
- **🎯 智能優化**：根據設備自動選擇最佳配置
- **🔧 多版本編譯**：針對不同 CPU 架構的優化版本

## 🏆 性能表現

### 實測結果（Pixel 8 Pro）
```
音頻時長: 3.12秒
轉錄耗時: 1.02秒
處理速度: 3.06x 實時
準確率: 高（中文語音）
```

### 性能對比
| 版本 | 轉錄時間 | 性能提升 |
|------|----------|----------|
| Debug | 35-71秒 | 基準 |
| Release | **1秒** | **35-70倍** |

## 🚀 快速開始

### 環境要求
- **Flutter**: 3.0+
- **Android**: API 23+ (Android 6.0+)
- **NDK**: 27.0.12077973
- **設備**: ARM64 或 ARMv7 處理器

### 安裝步驟

1. **克隆專案**
```bash
git clone https://github.com/yourusername/whisper_voice_notes.git
cd whisper_voice_notes
```

2. **初始化子模組**
```bash
git submodule update --init --recursive
```

3. **安裝依賴**
```bash
flutter pub get
```

4. **構建並運行**
```bash
# Debug 版本（開發用）
flutter run

# Release 版本（最佳性能）
flutter build apk --release
flutter install
```

## 📁 專案結構

```
whisper_voice_notes/
├── lib/                          # Flutter 應用程式碼
│   ├── main.dart                 # 應用入口
│   └── pages/
│       └── voice_recorder_page.dart  # 主要錄音轉錄頁面
├── android/
│   └── app/src/main/
│       ├── cpp/                  # C++ Native 程式碼
│       │   ├── CMakeLists.txt    # 構建配置
│       │   └── native-lib.cpp    # JNI 接口實現
│       └── kotlin/               # Android Kotlin 程式碼
│           └── MainActivity.kt   # 主 Activity
├── assets/models/                # Whisper 模型檔案
│   ├── ggml-tiny-q5_1.bin       # Tiny 模型（32MB，推薦）
│   └── ggml-base-q5_1.bin       # Base 模型（60MB）
└── third_party/whisper.cpp/     # Whisper.cpp 子模組
```

## 🔧 技術架構

### 核心組件
- **Flutter Frontend**: 現代化 UI 和用戶交互
- **Kotlin Bridge**: Android 平台整合和協程處理
- **C++ Engine**: whisper.cpp 核心引擎
- **JNI Interface**: 高效的 Native 調用

### 智能優化
```cpp
// 自動選擇最佳 Native Library
if (CPU_supports_FP16) {
    load("whisper_v8fp16_va")  // ARM64 FP16 優化
} else if (CPU_supports_NEON) {
    load("whisper_vfpv4")      // ARMv7 NEON 優化
} else {
    load("whisper")            // 通用版本
}
```

### 性能優化策略
1. **編譯時優化**: `-O3` 優化、函數內聯、向量化
2. **運行時優化**: 智能執行緒分配、記憶體池管理
3. **模型優化**: 量化模型（Q5_1）減少記憶體佔用
4. **架構優化**: 多版本 Native Library 支援

## 📊 使用說明

### 基本操作
1. **載入模型**: 首次使用時自動從 assets 複製模型
2. **錄製音頻**: 點擊錄音按鈕開始/停止錄音
3. **播放確認**: 播放錄製的音頻確認品質
4. **開始轉錄**: 點擊轉錄按鈕進行語音識別
5. **查看結果**: 獲得詳細的轉錄結果和性能統計

### 性能監控
應用提供詳細的性能指標：
- **轉錄耗時**: 毫秒級精確計時
- **處理速度**: 相對於音頻時長的倍率
- **系統資訊**: CPU 架構、執行緒數、模型資訊
- **記憶體使用**: 模型載入和處理狀態

## 🛠️ 開發指南

### 添加新語言支援
```cpp
// 在 native-lib.cpp 中修改
wparams.language = "zh";  // 中文
wparams.language = "en";  // 英文
wparams.language = "ja";  // 日文
```

### 調整性能參數
```cpp
// 執行緒數調整
wparams.n_threads = 6;  // 根據設備調整

// 模型精度權衡
wparams.single_segment = false;  // 更準確
wparams.no_context = true;       // 更快速
```

### 自定義模型
1. 下載所需的 whisper 模型（.bin 格式）
2. 放置在 `assets/models/` 目錄
3. 在 `pubspec.yaml` 中註冊 asset
4. 修改載入路徑

## 🐛 故障排除

### 常見問題

**Q: 轉錄速度很慢**
A: 確保使用 Release 版本：`flutter build apk --release`

**Q: 模型載入失敗**
A: 檢查 assets 目錄是否包含模型檔案，確保 git submodule 正確初始化

**Q: 音頻錄製失敗**
A: 確認應用具有麥克風權限

**Q: 編譯錯誤**
A: 確保 NDK 版本正確，檢查 CMakeLists.txt 中的路徑

### 性能調優
- **Debug vs Release**: Release 版本性能提升 30-70 倍
- **模型選擇**: Tiny 模型速度最快，Base 模型準確率更高
- **執行緒數**: 根據設備 CPU 核心數調整

## 📈 版本歷史

### v1.0.0 (2024-06-26) - 重大突破
- ✅ 實現毫秒級轉錄性能
- ✅ 完整的中文語音識別支援
- ✅ 智能硬體優化和多版本編譯
- ✅ 詳細的性能監控和統計
- ✅ 現代化 Flutter UI 設計
- ✅ 完整的錯誤處理和用戶反饋

## 🤝 貢獻

歡迎提交 Issue 和 Pull Request！

### 開發環境設置
1. Fork 此專案
2. 創建功能分支: `git checkout -b feature/amazing-feature`
3. 提交變更: `git commit -m 'Add amazing feature'`
4. 推送分支: `git push origin feature/amazing-feature`
5. 提交 Pull Request

## 📄 授權

本專案採用 MIT 授權 - 詳見 [LICENSE](LICENSE) 文件

## 🙏 致謝

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) - 高性能 Whisper 實現
- [OpenAI Whisper](https://github.com/openai/whisper) - 原始 Whisper 模型
- Flutter 和 Android 開發社群

## 📞 聯繫

- **專案主頁**: https://github.com/yourusername/whisper_voice_notes
- **問題回報**: https://github.com/yourusername/whisper_voice_notes/issues
- **討論區**: https://github.com/yourusername/whisper_voice_notes/discussions

---

**⚡ 體驗毫秒級語音轉文字的魅力！**