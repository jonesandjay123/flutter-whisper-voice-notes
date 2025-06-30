# 📱⌚️ WearOS 手錶對接指南

## 🎯 目標
創建一個 WearOS 手錶應用程序，與現有的手機 Whisper 語音筆記應用程序對接，實現數據同步顯示。

## 📋 重要前提條件

### 1. 專案命名規範 (⚠️ 非常重要)
**手錶端專案必須使用相同的套件名稱前綴**：
```
手機端：com.jovicheer.whisper_voice_notes
手錶端：com.jovicheer.whisper_voice_notes_wear
```

### 2. 開發環境要求
- Android Studio (最新版本)
- WearOS 模擬器或實體手錶
- 與手機端相同的 Kotlin 版本
- 目標 API Level 30+

## 🏗️ 手錶端專案結構

### 1. 基本專案設定
```gradle
// build.gradle (app level)
dependencies {
    implementation 'com.google.android.gms:play-services-wearable:18.1.0'
    implementation 'com.google.code.gson:gson:2.10.1'
    implementation 'androidx.wear:wear:1.3.0'
    implementation 'androidx.wear.compose:compose-material:1.2.1'
}
```

### 2. AndroidManifest.xml 設定
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.jovicheer.whisper_voice_notes_wear">
    
    <!-- WearOS 權限 -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    
    <!-- WearOS 功能聲明 -->
    <uses-feature android:name="android.hardware.type.watch" />
    
    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:theme="@android:style/Theme.DeviceDefault">
        
        <!-- 主要活動 -->
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:label="@string/app_name">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
        
        <!-- WearOS 數據監聽服務 -->
        <service android:name=".WearDataService">
            <intent-filter>
                <action android:name="com.google.android.gms.wearable.MESSAGE_RECEIVED" />
                <action android:name="com.google.android.gms.wearable.DATA_CHANGED" />
            </intent-filter>
        </service>
        
    </application>
</manifest>
```

## 📡 數據對接實現

### 1. 數據模型 (與手機端保持一致)
```kotlin
// TranscriptionRecord.kt
data class TranscriptionRecord(
    val id: String,
    val text: String,
    val timestamp: Long,
    val isImportant: Boolean = false,
    val duration: Long = 0L,
    val isSynced: Boolean = true
)

// SyncResponse.kt
data class SyncResponse(
    val success: Boolean,
    val records: List<TranscriptionRecord>,
    val requestId: String,
    val timestamp: Long
)
```

### 2. WearOS 數據監聽服務
```kotlin
// WearDataService.kt
class WearDataService : WearableListenerService() {
    
    override fun onMessageReceived(messageEvent: MessageEvent) {
        super.onMessageReceived(messageEvent)
        
        Log.d("WearDataService", "收到訊息: ${messageEvent.path}")
        
        when (messageEvent.path) {
            "/whisper/sync_response" -> {
                handleSyncResponse(messageEvent.data)
            }
        }
    }
    
    private fun handleSyncResponse(data: ByteArray) {
        try {
            val json = String(data)
            val response = Gson().fromJson(json, SyncResponse::class.java)
            
            Log.d("WearDataService", "收到 ${response.records.size} 筆記錄")
            
            // 更新本地數據並通知 UI
            NotesRepository.getInstance().updateNotes(response.records)
            
        } catch (e: Exception) {
            Log.e("WearDataService", "解析數據失敗", e)
        }
    }
}
```

### 3. 數據請求功能
```kotlin
// WearDataManager.kt
class WearDataManager(private val context: Context) {
    
    private val wearableClient = Wearable.getMessageClient(context)
    
    fun requestNotesSync(): Task<Void> {
        val request = SyncRequest(
            requestId = UUID.randomUUID().toString(),
            lastSyncTimestamp = getLastSyncTime(),
            timestamp = System.currentTimeMillis()
        )
        
        val json = Gson().toJson(request)
        val data = json.toByteArray()
        
        return wearableClient.sendMessage(
            getPhoneNodeId(),
            "/whisper/sync_request",
            data
        )
    }
    
    private fun getPhoneNodeId(): String {
        // 獲取配對的手機節點 ID
        // 這裡需要實現節點發現邏輯
        return "phone_node_id"
    }
}
```

### 4. UI 顯示組件
```kotlin
// MainActivity.kt
class MainActivity : ComponentActivity() {
    
    private lateinit var dataManager: WearDataManager
    private val notesRepository = NotesRepository.getInstance()
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        dataManager = WearDataManager(this)
        
        setContent {
            NotesListScreen(
                notes = notesRepository.notes.collectAsState().value,
                onSyncClick = { syncNotes() }
            )
        }
    }
    
    private fun syncNotes() {
        dataManager.requestNotesSync()
            .addOnSuccessListener {
                Log.d("MainActivity", "同步請求發送成功")
            }
            .addOnFailureListener { e ->
                Log.e("MainActivity", "同步請求失敗", e)
            }
    }
}
```

## 🎨 UI 設計建議

### 1. 基本列表顯示
```kotlin
@Composable
fun NotesListScreen(
    notes: List<TranscriptionRecord>,
    onSyncClick: () -> Unit
) {
    Column {
        // 同步按鈕
        Button(
            onClick = onSyncClick,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("同步筆記")
        }
        
        // 筆記列表
        LazyColumn {
            items(notes) { note ->
                NoteItem(note = note)
            }
        }
    }
}

@Composable
fun NoteItem(note: TranscriptionRecord) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(4.dp)
    ) {
        Column(
            modifier = Modifier.padding(8.dp)
        ) {
            Text(
                text = note.text,
                style = MaterialTheme.typography.body2,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = formatTimestamp(note.timestamp),
                style = MaterialTheme.typography.caption,
                color = Color.Gray
            )
        }
    }
}
```

## 🔧 測試步驟

### 1. 部署和測試
```bash
# 1. 確保手機和手錶已配對
adb devices

# 2. 部署手錶應用程序
adb -s [手錶設備ID] install app-debug.apk

# 3. 查看日誌
adb -s [手錶設備ID] logcat | grep "WearDataService"
```

### 2. 驗證對接
1. 啟動手機端應用程序
2. 啟動手錶端應用程序
3. 在手錶端點擊「同步筆記」
4. 確認手錶顯示從手機獲取的筆記

## 📚 通訊協議說明

### 手錶 ➡️ 手機
- **路徑**: `/whisper/sync_request`
- **數據**: `SyncRequest` JSON

### 手機 ➡️ 手錶
- **路徑**: `/whisper/sync_response`
- **數據**: `SyncResponse` JSON

## 🚀 下一步開發

1. **建立基本專案** - 使用正確的套件名稱
2. **實現數據監聽** - 添加 WearableListenerService
3. **創建 UI 界面** - 顯示筆記列表
4. **測試對接功能** - 確保能從手機獲取數據
5. **優化用戶體驗** - 添加加載狀態、錯誤處理等

---

**重要提醒**: 套件名稱必須使用 `com.jovicheer.whisper_voice_notes_wear`，這樣才能與手機端正確配對和通訊！

🎯 **成功標準**: 當手錶能夠顯示從手機同步過來的語音筆記時，對接就成功了！ 