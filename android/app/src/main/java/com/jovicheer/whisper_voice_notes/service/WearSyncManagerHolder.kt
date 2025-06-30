package com.jovicheer.whisper_voice_notes.service

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine

// 使用 object 關鍵字創建一個單例
object WearSyncManagerHolder {
    @Volatile
    private var instance: WearSyncManager? = null

    fun getInstance(context: Context): WearSyncManager {
        return instance ?: synchronized(this) {
            instance ?: WearSyncManager(context.applicationContext).also { instance = it }
        }
    }
    
    // 這個方法讓我們可以從 MainActivity 初始化 WearSyncManager
    fun initialize(flutterEngine: FlutterEngine) {
        instance?.initialize(flutterEngine)
    }
} 