package com.jovicheer.whisper_voice_notes

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.jovicheer.whisper_voice_notes/whisper"
    private val TAG = "MainActivity"

    companion object {
        // 載入 native library
        init {
            System.loadLibrary("native-lib")
        }
    }

    // JNI 方法宣告
    external fun runWhisper(audioPath: String): String

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "transcribeAudio" -> {
                    try {
                        val audioPath = call.argument<String>("audioPath") ?: ""
                        Log.d(TAG, "Transcribing audio from path: $audioPath")
                        
                        val transcription = runWhisper(audioPath)
                        Log.d(TAG, "Transcription result: $transcription")
                        
                        result.success(transcription)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error during transcription", e)
                        result.error("TRANSCRIPTION_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
