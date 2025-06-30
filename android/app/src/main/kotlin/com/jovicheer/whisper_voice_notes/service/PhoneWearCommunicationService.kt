package com.jovicheer.whisper_voice_notes.service

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.*
import com.google.gson.Gson
import com.jovicheer.whisper_voice_notes.data.model.*
import com.jovicheer.whisper_voice_notes.util.Constants
import com.jovicheer.whisper_voice_notes.util.AudioUtils
import kotlinx.coroutines.*
import kotlinx.coroutines.tasks.await
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/**
 * 手機端 WearOS 通訊服務
 */
class PhoneWearCommunicationService : WearableListenerService() {
    
    companion object {
        private const val TAG = "PhoneWearComm"
        private const val FLUTTER_CHANNEL = "whisper_voice_notes"
    }
    
    private val gson = Gson()
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    // Wearable API 客戶端
    private val dataClient: DataClient by lazy { Wearable.getDataClient(this) }
    private val messageClient: MessageClient by lazy { Wearable.getMessageClient(this) }
    private val nodeClient: NodeClient by lazy { Wearable.getNodeClient(this) }
    
    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "PhoneWearCommunicationService created")
        
        // 清理舊的暫存檔案
        AudioUtils.cleanupTempAudioFiles(cacheDir)
    }
    
    /**
     * 接收來自手錶的資料變更
     */
    override fun onDataChanged(dataEvents: DataEventBuffer) {
        super.onDataChanged(dataEvents)
        
        for (event in dataEvents) {
            if (event.type == DataEvent.TYPE_CHANGED) {
                val item = event.dataItem
                when (item.uri.path) {
                    Constants.WearMessagePaths.AUDIO_FILE -> {
                        handleAudioFileReceived(item)
                    }
                }
            }
        }
    }
    
    /**
     * 接收來自手錶的訊息 - 加強日誌版
     */
    override fun onMessageReceived(messageEvent: MessageEvent) {
        super.onMessageReceived(messageEvent)
        
        Log.d(TAG, "=== Message received ===")
        Log.d(TAG, "Path: ${messageEvent.path}")
        Log.d(TAG, "Source: ${messageEvent.sourceNodeId}")  
        Log.d(TAG, "Data size: ${messageEvent.data.size} bytes")
        
        when (messageEvent.path) {
            Constants.WearMessagePaths.NOTES_SYNC_REQUEST -> {
                Log.i(TAG, "Processing NOTES_SYNC_REQUEST...")
                handleSyncRequest(messageEvent.data, messageEvent.sourceNodeId)
            }
            Constants.WearMessagePaths.HEARTBEAT -> {
                Log.i(TAG, "Processing HEARTBEAT...")
                handleHeartbeat(messageEvent.sourceNodeId, messageEvent.data)
            }
            else -> {
                Log.w(TAG, "Unknown message path: ${messageEvent.path}")
            }
        }
    }
    
    /**
     * 處理接收到的音檔
     */
    private fun handleAudioFileReceived(dataItem: DataItem) {
        serviceScope.launch {
            try {
                val dataMap = DataMapItem.fromDataItem(dataItem).dataMap
                val asset = dataMap.getAsset("audio_data") ?: return@launch
                val recordId = dataMap.getString("record_id") ?: return@launch
                val timestamp = dataMap.getLong("timestamp")
                val fileName = dataMap.getString("file_name") ?: "audio_${recordId}.wav"
                
                Log.i(TAG, "Received audio file: $fileName for record: $recordId")
                
                // 取得音檔資料
                val inputStream = Wearable.getDataClient(this@PhoneWearCommunicationService)
                    .getFdForAsset(asset).await().inputStream
                
                // 儲存音檔到暫存目錄
                val audioFile = File(cacheDir, "temp_audio_$recordId.wav")
                FileOutputStream(audioFile).use { output ->
                    inputStream.copyTo(output)
                }
                
                Log.i(TAG, "Audio file saved: ${audioFile.length()} bytes")
                
                // 驗證音檔
                if (!AudioUtils.isValidAudioFile(audioFile)) {
                    throw Exception("無效的音檔格式")
                }
                
                // 進行語音轉錄
                transcribeAudioWithNativeWhisper(audioFile, recordId) { result ->
                    // 發送轉錄結果回手錶
                    serviceScope.launch {
                        sendTranscriptionResult(result)
                    }
                    
                    // 清理暫存檔案
                    audioFile.delete()
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Error processing audio file", e)
                
                // 發送錯誤結果
                val errorResult = TranscriptionResult(
                    success = false,
                    text = "",
                    timestamp = System.currentTimeMillis(),
                    recordId = "unknown",
                    error = "音檔處理失敗: ${e.message}"
                )
                sendTranscriptionResult(errorResult)
            }
        }
    }
    
    /**
     * 使用本地 Whisper 進行轉錄
     */
    private suspend fun transcribeAudioWithNativeWhisper(
        audioFile: File,
        recordId: String,
        onResult: (TranscriptionResult) -> Unit
    ) {
        withContext(Dispatchers.Main) {
            try {
                Log.i(TAG, "Starting native Whisper transcription for record: $recordId")
                
                // 通過 Flutter Engine 調用本地 Whisper
                val flutterEngine = getFlutterEngine()
                if (flutterEngine != null) {
                    val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FLUTTER_CHANNEL)
                    
                    // 調用 Flutter 端的轉錄方法
                    methodChannel.invokeMethod("transcribeAudioForWear", mapOf(
                        "audioPath" to audioFile.absolutePath,
                        "recordId" to recordId
                    ), object : MethodChannel.Result {
                        override fun success(result: Any?) {
                            val transcriptionText = result as? String ?: ""
                            Log.i(TAG, "Transcription completed: ${transcriptionText.take(50)}...")
                            
                            val transcriptionResult = TranscriptionResult(
                                success = true,
                                text = transcriptionText.trim(),
                                timestamp = System.currentTimeMillis(),
                                recordId = recordId
                            )
                            
                            onResult(transcriptionResult)
                        }
                        
                        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                            Log.e(TAG, "Transcription failed: $errorMessage")
                            
                            val transcriptionResult = TranscriptionResult(
                                success = false,
                                text = "",
                                timestamp = System.currentTimeMillis(),
                                recordId = recordId,
                                error = "轉錄失敗: $errorMessage"
                            )
                            
                            onResult(transcriptionResult)
                        }
                        
                        override fun notImplemented() {
                            Log.e(TAG, "Transcription method not implemented")
                            
                            val transcriptionResult = TranscriptionResult(
                                success = false,
                                text = "",
                                timestamp = System.currentTimeMillis(),
                                recordId = recordId,
                                error = "轉錄方法未實現"
                            )
                            
                            onResult(transcriptionResult)
                        }
                    })
                } else {
                    throw Exception("Flutter Engine 不可用")
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Native Whisper transcription failed for record: $recordId", e)
                
                val transcriptionResult = TranscriptionResult(
                    success = false,
                    text = "",
                    timestamp = System.currentTimeMillis(),
                    recordId = recordId,
                    error = "轉錄失敗: ${e.message}"
                )
                
                onResult(transcriptionResult)
            }
        }
    }
    
    /**
     * 獲取 Flutter Engine 實例
     */
    private fun getFlutterEngine(): FlutterEngine? {
        return try {
            // 嘗試從 Flutter Application 獲取 Engine
            val app = application
            val engineField = app.javaClass.getDeclaredField("flutterEngine")
            engineField.isAccessible = true
            engineField.get(app) as? FlutterEngine
        } catch (e: Exception) {
            Log.w(TAG, "Could not get FlutterEngine: ${e.message}")
            null
        }
    }
    
    /**
     * 處理同步請求 - 超詳細版
     */
    private fun handleSyncRequest(data: ByteArray, sourceNodeId: String) {
        Log.i(TAG, "🔄 === SYNC REQUEST RECEIVED ===")
        Log.i(TAG, "📱 Source node: $sourceNodeId")
        Log.i(TAG, "📦 Data size: ${data.size} bytes")
        
        serviceScope.launch {
            var response: SyncResponse
            
            try {
                // 解析請求
                val json = String(data)
                Log.d(TAG, "📄 Request JSON: $json")
                
                val request = gson.fromJson(json, SyncRequest::class.java)
                Log.i(TAG, "✅ Request parsed successfully:")
                Log.i(TAG, "   - Request ID: ${request.requestId}")
                Log.i(TAG, "   - Last sync timestamp: ${request.lastSyncTimestamp}")
                Log.i(TAG, "   - Last sync time: ${java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date(request.lastSyncTimestamp))}")
                
                // 獲取筆記資料
                Log.i(TAG, "🔍 Fetching notes from database...")
                val notes = getNotesFromFlutter(request.lastSyncTimestamp)
                
                // 建立成功回應
                response = SyncResponse(
                    success = true,
                    records = notes,
                    timestamp = System.currentTimeMillis(),
                    requestId = request.requestId
                )
                
                Log.i(TAG, "✅ SUCCESS: Sync response prepared")
                Log.i(TAG, "   - Records to sync: ${notes.size}")
                Log.i(TAG, "   - Response timestamp: ${response.timestamp}")
                
                if (notes.isNotEmpty()) {
                    Log.i(TAG, "📝 Notes summary:")
                    notes.forEachIndexed { index, note ->
                        Log.i(TAG, "   ${index + 1}. [${note.id}] ${note.text.take(40)}...")
                    }
                } else {
                    Log.w(TAG, "⚠️  No notes to sync!")
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "❌ ERROR handling sync request", e)
                
                // 建立錯誤回應
                response = SyncResponse(
                    success = false,
                    records = emptyList(),
                    timestamp = System.currentTimeMillis(),
                    requestId = "error",
                    error = "同步失敗: ${e.message}"
                )
                
                Log.i(TAG, "🔧 Error response prepared")
            }
            
            // 發送回應到手錶
            try {
                Log.i(TAG, "📤 Sending sync response to watch...")
                sendSyncResponse(response, sourceNodeId)
                Log.i(TAG, "🎉 === SYNC PROCESS COMPLETED ===")
            } catch (e: Exception) {
                Log.e(TAG, "💥 === FAILED TO SEND SYNC RESPONSE ===", e)
            }
        }
    }
    
    /**
     * 簡化版本：從資料庫獲取筆記（推薦）
     */
    private suspend fun getNotesFromFlutter(lastSyncTimestamp: Long): List<TranscriptionRecord> {
        return withContext(Dispatchers.IO) {
            try {
                Log.d(TAG, "Getting notes after timestamp: $lastSyncTimestamp")
                
                // 方案1：直接從資料庫獲取（推薦，先用這個測試）
                val notes = getNotesFromDatabase(lastSyncTimestamp)
                Log.i(TAG, "Got ${notes.size} notes from database")
                return@withContext notes
                
                // 方案2：如果必須用 Flutter，請使用帶超時的版本（暫時註解）
                /*
                return@withContext withTimeout(5000L) {
                    getNotesFromFlutterWithTimeout(lastSyncTimestamp)
                }
                */
                
            } catch (e: Exception) {
                Log.e(TAG, "Error getting notes, returning empty list", e)
                return@withContext emptyList()
            }
        }
    }

    /**
     * 直接從資料庫獲取筆記（臨時測試方案）
     */
    private suspend fun getNotesFromDatabase(lastSyncTimestamp: Long): List<TranscriptionRecord> {
        return try {
            val currentTime = System.currentTimeMillis()
            Log.d(TAG, "Current time: $currentTime, lastSyncTimestamp: $lastSyncTimestamp")
            
            // 確保測試資料總是比 lastSyncTimestamp 新，這樣不會被過濾掉
            val testNotes = listOf(
                TranscriptionRecord(
                    id = "phone_test_1",
                    text = "🏢 手機端測試筆記 1 - 今天的重要會議記錄需要整理",
                    timestamp = currentTime - 300000, // 5分鐘前
                    isImportant = true,
                    duration = 30000L,
                    isSynced = true
                ),
                TranscriptionRecord(
                    id = "phone_test_2", 
                    text = "🛒 手機端測試筆記 2 - 週末購物清單：有機牛奶、全麥麵包、新鮮雞蛋、蘋果",
                    timestamp = currentTime - 180000, // 3分鐘前
                    isImportant = false,
                    duration = 25000L,
                    isSynced = true
                ),
                TranscriptionRecord(
                    id = "phone_test_3",
                    text = "📞 手機端測試筆記 3 - 明天上午十點要記得打電話給王總討論新項目合約細節",
                    timestamp = currentTime - 60000, // 1分鐘前
                    isImportant = true,
                    duration = 45000L,
                    isSynced = true
                ),
                TranscriptionRecord(
                    id = "phone_new_note",
                    text = "⭐ 剛剛創建的最新測試筆記 - 同步時間: ${java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())}",
                    timestamp = currentTime, // 現在
                    isImportant = false,
                    duration = 20000L,
                    isSynced = true
                )
            )
            
            Log.i(TAG, "Generated ${testNotes.size} test notes")
            for (note in testNotes) {
                Log.d(TAG, "Note: ${note.id} - ${note.text.take(30)}... - timestamp: ${note.timestamp}")
            }
            
            // 只返回指定時間戳之後的筆記
            val filteredNotes = testNotes.filter { it.timestamp > lastSyncTimestamp }
            Log.i(TAG, "After filtering by timestamp $lastSyncTimestamp: ${filteredNotes.size} notes remain")
            
            // 確保至少返回一些測試資料（調試用）
            if (filteredNotes.isEmpty()) {
                Log.w(TAG, "No notes after filtering! Returning all test notes for debugging...")
                return testNotes
            }
            
            return filteredNotes
            
        } catch (e: Exception) {
            Log.e(TAG, "Database query failed", e)
            emptyList()
        }
    }
    
    /**
     * 處理心跳訊息
     */
    private fun handleHeartbeat(sourceNodeId: String, data: ByteArray) {
        serviceScope.launch {
            try {
                val message = String(data)
                Log.d(TAG, "Heartbeat received: $message from $sourceNodeId")
                
                // 回應心跳
                messageClient.sendMessage(
                    sourceNodeId,
                    Constants.WearMessagePaths.HEARTBEAT,
                    "pong".toByteArray()
                ).await()
                
            } catch (e: Exception) {
                Log.e(TAG, "Error responding to heartbeat", e)
            }
        }
    }
    
    /**
     * 發送轉錄結果到手錶
     */
    private suspend fun sendTranscriptionResult(result: TranscriptionResult) {
        try {
            val json = gson.toJson(result)
            val connectedNodes = nodeClient.connectedNodes.await()
            
            for (node in connectedNodes) {
                try {
                    messageClient.sendMessage(
                        node.id,
                        Constants.WearMessagePaths.TRANSCRIPTION_RESULT,
                        json.toByteArray()
                    ).await()
                    
                    Log.i(TAG, "Transcription result sent to ${node.displayName}")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to send transcription result to ${node.displayName}", e)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error sending transcription result", e)
        }
    }
    
    /**
     * 發送同步回應到手錶 - 改進版
     */
    private suspend fun sendSyncResponse(response: SyncResponse, targetNodeId: String) {
        try {
            Log.i(TAG, "🚀 Preparing to send sync response...")
            Log.i(TAG, "Target node ID: $targetNodeId")
            Log.i(TAG, "Response records count: ${response.records.size}")
            Log.i(TAG, "Response success: ${response.success}")
            
            // 檢查連接的節點
            val connectedNodes = nodeClient.connectedNodes.await()
            Log.i(TAG, "Connected nodes: ${connectedNodes.size}")
            
            for (node in connectedNodes) {
                Log.d(TAG, "Connected node: ${node.id} - ${node.displayName}")
            }
            
            // 查找目標節點
            val targetNode = connectedNodes.find { it.id == targetNodeId }
            if (targetNode == null) {
                Log.e(TAG, "❌ Target node $targetNodeId not found in connected nodes!")
                return
            }
            
            Log.i(TAG, "✅ Found target node: ${targetNode.displayName}")
            
            // 準備 JSON 資料
            val json = gson.toJson(response)
            Log.d(TAG, "Response JSON: $json")
            Log.i(TAG, "JSON size: ${json.length} characters")
            
            // 顯示要發送的筆記摘要
            Log.i(TAG, "📝 Records to send:")
            response.records.forEachIndexed { index, record ->
                Log.i(TAG, "  ${index + 1}. ${record.id}: ${record.text.take(50)}...")
            }
            
            // 發送訊息
            Log.i(TAG, "📤 Sending message to ${targetNode.displayName}...")
            Log.i(TAG, "Message path: ${Constants.WearMessagePaths.NOTES_SYNC_RESPONSE}")
            
            val task = messageClient.sendMessage(
                targetNodeId,
                Constants.WearMessagePaths.NOTES_SYNC_RESPONSE,
                json.toByteArray()
            )
            
            // 等待發送完成
            task.await()
            
            Log.i(TAG, "🎉 SUCCESS: Sync response sent successfully!")
            Log.i(TAG, "   - Records sent: ${response.records.size}")
            Log.i(TAG, "   - Target: ${targetNode.displayName}")
            Log.i(TAG, "   - Request ID: ${response.requestId}")
            
        } catch (e: Exception) {
            Log.e(TAG, "💥 CRITICAL ERROR sending sync response", e)
            Log.e(TAG, "   - Target node: $targetNodeId")
            Log.e(TAG, "   - Records count: ${response.records.size}")
            Log.e(TAG, "   - Error type: ${e.javaClass.simpleName}")
            Log.e(TAG, "   - Error message: ${e.message}")
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
        AudioUtils.cleanupTempAudioFiles(cacheDir)
        Log.i(TAG, "PhoneWearCommunicationService destroyed")
    }
} 