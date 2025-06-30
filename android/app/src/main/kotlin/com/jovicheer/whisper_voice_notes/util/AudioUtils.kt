package com.jovicheer.whisper_voice_notes.util

import android.media.MediaMetadataRetriever
import android.util.Log
import java.io.File

/**
 * 音檔處理工具類
 */
object AudioUtils {
    
    private const val TAG = "AudioUtils"
    
    /**
     * 驗證音檔格式
     */
    fun isValidAudioFile(file: File): Boolean {
        return try {
            if (!file.exists() || file.length() == 0L) {
                Log.w(TAG, "Audio file does not exist or is empty")
                return false
            }
            
            if (file.length() > Constants.AudioConfig.MAX_FILE_SIZE_BYTES) {
                Log.w(TAG, "Audio file too large: ${file.length()} bytes")
                return false
            }
            
            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(file.absolutePath)
            
            val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()
            val sampleRate = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_SAMPLERATE)?.toIntOrNull()
            
            retriever.release()
            
            if (duration == null || duration > Constants.AudioConfig.MAX_DURATION_MS) {
                Log.w(TAG, "Audio duration invalid or too long: $duration ms")
                return false
            }
            
            if (sampleRate != null && sampleRate != Constants.AudioConfig.SAMPLE_RATE) {
                Log.w(TAG, "Audio sample rate mismatch: $sampleRate vs ${Constants.AudioConfig.SAMPLE_RATE}")
                // 不要因為取樣率不匹配就拒絕，Whisper 可以處理
            }
            
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error validating audio file", e)
            false
        }
    }
    
    /**
     * 清理暫存音檔
     */
    fun cleanupTempAudioFiles(cacheDir: File) {
        try {
            val tempFiles = cacheDir.listFiles { file ->
                file.name.startsWith("temp_audio_") && file.name.endsWith(".wav")
            }
            
            tempFiles?.forEach { file ->
                try {
                    if (file.delete()) {
                        Log.d(TAG, "Deleted temp audio file: ${file.name}")
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to delete temp audio file: ${file.name}", e)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error cleaning up temp audio files", e)
        }
    }
} 