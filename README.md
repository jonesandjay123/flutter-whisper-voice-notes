# 💡 Whisper 快閃筆記

**AI 驅動的語音靈感記錄應用，支援 WearOS 手錶同步**

使用最新的 whisper.cpp 實現**毫秒級**語音轉文字，專為快速記錄和管理靈感而設計。完全離線運行，保護隱私。

## ✨ 主要特色

### 🧠 快閃筆記系統

- **💡 靈感捕捉**：一鍵錄音，自動轉為文字筆記
- **⭐ 重要性標記**：標記重要想法，快速篩選
- **📱 本地存儲**：所有筆記安全存儲在設備本地
- **🔍 詳細查看**：點擊筆記查看完整內容和創建時間

### ⌚ WearOS 同步功能 (NEW!)

- **📡 手錶同步**：支援與 WearOS 手錶雙向同步筆記
- **🔄 即時更新**：手機端筆記自動同步到手錶
- **📲 離線同步**：通過 WearOS 數據層進行本地同步
- **🎯 輕量設計**：手錶端優化的筆記顯示界面

### 🚀 極致性能

- **⚡ 毫秒級轉錄**：3 秒音頻僅需 1 秒處理時間
- **🎯 智能模型**：Tiny 模型（快速）/ Base 模型（準確）動態切換
- **🔥 實時體驗**：錄音完成自動轉錄，無縫流程

### 🌍 語言支援

- **🇨🇳 中文優化**：針對中文語音識別調優
- **🌐 多語言**：支援 whisper.cpp 的所有語言
- **🔄 自動檢測**：智能語言識別

### 🔒 隱私安全

- **📱 完全離線**：所有處理在本地進行
- **🚫 無網路需求**：不上傳任何音頻或文字數據
- **🔐 數據安全**：筆記僅存儲在設備本地
- **⌚ 本地同步**：手錶同步通過 WearOS 本地數據層進行

### 🎨 現代化設計

- **📱 響應式布局**：適配各種屏幕尺寸
- **🎯 統一界面**：所有功能整合在單一頁面
- **⚡ 流暢動畫**：現代化 Material Design 3

## 🏆 性能表現

### 實測結果（Pixel 8 Pro）

```
音頻時長: 3.12秒
轉錄耗時: 1.02秒
處理速度: 3.06x 實時
準確率: 高（中文語音）
存儲方式: 本地 SharedPreferences
```

### 模型對比

| 模型 | 大小 | 速度   | 準確度   | 適用場景 |
| ---- | ---- | ------ | -------- | -------- |
| Tiny | 31MB | ⚡⚡⚡ | ⭐⭐⭐   | 快速記錄 |
| Base | 57MB | ⚡⚡   | ⭐⭐⭐⭐ | 重要內容 |

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

