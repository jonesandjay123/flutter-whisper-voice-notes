package com.jovicheer.whisper_voice_notes.data.model

import java.util.UUID

/**
 * 轉錄記錄 (與 Flutter 端一致)
 */
data class TranscriptionRecord(
    val id: String = UUID.randomUUID().toString(),
    val text: String,
    val timestamp: Long = System.currentTimeMillis(),
    val isImportant: Boolean = false,
    val duration: Long = 0L,
    val isSynced: Boolean = true  // 手機端預設為已同步
) {
    /**
     * 轉換為與 Flutter 一致的 Map 格式
     */
    fun toMap(): Map<String, Any> {
        return mapOf(
            "id" to id,
            "text" to text,
            "timestamp" to timestamp,
            "isImportant" to isImportant
        )
    }
    
    companion object {
        /**
         * 從 Map 建立 TranscriptionRecord（用於 Flutter 整合）
         */
        fun fromMap(map: Map<String, Any>): TranscriptionRecord {
            return TranscriptionRecord(
                id = map["id"] as? String ?: UUID.randomUUID().toString(),
                text = map["text"] as? String ?: "",
                timestamp = when (val ts = map["timestamp"]) {
                    is Number -> ts.toLong()
                    is String -> ts.toLongOrNull() ?: System.currentTimeMillis()
                    else -> System.currentTimeMillis()
                },
                isImportant = map["isImportant"] as? Boolean ?: false,
                duration = when (val dur = map["duration"]) {
                    is Number -> dur.toLong()
                    is String -> dur.toLongOrNull() ?: 0L
                    else -> 0L
                },
                isSynced = map["isSynced"] as? Boolean ?: true
            )
        }
    }
}

/**
 * 轉錄結果 (發送給手錶端)
 */
data class TranscriptionResult(
    val success: Boolean,
    val text: String,
    val timestamp: Long,
    val recordId: String,
    val error: String? = null
)

/**
 * 同步請求 (從手錶端接收)
 */
data class SyncRequest(
    val lastSyncTimestamp: Long,
    val requestId: String = UUID.randomUUID().toString()
)

/**
 * 同步回應 (發送給手錶端)
 */
data class SyncResponse(
    val success: Boolean,
    val records: List<TranscriptionRecord>,
    val timestamp: Long,
    val requestId: String,
    val error: String? = null
)

/**
 * 連接狀態
 */
data class ConnectionStatus(
    val isConnected: Boolean,
    val deviceName: String?,
    val lastConnectedTime: Long?
) 