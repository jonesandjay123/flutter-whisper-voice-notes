# 開發技術筆記

## 🎯 專案狀態總結

### ✅ 已完成的里程碑

#### 1. **JNI 橋接成功建立** (2024年6月25日)
- Flutter → Kotlin → JNI → C++ 完整通道打通
- MethodChannel 雙向通訊驗證完成
- 測試用 stub 函式正常運作

#### 2. **whisper.cpp 官方整合完成** (2024年6月25日) 🎉
- ✅ **Git Submodule 成功整合** - 使用 `third_party/whisper.cpp/`
- ✅ **手動檔案清理** - 移除 29 個手動複製的檔案
- ✅ **CMakeLists.txt 重構** - 基於官方 Android 範例
- ✅ **GGML 自動依賴** - FetchContent 自動處理
- ✅ **ARM 優化全開** - NEON, FMA, OpenMP, REPACK 全部啟用
- ✅ **whisper.h API 可用** - 可以呼叫完整 whisper 功能庫

### 🔍 whisper.cpp 官方整合技術細節

#### 📊 **整合成功的技術證據**
```log
編譯時間：22.8s (無錯誤)
系統資訊：WHISPER : COREML = 0 | OPENVINO = 0 | CPU : NEON = 1 | ARM_FMA = 1 | OPENMP = 1 | REPACK = 1
✅ NEON = 1     - ARM NEON SIMD 指令集啟用 (向量化計算)
✅ ARM_FMA = 1  - Fused Multiply-Add 指令啟用 (融合乘加運算)
✅ OPENMP = 1   - OpenMP 多執行緒並行處理啟用
✅ REPACK = 1   - 記憶體重組優化啟用 (提升快取效率)
```

#### 🏗️ **官方整合架構 vs 手動整合對比**

| 項目 | 手動整合 (舊) | 官方整合 (新) | 改善 |
|------|---------------|---------------|------|
| **檔案管理** | 手動複製 29 個檔案 | Git Submodule | 版本控制 ✅ |
| **依賴處理** | 手動解決編譯錯誤 | FetchContent 自動 | 零配置 ✅ |
| **編譯設定** | 自製 CMakeLists.txt | 官方標準配置 | 最佳化 ✅ |
| **更新維護** | 重新手動複製 | `git submodule update` | 一鍵更新 ✅ |
| **ARM 優化** | 部分啟用 | 完整啟用 | 性能提升 ✅ |

#### 📁 **新的檔案結構**
```
whisper_voice_notes/
├── android/app/src/main/cpp/
│   ├── native-lib.cpp              # 我們的 JNI 實作
│   └── CMakeLists.txt              # 官方標準編譯設定
├── third_party/
│   └── whisper.cpp/                # Git Submodule (24.13 MiB)
│       ├── src/whisper.cpp         # 主要 Whisper 實作
│       ├── include/whisper.h       # API 介面
│       ├── ggml/                   # GGML 數學函式庫
│       └── examples/whisper.android/ # 官方 Android 範例
└── .gitmodules                     # Submodule 設定
```

### 🔧 **關鍵技術決策記錄**

#### **決策 1: Git Submodule vs 手動複製**
- **選擇**: Git Submodule
- **理由**: 版本控制、自動更新、避免檔案管理複雜度
- **實作**: `git submodule add https://github.com/ggml-org/whisper.cpp.git third_party/whisper.cpp`

#### **決策 2: CMakeLists.txt 設計**
- **選擇**: 基於官方 `examples/whisper.android/lib/src/main/jni/whisper/CMakeLists.txt`
- **關鍵配置**:
  ```cmake
  set(WHISPER_LIB_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../third_party/whisper.cpp)
  FetchContent_Declare(ggml SOURCE_DIR ${WHISPER_LIB_DIR}/ggml)
  target_compile_definitions(native-lib PUBLIC GGML_USE_CPU)
  ```

#### **決策 3: JNI 介面設計**
- **保持現有**: `Java_com_jovicheer_whisper_1voice_1notes_MainActivity_runWhisper`
- **新增功能**: 加入 `whisper_print_system_info()` 驗證整合
- **未來擴展**: 準備加入真正的轉錄函式

### 🚀 **下一階段技術準備**

#### **第三階段：基礎語音辨識 - 技術實作細節**

##### **A. 模型載入系統**
```cpp
// 計劃實作的 JNI 函式
JNIEXPORT jlong JNICALL 
Java_com_jovicheer_whisper_1voice_1notes_MainActivity_initWhisperContext
(JNIEnv *env, jobject thiz, jstring modelPath) {
    const char *model_path_chars = env->GetStringUTFChars(modelPath, NULL);
    
    // 使用官方 API
    struct whisper_context_params cparams = whisper_context_default_params();
    struct whisper_context *ctx = whisper_init_from_file_with_params(model_path_chars, cparams);
    
    env->ReleaseStringUTFChars(modelPath, model_path_chars);
    return (jlong) ctx;  // 回傳 context 指標
}
```