# Release 版本（最佳性能） - 推薦！
flutter build apk --release
flutter install --release
```

### 🎯 使用說明

#### 基本流程

1. **選擇模型**: 右上角選擇 Tiny（快）或 Base（準確）
2. **錄製想法**: 點擊「錄製想法」按鈕開始錄音
3. **自動轉錄**: 停止錄音後自動轉為文字筆記
4. **管理筆記**: 查看、編輯、刪除、標記重要性

#### 快閃筆記功能

- **📝 查看詳情**: 點擊筆記查看完整內容
- **✏️ 編輯筆記**: 點擊編輯圖標修改內容
- **⭐ 重要標記**: 在詳情頁面標記/取消重要性
- **🗑️ 刪除筆記**: 點擊刪除圖標移除筆記
- **📋 複製內容**: 在詳情頁面複製筆記到剪貼簿

#### 進階功能

- **🔄 模型切換**: 實時切換不同性能的模型
- **📱 響應式界面**: 自動適配不同屏幕尺寸
- **💾 自動保存**: 所有筆記自動本地保存

#### ⌚ WearOS 同步使用指南

1. **配對設備**:
   - 確保手機和 WearOS 手錶已透過 Wear OS 應用配對
   - 兩個設備都需要安裝對應版本的應用程式
2. **手錶端安裝**:

   ```bash
   # 安裝手錶端應用
   adb -s [手錶設備ID] install WhisperVoiceNotesWear.apk
   ```

3. **同步操作**:

   - **手機端**: 正常錄製和管理筆記
   - **手錶端**: 開啟「語音筆記手錶」應用，點擊「同步筆記」
   - **自動同步**: 手錶會自動獲取手機端的最新筆記

4. **支援功能**:

   - ✅ **查看筆記**: 在手錶上瀏覽所有筆記內容
   - ✅ **重要標記**: 手錶端顯示重要筆記的星形標記
   - ✅ **時間排序**: 按最新時間順序顯示筆記
   - ✅ **離線同步**: 無需網路連接，透過 WearOS 本地數據層同步

5. **技術特色**:
   - **即時同步**: 通過 WearOS MessageAPI 實現毫秒級同步
   - **資料一致性**: 使用 SharedPreferences 確保資料同步一致
   - **錯誤恢復**: 內建重試機制和超時處理
   - **輕量設計**: 手錶端針對小螢幕優化，省電高效

## 📁 專案結構

```
whisper_voice_notes/
├── lib/                          # Flutter 應用程式碼
│   ├── main.dart                 # 應用入口
│   └── pages/
│       └── home_page.dart        # 統一主頁面（快閃筆記）
├── android/
│   └── app/src/main/
│       ├── cpp/                  # C++ Native 程式碼
│       │   ├── CMakeLists.txt    # 構建配置
│       │   └── native-lib.cpp    # JNI 接口實現
│       ├── kotlin/               # Android Kotlin 程式碼
│       │   └── MainActivity.kt   # 主 Activity
│       └── service/              # WearOS 通訊服務
│           ├── PhoneWearCommunicationService.kt  # 手機端通訊服務
│           ├── WearSyncManager.kt                 # 同步管理器
│           └── WearSyncManagerHolder.kt           # 單例管理器
├── assets/models/                # Whisper 模型檔案
│   ├── ggml-tiny-q5_1.bin       # Tiny 模型（31MB，預設）
│   └── ggml-base-q5_1.bin       # Base 模型（57MB）
├── third_party/whisper.cpp/     # Whisper.cpp 子模組
└── ../WhisperVoiceNotesWear/     # 配套的 WearOS 應用（獨立專案）
```

## 🔧 技術架構

### 核心特色

- **統一頁面設計**: 所有功能整合在單一主頁面
- **智能狀態管理**: 響應式 UI 狀態同步
- **本地數據持久化**: SharedPreferences 安全存儲
- **模塊化代碼結構**: 清晰的功能分離和常量管理
- **WearOS 雙向同步**: 透過 MessageAPI 實現手錶端同步

### WearOS 通訊架構

```kotlin
// 手機端通訊服務
class PhoneWearCommunicationService : WearableListenerService() {
    // 監聽來自手錶的同步請求
    override fun onMessageReceived(messageEvent: MessageEvent)

    // 從 SharedPreferences 讀取筆記資料
    private fun getNotesJsonFromSharedPreferences(): String

    // 發送筆記資料到手錶
    private suspend fun sendMessage(nodeId: String, path: String, data: ByteArray)
}

// 資料同步流程
手錶端請求 (/whisper/sync_request)
    ↓
手機端接收並處理請求
    ↓
讀取 SharedPreferences 中的筆記資料
    ↓
發送資料到手錶 (/whisper/sync_response)
    ↓
手錶端接收並顯示筆記
```

### 資料格式一致性

```dart
// Flutter 端筆記模型
class TranscriptionRecord {
  String id;              // 唯一標識
  String text;            // 筆記內容
  DateTime timestamp;     // 創建時間
  bool isImportant;       // 重要性標記
}

// SharedPreferences 存儲 key
static const String recordsKey = 'transcription_records';

