#include <jni.h>
#include <string>
#include <vector>
#include <fstream>
#include <android/log.h>
#include <cstdint>
#include <memory>
#include <thread>
#include <chrono>
#include "whisper.h"
#include "ggml.h"

#define LOG_TAG "WhisperNative"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

#define WHISPER_SAMPLE_RATE 16000

// WAV 檔案讀取函數
std::vector<float> read_wav_file(const std::string& filename) {
    std::ifstream file(filename, std::ios::binary);
    if (!file.is_open()) {
        LOGE("Cannot open WAV file: %s", filename.c_str());
        return {};
    }

    // 讀取 WAV header
    char header[44];
    file.read(header, 44);
    
    if (file.gcount() != 44) {
        LOGE("Invalid WAV file header size");
        return {};
    }

    // 檢查 WAV 格式
    if (strncmp(header, "RIFF", 4) != 0 || strncmp(header + 8, "WAVE", 4) != 0) {
        LOGE("Not a valid WAV file");
        return {};
    }

    // 提取音頻參數
    int sample_rate = *reinterpret_cast<int*>(header + 24);
    int bits_per_sample = *reinterpret_cast<short*>(header + 34);
    int channels = *reinterpret_cast<short*>(header + 22);
    
    LOGI("WAV file info: %d Hz, %d bits, %d channels", sample_rate, bits_per_sample, channels);

    // 讀取音頻資料
    file.seekg(44, std::ios::beg);
    std::vector<char> wav_data((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    
    if (wav_data.empty()) {
        LOGE("No audio data found in WAV file");
        return {};
    }

    // 轉換為 float 格式
    std::vector<float> audio_data;
    
    if (bits_per_sample == 16) {
        const int16_t* samples = reinterpret_cast<const int16_t*>(wav_data.data());
        size_t sample_count = wav_data.size() / sizeof(int16_t);
        
        audio_data.reserve(sample_count / channels); // 只取第一個聲道
        
        for (size_t i = 0; i < sample_count; i += channels) {
            audio_data.push_back(static_cast<float>(samples[i]) / 32768.0f);
        }
    } else if (bits_per_sample == 32) {
        const float* samples = reinterpret_cast<const float*>(wav_data.data());
        size_t sample_count = wav_data.size() / sizeof(float);
        
        audio_data.reserve(sample_count / channels);
        
        for (size_t i = 0; i < sample_count; i += channels) {
            audio_data.push_back(samples[i]);
        }
    } else {
        LOGE("Unsupported bits per sample: %d", bits_per_sample);
        return {};
    }

    LOGI("Loaded %zu audio samples (%.2f seconds)", 
         audio_data.size(), 
         static_cast<double>(audio_data.size()) / sample_rate);

    return audio_data;
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_jovicheer_whisper_1voice_1notes_MainActivity_loadWhisperModel(
        JNIEnv *env, jobject /* this */, jstring model_path) {

    const char *model_path_cstr = env->GetStringUTFChars(model_path, nullptr);
    
    LOGI("Loading Whisper model from: %s", model_path_cstr);

    // 載入模型
    struct whisper_context_params cparams = whisper_context_default_params();
    cparams.use_gpu = false; // Android 上使用 CPU
    
    struct whisper_context* context = whisper_init_from_file_with_params(model_path_cstr, cparams);
    
    env->ReleaseStringUTFChars(model_path, model_path_cstr);

    if (context == nullptr) {
        LOGE("Failed to load Whisper model");
        return 0;
    }

    LOGI("Whisper model loaded successfully");
    return reinterpret_cast<jlong>(context);
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_jovicheer_whisper_1voice_1notes_MainActivity_transcribeAudio(
        JNIEnv *env,
        jobject /* this */,
        jlong contextPtr,
        jstring audioPath,
        jint threads) {

    // 開始計時
    auto start_time = std::chrono::high_resolution_clock::now();

    if (contextPtr == 0) {
        LOGE("Context pointer is null");
        return env->NewStringUTF("錯誤：模型未載入");
    }

    whisper_context *ctx = reinterpret_cast<whisper_context *>(contextPtr);
    const char *audio_path = env->GetStringUTFChars(audioPath, 0);

    LOGI("Transcribing: %s with %d threads", audio_path, threads);

    // 讀取音頻檔案
    std::vector<float> pcmf32 = read_wav_file(audio_path);
    if (pcmf32.empty()) {
        LOGE("Failed to read audio file");
        env->ReleaseStringUTFChars(audioPath, audio_path);
        return env->NewStringUTF("錯誤：無法讀取音頻檔案");
    }

    // 設定 whisper 參數（基於官方 Android 範例）
    whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    
    wparams.print_realtime   = false;  // 關閉實時輸出以提高性能
    wparams.print_progress   = false;
    wparams.print_timestamps = false;
    wparams.print_special    = false;
    wparams.translate        = false;
    wparams.language         = "zh";   // 中文
    wparams.n_threads        = threads;
    wparams.offset_ms        = 0;
    wparams.no_context       = true;
    wparams.single_segment   = false;

    // 重置計時器並執行轉錄
    whisper_reset_timings(ctx);

    if (whisper_full(ctx, wparams, pcmf32.data(), pcmf32.size()) != 0) {
        LOGE("Transcription failed");
        env->ReleaseStringUTFChars(audioPath, audio_path);
        return env->NewStringUTF("錯誤：轉錄過程失敗");
    }

    // 計算轉錄耗時
    auto end_time = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time);
    
    LOGI("Transcription completed in %lld ms", duration.count());

    // 獲取轉錄結果
    const int n_segments = whisper_full_n_segments(ctx);
    std::string result_text;
    
    if (n_segments == 0) {
        result_text = "沒有檢測到語音內容";
    } else {
        // 合併所有段落的文字
        for (int i = 0; i < n_segments; ++i) {
            const char *text = whisper_full_get_segment_text(ctx, i);
            if (text != nullptr) {
                if (!result_text.empty()) {
                    result_text += " ";
                }
                result_text += text;
            }
        }
    }

    // 清理前導/尾隨空格
    result_text.erase(0, result_text.find_first_not_of(" \t\n\r"));
    result_text.erase(result_text.find_last_not_of(" \t\n\r") + 1);

    if (result_text.empty()) {
        result_text = "無法識別語音內容";
    }

    LOGI("Final result: %s", result_text.c_str());

    // 輸出性能統計（僅在 Debug 模式）
    #ifdef DEBUG
    whisper_print_timings(ctx);
    #endif

    env->ReleaseStringUTFChars(audioPath, audio_path);
    return env->NewStringUTF(result_text.c_str());
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_jovicheer_whisper_1voice_1notes_MainActivity_getSystemInfo(
        JNIEnv *env, jobject /* this */) {
    
    const char *sysinfo = whisper_print_system_info();
    return env->NewStringUTF(sysinfo);
} 