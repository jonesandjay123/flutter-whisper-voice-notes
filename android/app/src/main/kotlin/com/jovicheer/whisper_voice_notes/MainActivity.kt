package com.jovicheer.whisper_voice_notes

import android.os.Build
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
import android.content.Context
import android.content.SharedPreferences

class MainActivity : FlutterActivity() {
    private val CHANNEL = "whisper_voice_notes"
    private val LOG_TAG = "WhisperVoiceNotes"

    companion object {
        init {
            try {
                // This is a simplified version of your smart library loader.
                // For now, we'll just load the base library.
                System.loadLibrary("whisper")
                Log.d("WhisperVoiceNotes", "Successfully loaded libwhisper.so")
            } catch (e: UnsatisfiedLinkError) {
                Log.e("WhisperVoiceNotes", "Failed to load native whisper library", e)
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
                            result.error("COPY_FAILED", e.message, null)
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
                                withContext(Dispatchers.Main) { result.success(contextPtr) }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) { result.error("LOAD_FAILED", e.message, null) }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing modelPath", null)
                    }
                }
                "transcribeAudio" -> {
                    val contextPtr = call.argument<Long>("contextPtr")
                    val audioPath = call.argument<String>("audioPath")
                    val threads = call.argument<Int>("threads") ?: 6

                    if (contextPtr != null && audioPath != null) {
                        GlobalScope.launch(Dispatchers.Default) {
                            try {
                                val transcription = transcribeAudio(contextPtr, audioPath, threads)
                                withContext(Dispatchers.Main) { result.success(transcription) }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) { result.error("TRANSCRIBE_FAILED", e.message, null) }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing contextPtr or audioPath", null)
                    }
                }
                "getNotesForWear" -> {
                    try {
                        val notesJson = getNotesJsonFromSharedPreferences()
                        result.success(notesJson)
                    } catch (e: Exception) {
                        result.error("NATIVE_ERROR", "Failed to get notes from SharedPreferences", e.toString())
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
        assets.open(assetName).use { inputStream ->
            FileOutputStream(File(targetPath)).use { outputStream ->
                inputStream.copyTo(outputStream)
            }
        }
    }

    private fun getNotesJsonFromSharedPreferences(): String {
        val sharedPreferences: SharedPreferences = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val notesJson = sharedPreferences.getString("notes", null)
        if (notesJson != null) return notesJson

        val legacyNotesJson = sharedPreferences.all.entries
            .firstOrNull { it.key.startsWith("flutter.notes_") }
            ?.value as? String
        if (legacyNotesJson != null) return legacyNotesJson
        
        return "[]"
    }

    // JNI function declarations
    private external fun loadWhisperModel(modelPath: String): Long
    private external fun transcribeAudio(contextPtr: Long, audioPath: String, threads: Int): String
    private external fun getSystemInfo(): String
}
