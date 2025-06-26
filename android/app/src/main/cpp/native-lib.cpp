#include <jni.h>
#include <string>
#include <android/log.h>
#include "whisper.h"  // 加入 whisper 頭文件

#define LOG_TAG "WhisperJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

extern "C" JNIEXPORT jstring JNICALL
Java_com_jovicheer_whisper_1voice_1notes_MainActivity_runWhisper(JNIEnv *env, jobject /* this */, jstring audioPath) {
    LOGI("JNI runWhisper called");
    
    // 將 Java String 轉換為 C++ string
    const char *audioPathCStr = env->GetStringUTFChars(audioPath, 0);
    std::string audioPathStr(audioPathCStr);
    
    // 釋放 Java String 記憶體
    env->ReleaseStringUTFChars(audioPath, audioPathCStr);
    
    LOGI("Audio path received: %s", audioPathStr.c_str());
    
    // 測試 whisper.h 是否正確引入
    const char* whisper_version = whisper_print_system_info();
    LOGI("Whisper system info: %s", whisper_version);
    
    // 目前先回傳系統資訊，確認 whisper.cpp 正確整合
    std::string result = "transcription: whisper.cpp integrated successfully!\nSystem: ";
    result += whisper_version;
    result += "\nAudio path: " + audioPathStr;
    
    LOGI("Returning result: %s", result.c_str());
    
    return env->NewStringUTF(result.c_str());
} 