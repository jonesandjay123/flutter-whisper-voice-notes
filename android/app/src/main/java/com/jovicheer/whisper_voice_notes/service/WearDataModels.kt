package com.jovicheer.whisper_voice_notes.service

// 手錶發送過來的請求
data class WearSyncRequest(
    val requestId: String,
    val lastSyncTimestamp: Long,
    val timestamp: Long
)

// 手機回傳給手錶的回應
data class WearSyncResponse(
    val success: Boolean,
    val records: List<WearTranscriptionRecord>,
    val requestId: String,
    val timestamp: Long
)

// 用於通訊的筆記資料結構
data class WearTranscriptionRecord(
    val id: String,
    val text: String,
    val timestamp: Long,
    val isImportant: Boolean = false,
    val duration: Long = 0L,
    val isSynced: Boolean = true
) 