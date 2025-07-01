package com.jovicheer.whisper_voice_notes.service

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import kotlinx.coroutines.*
import kotlinx.coroutines.tasks.await

/**
 * 手機端 WearOS 通訊服務
 */
class PhoneWearCommunicationService : WearableListenerService() {
    
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    companion object {
        private const val LOG_TAG = "PhoneWearComm"
        private const val NOTES_SYNC_REQUEST_PATH = "/whisper/sync_request"
        private const val SYNC_RESPONSE_PATH = "/whisper/sync_response"
    }
    
    override fun onMessageReceived(messageEvent: MessageEvent) {
        super.onMessageReceived(messageEvent)
        
        Log.d(LOG_TAG, "=== Message received ===")
        Log.d(LOG_TAG, "Path: ${messageEvent.path}")
        Log.d(LOG_TAG, "Source: ${messageEvent.sourceNodeId}")
        Log.d(LOG_TAG, "Data: ${String(messageEvent.data, Charsets.UTF_8)}")
        
        if (messageEvent.path == NOTES_SYNC_REQUEST_PATH) {
            Log.i(LOG_TAG, "Processing NOTES_SYNC_REQUEST...")
            scope.launch {
                try {
                    handleSyncRequest(messageEvent.sourceNodeId)
                } catch (e: Exception) {
                    Log.e(LOG_TAG, "Failed to handle sync request and send response", e)
                }
            }
        } else {
            Log.w(LOG_TAG, "Unknown message path: ${messageEvent.path}")
        }
    }
    
    private suspend fun handleSyncRequest(clientNodeId: String) {
        Log.d(LOG_TAG, "Handling sync request from node $clientNodeId")
        val notesJson = getNotesJsonFromSharedPreferences()
        Log.d(LOG_TAG, "Service: Got notes from SharedPreferences: $notesJson")
        sendMessage(clientNodeId, SYNC_RESPONSE_PATH, notesJson.toByteArray(Charsets.UTF_8))
    }
    
    private fun getNotesJsonFromSharedPreferences(): String {
        Log.d(LOG_TAG, "getNotesJsonFromSharedPreferences: Attempting to get notes.")
        try {
            val sharedPreferences: SharedPreferences = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            
            // 先列出所有可用的keys以便除錯
            val allKeys = sharedPreferences.all.keys
            Log.d(LOG_TAG, "所有可用的SharedPreferences keys: $allKeys")
            
            // 詳細檢查每個key的值
            allKeys.forEach { key ->
                val value = sharedPreferences.all[key]
                Log.d(LOG_TAG, "Key: $key, Value type: ${value?.javaClass?.simpleName}, Value: $value")
            }
            
            // 使用正確的 key - Flutter 端使用 'transcription_records'
            val notesJson = sharedPreferences.getString("transcription_records", null)
            
            if (notesJson != null) {
                Log.d(LOG_TAG, "getNotesJsonFromSharedPreferences: Successfully retrieved JSON string from flutter.transcription_records")
                Log.d(LOG_TAG, "JSON content: $notesJson")
                return notesJson
            }
            
            // 嘗試不帶前綴的key
            val directNotesJson = sharedPreferences.getString("transcription_records", null)
            if (directNotesJson != null) {
                Log.d(LOG_TAG, "getNotesJsonFromSharedPreferences: Found direct key transcription_records.")
                Log.d(LOG_TAG, "JSON content: $directNotesJson")
                return directNotesJson
            }
            
            // Fallback for very old key format
            val legacyNotesJson = sharedPreferences.all.entries
                .firstOrNull { it.key.contains("transcription_records") }
                ?.value as? String
            
            if (legacyNotesJson != null) {
                Log.d(LOG_TAG, "getNotesJsonFromSharedPreferences: Found legacy notes key containing transcription_records.")
                Log.d(LOG_TAG, "JSON content: $legacyNotesJson")
                return legacyNotesJson
            }
            
            Log.w(LOG_TAG, "getNotesJsonFromSharedPreferences: No notes key found. Returning empty list.")
            return "[]"
        } catch (e: Exception) {
            Log.e(LOG_TAG, "getNotesJsonFromSharedPreferences: Error reading SharedPreferences", e)
            return "[]"
        }
    }
    
    private suspend fun sendMessage(nodeId: String, path: String, data: ByteArray) {
        try {
            Wearable.getMessageClient(this).sendMessage(nodeId, path, data).await()
            Log.i(LOG_TAG, "Message sent to $nodeId successfully")
        } catch (e: Exception) {
            Log.e(LOG_TAG, "Error sending message to $nodeId", e)
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
        Log.i(LOG_TAG, "PhoneWearCommunicationService destroyed")
    }
} 