// WearOS 通訊時的資料轉換
Map<String, dynamic> toWearOSFormat() => {
  'id': id,
  'text': text,
  'timestamp': timestamp.millisecondsSinceEpoch,
  'isImportant': isImportant,
};
```

## 📱 界面設計

### 主界面特色

- **🎙️ 錄音控制**: 醒目的錄音、停止、播放按鈕
- **📋 快閃筆記列表**: 流水號標識，支援重要標記
- **📄 詳細視圖**: 點擊查看完整筆記內容
- **⚙️ 模型選擇**: 右上角下拉選單動態切換

### 響應式設計

- **自適應高度**: 筆記列表根據屏幕大小調整
- **智能間距**: 條件性間距減少空間浪費
- **滾動支援**: 詳細內容支援滾動查看
- **SafeArea**: 避免系統 UI 遮擋

## 🛠️ 開發指南

### 代碼結構最佳實踐

```dart
// 功能模塊分離
// ============ 初始化方法 ============
// ============ 模型相關方法 ============
// ============ 錄音相關方法 ============
// ============ 轉錄相關方法 ============
// ============ 筆記管理方法 ============
// ============ UI 相關方法 ============
// ============ 消息顯示方法 ============
// ============ UI 組件構建方法 ============
```

### 添加新功能

1. **數據模型**: 在 `TranscriptionRecord` 中添加新字段
2. **UI 組件**: 創建新的 `_build*()` 方法
3. **業務邏輯**: 在對應功能模塊中添加方法
4. **常量管理**: 在 `AppConstants` 中添加相關常量

### 性能優化建議

- **Release 構建**: 始終使用 Release 版本測試性能
- **模型選擇**: 根據使用場景選擇合適模型
- **本地存儲**: 合理使用 SharedPreferences 避免過度讀寫

## 📊 版本歷史

### v2.1.0 (2024-12-27) - WearOS 同步功能修正版本

**解決手錶同步問題，實現穩定的雙向同步功能**

#### 🔧 關鍵修正

- ✅ **SharedPreferences Key 修正**: 解決 `notes` vs `transcription_records` key 不匹配問題
- ✅ **資料格式統一**: 改進 JSON 解析邏輯，支援毫秒數和 ISO8601 格式
- ✅ **錯誤處理優化**: 添加 10 秒超時機制和完整的錯誤恢復
- ✅ **應用 ID 分離**: 手錶端使用獨立的應用 ID 避免安裝衝突
- ✅ **詳細日誌輸出**: 添加完整的除錯日誌幫助診斷問題

#### 🛠️ 技術改進

```kotlin
// 修正前：SharedPreferences key 不匹配
val notesJson = sharedPreferences.getString("notes", null) // ❌

// 修正後：使用正確的 Flutter key
val notesJson = sharedPreferences.getString("flutter.transcription_records", null) // ✅
```

#### 📱 手錶端優化

- **WearDataService**: 強化 JSON 解析和 timestamp 處理
- **WearDataManager**: 改進節點連接和超時處理
- **應用配置**: 修正 applicationId 為 `com.jovicheer.whisper_voice_notes.wear`

#### 🧪 測試框架

- 創建完整的測試指南 (`TESTING_GUIDE.md`)
- 提供除錯工具和常見問題解決方案
- 支援並行日誌監控和問題診斷

### v2.0.0 (2024-06-27) - 快閃筆記重構版本

- ✅ **核心重新定位**: 從語音轉錄工具變成快閃筆記應用
- ✅ **統一界面設計**: 整合所有功能到單一主頁面
- ✅ **本地存儲系統**: 實現筆記的持久化保存
- ✅ **重要性標記**: 支援筆記重要性管理
- ✅ **動態模型切換**: 實時切換 Tiny/Base 模型
- ✅ **響應式佈局**: 解決屏幕溢出，適配各種尺寸
- ✅ **代碼重構**: 模塊化架構，提升可維護性

### v1.0.0 (2024-06-26) - 性能突破版本

- ✅ 實現毫秒級轉錄性能
- ✅ 完整的中文語音識別支援
- ✅ 智能硬體優化和多版本編譯
- ✅ 現代化 Flutter UI 設計

## 🎯 未來發展

### 短期計劃 (v2.1.0)

- [ ] 筆記搜索功能
- [ ] 筆記分類標籤
- [ ] 批量操作（批量刪除、導出）
- [ ] 筆記同步備份

### 中期計劃 (v2.2.0)

- [ ] 語音備忘錄功能
- [ ] 筆記分享功能
- [ ] 主題切換（暗色模式）
- [ ] 多語言界面

### 長期規劃 (v3.0.0)

- [ ] AI 智能摘要
- [ ] 語音命令控制
- [ ] 跨平台同步（iOS、Web）
- [ ] 團隊協作功能

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

---

## 💡 設計理念

**「靈感稍縱即逝，用語音快速記錄你的想法！」**

這個應用專為那些需要快速記錄靈感、想法、會議要點的用戶而設計。通過 AI 語音識別技術，讓記錄變得自然而高效，讓每一個閃現的想法都不再錯失。