##### **B. 轉錄功能實作**
```cpp
// 基於官方範例的轉錄函式
JNIEXPORT jstring JNICALL 
Java_com_jovicheer_whisper_1voice_1notes_MainActivity_transcribeAudio
(JNIEnv *env, jobject thiz, jlong contextPtr, jfloatArray audioData, jint numThreads) {
    
    struct whisper_context *ctx = (struct whisper_context *) contextPtr;
    jfloat *audio_data_arr = env->GetFloatArrayElements(audioData, NULL);
    const jsize audio_data_length = env->GetArrayLength(audioData);
    
    // 設定轉錄參數
    struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.n_threads = numThreads;
    params.language = "zh";  // 支援中文
    params.translate = false;
    
    // 執行轉錄
    if (whisper_full(ctx, params, audio_data_arr, audio_data_length) != 0) {
        // 錯誤處理
        return env->NewStringUTF("轉錄失敗");
    }
    
    // 收集結果
    std::string result;
    const int n_segments = whisper_full_n_segments(ctx);
    for (int i = 0; i < n_segments; ++i) {
        const char *text = whisper_full_get_segment_text(ctx, i);
        result += text;
    }
    
    env->ReleaseFloatArrayElements(audioData, audio_data_arr, JNI_ABORT);
    return env->NewStringUTF(result.c_str());
}
```

##### **C. Asset 管理系統**
```kotlin
// Kotlin 端模型管理
class WhisperModelManager(private val context: Context) {
    
    suspend fun copyModelFromAssets(modelName: String): String = withContext(Dispatchers.IO) {
        val assetManager = context.assets
        val modelFile = File(context.filesDir, modelName)
        
        if (!modelFile.exists()) {
            assetManager.open("models/$modelName").use { input ->
                modelFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
        }
        
        modelFile.absolutePath
    }
}
```

### 🔮 **技術路線時程規劃**

#### **本週 (6/25-6/30)：基礎轉錄功能**
- [ ] 下載 `ggml-base.bin` 模型 (148MB)
- [ ] 實作 `initWhisperContext` JNI 函式
- [ ] 實作 `transcribeAudio` JNI 函式
- [ ] Asset 模型載入機制
- [ ] 基本錯誤處理

#### **下週 (7/1-7/7)：錄音整合**
- [ ] 評估 Flutter 錄音插件
- [ ] 實作錄音 → WAV 轉換
- [ ] 整合錄音 + 轉錄流程
- [ ] UI 改善

#### **第三週 (7/8-7/14)：性能優化**
- [ ] VAD 模型整合
- [ ] 多執行緒優化
- [ ] 記憶體使用監控
- [ ] 長音檔分段處理

### 🛠️ **開發環境與工具**

#### **建議的開發工具鏈**
```bash
# 模型下載腳本 (未來使用)
./third_party/whisper.cpp/models/download-ggml-model.sh base

# VAD 模型下載
./third_party/whisper.cpp/models/download-vad-model.sh silero-v5.1.2

# 性能測試
./third_party/whisper.cpp/build/bin/bench -m models/ggml-base.bin
```

#### **除錯與監控**
- **記憶體**: Android Studio Profiler
- **CPU**: `top -p $(pgrep whisper_voice_notes)`
- **Log**: `adb logcat | grep -E "(WhisperJNI|MainActivity)"`

### 📚 **學習資源更新**

#### **新加入的重要參考**
- **官方 Android 範例**: `third_party/whisper.cpp/examples/whisper.android/`
- **JNI 實作範例**: `third_party/whisper.cpp/examples/whisper.android/lib/src/main/jni/whisper/jni.c`
- **CMake 設定範例**: 對應的 `CMakeLists.txt`

### 🚧 **已知技術挑戰與解決方案**

#### **已解決 ✅**
1. **編譯複雜度** → Git Submodule + 官方 CMake
2. **檔案管理** → 自動化依賴管理
3. **ARM 優化** → 官方最佳化設定

#### **待解決 🔄**
1. **APK 大小**: 計劃使用 App Bundle + 動態模型下載
2. **首次載入**: 實作進度顯示 + 背景載入
3. **記憶體管理**: Context 生命週期管理

### 📝 **開發日誌**

#### **2024-06-25 (今日完成)**
- ✅ **上午**: 發現手動整合的限制和複雜度
- ✅ **下午**: 研究官方 whisper.cpp 專案結構 
- ✅ **傍晚**: 實作 Git Submodule 整合
  - 清理 29 個手動複製檔案
  - 加入 `third_party/whisper.cpp/` submodule
  - 重構 CMakeLists.txt (基於官方範例)
  - 更新 native-lib.cpp 加入 `whisper.h`
- ✅ **測試結果**: 22.8s 編譯成功，ARM 優化全開

#### **明日開發重點 (2024-06-26)**
1. **模型準備**: 下載並整合 ggml-base.bin
2. **JNI 擴展**: 實作真正的轉錄函式
3. **Asset 管理**: 模型載入機制
4. **Flutter 端**: WhisperService 類別設計

---

## 💡 **核心原則與經驗總結**

### ✨ **成功關鍵因素**
1. **使用官方標準** - 避免重造輪子，直接採用官方最佳實踐
2. **漸進式整合** - 先確保基礎架構穩固，再加入複雜功能
3. **充分測試驗證** - 每個階段都有明確的成功指標
4. **詳細文檔記錄** - 記錄決策過程和技術細節

### 🎯 **下階段關鍵成功指標**
- [ ] **模型載入** < 5秒
- [ ] **轉錄準確度** > 90% (中文)
- [ ] **記憶體使用** < 500MB
- [ ] **APK 大小增量** < 200MB

**💫 當前狀態：whisper.cpp 官方整合完成，基礎架構非常穩固，準備進入實用功能開發階段！** 