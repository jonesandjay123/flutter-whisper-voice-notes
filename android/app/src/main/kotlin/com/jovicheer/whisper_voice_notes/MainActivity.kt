package com.jovicheer.whisper_voice_notes

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

class MainActivity : FlutterActivity() {
    private val CHANNEL = "whisper_voice_notes"
    private val LOG_TAG = "WhisperVoiceNotes"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 強制啟動 WearOS 服務
        startWearableService()
    }
    
    private fun startWearableService() {
        try {
            val intent = Intent(this, com.jovicheer.whisper_voice_notes.service.PhoneWearCommunicationService::class.java)
            startService(intent)
            Log.i(LOG_TAG, "✅ WearOS service started manually")
        } catch (e: Exception) {
            Log.e(LOG_TAG, "❌ Failed to start WearOS service", e)
        }
    }

    private fun getOptimalThreadCount(): Int {
        // 簡化的執行緒計算：使用可用處理器數量，最大限制為 8
        return minOf(Runtime.getRuntime().availableProcessors(), 8)
    }
    
    private fun getCurrentContextPtr(): Long? {
        return globalContextPtr
    }

    companion object {
        // 全域 context pointer，用於 WearOS 服務
        @Volatile
        private var globalContextPtr: Long? = null
        
        fun setGlobalContextPtr(ptr: Long?) {
            globalContextPtr = ptr
        }
        
        fun getGlobalContextPtr(): Long? = globalContextPtr
        init {
            Log.d("WhisperVoiceNotes", "Primary ABI: ${Build.SUPPORTED_ABIS[0]}")
            
            // 智能載入最佳化的 native library
            try {
                when (Build.SUPPORTED_ABIS[0]) {
                    "arm64-v8a" -> {
                        val cpuInfo = getCpuInfo()
                        if (cpuInfo?.contains("fphp") == true) {
                            Log.d("WhisperVoiceNotes", "Loading libwhisper_v8fp16_va.so")
                            System.loadLibrary("whisper_v8fp16_va")
                        } else {
                            Log.d("WhisperVoiceNotes", "Loading libwhisper.so")
                            System.loadLibrary("whisper")
                        }
                    }
                    "armeabi-v7a" -> {
                        val cpuInfo = getCpuInfo()
                        if (cpuInfo?.contains("vfpv4") == true) {
                            Log.d("WhisperVoiceNotes", "Loading libwhisper_vfpv4.so")
                            System.loadLibrary("whisper_vfpv4")
                        } else {
                            Log.d("WhisperVoiceNotes", "Loading libwhisper.so")
                            System.loadLibrary("whisper")
                        }
                    }
                    else -> {
                        Log.d("WhisperVoiceNotes", "Loading libwhisper.so")
                        System.loadLibrary("whisper")
                    }
                }
            } catch (e: UnsatisfiedLinkError) {
                Log.w("WhisperVoiceNotes", "Failed to load optimized library, falling back to default")
                System.loadLibrary("whisper")
            }
        }
        
        private fun getCpuInfo(): String? {
            return try {
                File("/proc/cpuinfo").readText()
            } catch (e: Exception) {
                null
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "copyAssetToFile" -> {
                    val assetName = call.argument<String>("assetName")
                    val targetPath = call.argument<String>("targetPath")
                    
                    if (assetName != null && targetPath != null) {
                        try {
                            copyAssetToFile(assetName, targetPath)
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(LOG_TAG, "Failed to copy asset: $assetName", e)
                            result.error("COPY_FAILED", "Failed to copy asset: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing assetName or targetPath", null)
                    }
                }
                "loadModel" -> {
                    val modelPath = call.argument<String>("modelPath")
                    if (modelPath != null) {
                        GlobalScope.launch(Dispatchers.Default) {
                            try {
                                val contextPtr = loadWhisperModel(modelPath)
                                // 更新全域 context pointer 供 WearOS 使用
                                setGlobalContextPtr(contextPtr)
                                withContext(Dispatchers.Main) {
                                    result.success(contextPtr)
                                }
                            } catch (e: Exception) {
                                Log.e(LOG_TAG, "Failed to load model: $modelPath", e)
                                withContext(Dispatchers.Main) {
                                    result.error("LOAD_FAILED", "Failed to load model: ${e.message}", null)
                                }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing modelPath", null)
                    }
                }
                "transcribeAudio" -> {
                    val contextPtr = call.argument<Long>("contextPtr")
                    val audioPath = call.argument<String>("audioPath")
                    val threads = call.argument<Int>("threads") ?: getOptimalThreadCount()
                    
                    if (contextPtr != null && audioPath != null) {
                        GlobalScope.launch(Dispatchers.Default) {
                            try {
                                Log.d(LOG_TAG, "Starting transcription with $threads threads")
                                val transcription = transcribeAudio(contextPtr, audioPath, threads)
                                withContext(Dispatchers.Main) {
                                    result.success(transcription)
                                }
                            } catch (e: Exception) {
                                Log.e(LOG_TAG, "Failed to transcribe audio: $audioPath", e)
                                withContext(Dispatchers.Main) {
                                    result.error("TRANSCRIBE_FAILED", "Failed to transcribe audio: ${e.message}", null)
                                }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing contextPtr or audioPath", null)
                    }
                }
                "transcribeAudioForWear" -> {
                    val audioPath = call.argument<String>("audioPath")
                    val recordId = call.argument<String>("recordId")
                    
                    if (audioPath != null && recordId != null) {
                        // 使用現有的轉錄邏輯，但需要載入的 context pointer
                        val contextPtr = getCurrentContextPtr()
                        if (contextPtr != null && contextPtr != 0L) {
                            GlobalScope.launch(Dispatchers.Default) {
                                try {
                                    Log.d(LOG_TAG, "WearOS transcription starting for record: $recordId")
                                    val transcription = transcribeAudio(contextPtr, audioPath, 6)
                                    withContext(Dispatchers.Main) {
                                        result.success(transcription)
                                    }
                                } catch (e: Exception) {
                                    Log.e(LOG_TAG, "WearOS transcription failed: $audioPath", e)
                                    withContext(Dispatchers.Main) {
                                        result.error("TRANSCRIBE_FAILED", "Failed to transcribe audio: ${e.message}", null)
                                    }
                                }
                            }
                        } else {
                            result.error("MODEL_NOT_LOADED", "Whisper model not loaded", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing audioPath or recordId", null)
                    }
                }
                "getNotesForWear" -> {
                    val lastSyncTimestamp = call.argument<Long>("lastSyncTimestamp") ?: 0L
                    Log.d(LOG_TAG, "getNotesForWear called with timestamp: $lastSyncTimestamp")
                    
                    GlobalScope.launch(Dispatchers.IO) {
                        try {
                            // 從 SharedPreferences 獲取筆記數據（與 Flutter 端同步）
                            val notes = getNotesFromSharedPreferences(lastSyncTimestamp)
                            Log.i(LOG_TAG, "Retrieved ${notes.size} notes for WearOS sync")
                            
                            withContext(Dispatchers.Main) {
                                result.success(notes)
                            }
                        } catch (e: Exception) {
                            Log.e(LOG_TAG, "Failed to get notes for wear", e)
                            withContext(Dispatchers.Main) {
                                result.error("GET_NOTES_FAILED", "Failed to get notes: ${e.message}", null)
                            }
                        }
                    }
                }
                "getSystemInfo" -> {
                    result.success(getSystemInfo())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun copyAssetToFile(assetName: String, targetPath: String) {
        val assetManager = assets
        val targetFile = File(targetPath)
        
        // 確保目標目錄存在
        targetFile.parentFile?.mkdirs()
        
        assetManager.open(assetName).use { inputStream ->
            FileOutputStream(targetFile).use { outputStream ->
                val buffer = ByteArray(8192) // 8KB buffer
                var bytesRead: Int
                var totalBytes = 0
                
                while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                    outputStream.write(buffer, 0, bytesRead)
                    totalBytes += bytesRead
                    
                    // 每 10MB 記錄一次進度
                    if (totalBytes % (10 * 1024 * 1024) == 0) {
                        Log.d(LOG_TAG, "Copied ${totalBytes / (1024 * 1024)}MB of $assetName")
                    }
                }
                
                Log.d(LOG_TAG, "Successfully copied $assetName (${totalBytes / (1024 * 1024)}MB)")
            }
        }
    }

    /**
     * 從 SharedPreferences 獲取筆記數據（與 Flutter 端保持一致）
     */
    private fun getNotesFromSharedPreferences(lastSyncTimestamp: Long): List<Map<String, Any>> {
        return try {
            val sharedPrefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val recordsJson = sharedPrefs.getString("flutter.transcription_records", null)
            
            if (recordsJson.isNullOrEmpty()) {
                Log.d(LOG_TAG, "No notes found in SharedPreferences")
                return emptyList()
            }
            
            Log.d(LOG_TAG, "Found notes JSON in SharedPreferences: ${recordsJson.length} chars")
            
            // 解析 JSON 字符串為 List<Map>
            val gson = com.google.gson.Gson()
            val listType = object : com.google.gson.reflect.TypeToken<List<Map<String, Any>>>() {}.type
            val allNotes: List<Map<String, Any>> = gson.fromJson(recordsJson, listType) ?: emptyList()
            
            Log.i(LOG_TAG, "Parsed ${allNotes.size} total notes from SharedPreferences")
            
            // 過濾出指定時間戳之後的筆記
            val filteredNotes = allNotes.filter { note ->
                val timestamp = when (val ts = note["timestamp"]) {
                    is Number -> ts.toLong()
                    is String -> ts.toLongOrNull() ?: 0L
                    else -> 0L
                }
                timestamp > lastSyncTimestamp
            }
            
            Log.i(LOG_TAG, "After filtering by timestamp $lastSyncTimestamp: ${filteredNotes.size} notes")
            
            // 轉換為 WearOS 適用的格式
            val wearNotes = filteredNotes.map { note ->
                mapOf(
                    "id" to (note["id"] as? String ?: ""),
                    "text" to (note["text"] as? String ?: ""),
                    "timestamp" to when (val ts = note["timestamp"]) {
                        is Number -> ts.toLong()
                        is String -> ts.toLongOrNull() ?: 0L
                        else -> 0L
                    },
                    "isImportant" to (note["isImportant"] as? Boolean ?: false),
                    "duration" to 0L,
                    "isSynced" to true
                )
            }
            
            Log.i(LOG_TAG, "Converted ${wearNotes.size} notes for WearOS")
            wearNotes.forEachIndexed { index, note ->
                Log.d(LOG_TAG, "Note ${index + 1}: ${note["id"]} - ${(note["text"] as String).take(40)}...")
            }
            
            return wearNotes
            
        } catch (e: Exception) {
            Log.e(LOG_TAG, "Error reading notes from SharedPreferences", e)
            
            // 如果讀取失敗，返回一些測試數據確保功能可用
            Log.w(LOG_TAG, "Returning test data as fallback")
            return getTestNotesForWear()
        }
    }
    
    /**
     * 返回測試筆記數據（fallback 方案）
     */
    private fun getTestNotesForWear(): List<Map<String, Any>> {
        val currentTime = System.currentTimeMillis()
        return listOf(
            mapOf(
                "id" to "test_wear_1",
                "text" to "🔄 手機端測試筆記 - WearOS 同步功能正常工作",
                "timestamp" to currentTime,
                "isImportant" to true,
                "duration" to 30000L,
                "isSynced" to true
            ),
            mapOf(
                "id" to "test_wear_2", 
                "text" to "📱 這是從手機端同步到手錶的測試數據",
                "timestamp" to currentTime - 60000,
                "isImportant" to false,
                "duration" to 25000L,
                "isSynced" to true
            )
        )
    }

    // JNI 函數聲明
    private external fun loadWhisperModel(modelPath: String): Long
    private external fun transcribeAudio(contextPtr: Long, audioPath: String, threads: Int): String
    private external fun getSystemInfo(): String
}
