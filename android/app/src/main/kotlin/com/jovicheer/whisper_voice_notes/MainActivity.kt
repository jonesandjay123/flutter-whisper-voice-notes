package com.jovicheer.whisper_voice_notes

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

class MainActivity : FlutterActivity() {
    private val CHANNEL = "whisper_voice_notes"
    private val LOG_TAG = "WhisperVoiceNotes"

    private fun getOptimalThreadCount(): Int {
        // 簡化的執行緒計算：使用可用處理器數量，最大限制為 8
        return minOf(Runtime.getRuntime().availableProcessors(), 8)
    }

    companion object {
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

    // JNI 函數聲明
    private external fun loadWhisperModel(modelPath: String): Long
    private external fun transcribeAudio(contextPtr: Long, audioPath: String, threads: Int): String
    private external fun getSystemInfo(): String
}
