package com.jovicheer.whisper_voice_notes.util

object Constants {
    // Package Name (必須與手錶端一致)
    const val PACKAGE_NAME = "com.jovicheer.whisper_voice_notes"
    
    // WearOS 通訊路徑 (必須與手錶端一致)
    object WearMessagePaths {
        const val AUDIO_FILE = "/whisper/audio"
        const val TRANSCRIPTION_RESULT = "/whisper/result"
        const val NOTES_SYNC_REQUEST = "/whisper/sync_request"
        const val NOTES_SYNC_RESPONSE = "/whisper/sync_response"
        const val CONNECTION_STATUS = "/whisper/connection"
        const val HEARTBEAT = "/whisper/heartbeat"
    }
    
    // 音檔配置 (必須與手錶端一致)
    object AudioConfig {
        const val SAMPLE_RATE = 16000
        const val MAX_DURATION_MS = 60 * 1000L
        const val MAX_FILE_SIZE_BYTES = 500 * 1024
    }
    
    // Whisper 配置
    object WhisperConfig {
        const val LANGUAGE = "zh-TW"  // 繁體中文
        const val THREADS = 6
    }
} 