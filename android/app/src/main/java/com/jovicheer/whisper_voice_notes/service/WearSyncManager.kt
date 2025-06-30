package com.jovicheer.whisper_voice_notes.service

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.gms.wearable.Wearable
import com.google.gson.Gson
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class WearSyncManager(private val context: Context) {

    private val messageClient by lazy { Wearable.getMessageClient(context) }
    private val gson = Gson()
    private var methodChannel: MethodChannel? = null

    companion object {
        private const val TAG = "WearSyncManager"
        const val FLUTTER_CHANNEL = "whisper_voice_notes"
    }

    // 這個方法需要在 MainActivity 中被呼叫以初始化 Channel
    fun initialize(flutterEngine: FlutterEngine) {
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FLUTTER_CHANNEL)
        Log.d(TAG, "MethodChannel initialized")
    }

    fun handleSyncRequest(watchNodeId: String, request: WearSyncRequest) {
        Log.d(TAG, "Handling sync request from node: $watchNodeId")
        
        // 確保 MethodChannel 已經被初始化
        if (methodChannel == null) {
            Log.e(TAG, "MethodChannel not initialized. Call initialize() first.")
            sendErrorResponse(watchNodeId, request.requestId, "Flutter engine not ready")
            return
        }
        
        // 透過 MethodChannel 呼叫 Dart 層的方法
        Handler(Looper.getMainLooper()).post {
            methodChannel?.invokeMethod("getNotesForWear", request.lastSyncTimestamp, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    Log.d(TAG, "Received notes from Flutter: $result")
                    // Flutter 返回的應該是 JSON 格式的字串
                    if (result is String) {
                        try {
                            val records = gson.fromJson(result, Array<WearTranscriptionRecord>::class.java).toList()
                            sendSuccessResponse(watchNodeId, request.requestId, records)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error parsing records from Flutter", e)
                            sendErrorResponse(watchNodeId, request.requestId, "JSON parsing error")
                        }
                    } else {
                         Log.e(TAG, "Unexpected data type from Flutter: ${result?.javaClass?.name}")
                         sendErrorResponse(watchNodeId, request.requestId, "Invalid data from Flutter")
                    }
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                     Log.e(TAG, "Flutter method call failed: $errorCode - $errorMessage")
                     sendErrorResponse(watchNodeId, request.requestId, errorMessage ?: "Unknown error")
                }

                override fun notImplemented() {
                    Log.e(TAG, "Flutter method 'getNotesForWear' not implemented.")
                    sendErrorResponse(watchNodeId, request.requestId, "Method not implemented in Flutter")
                }
            })
        }
    }

    private fun sendSuccessResponse(watchNodeId: String, requestId: String, records: List<WearTranscriptionRecord>) {
        val response = WearSyncResponse(
            success = true,
            records = records,
            requestId = requestId,
            timestamp = System.currentTimeMillis()
        )
        val json = gson.toJson(response)
        val data = json.toByteArray()

        messageClient.sendMessage(watchNodeId, "/whisper/sync_response", data)
            .addOnSuccessListener { Log.d(TAG, "Successfully sent ${records.size} records to watch.") }
            .addOnFailureListener { e -> Log.e(TAG, "Failed to send response to watch.", e) }
    }

    private fun sendErrorResponse(watchNodeId: String, requestId: String, errorMessage: String) {
        val response = WearSyncResponse(
            success = false,
            records = emptyList(),
            requestId = requestId,
            timestamp = System.currentTimeMillis()
        )
        val json = gson.toJson(response)
        val data = json.toByteArray()

        messageClient.sendMessage(watchNodeId, "/whisper/sync_response", data)
             .addOnSuccessListener { Log.d(TAG, "Successfully sent error response to watch.") }
             .addOnFailureListener { e -> Log.e(TAG, "Failed to send error response to watch.", e) }
    }
} 