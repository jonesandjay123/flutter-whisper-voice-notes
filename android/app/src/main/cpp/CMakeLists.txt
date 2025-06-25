cmake_minimum_required(VERSION 3.4.1)  # 最低 CMake 版本

# 定義 native-lib 名稱與來源檔案
add_library( # 名稱
        whisper
        # 建立為 SHARED 動態連結庫
        SHARED

        # 源碼檔案列表
        ggml.c
        whisper.cpp
)

# 包含 C++ 的頭文件目錄（.h）
include_directories(
        ${CMAKE_CURRENT_SOURCE_DIR}
)

# 指定 log 库（Android 平台特有，用來印出 log）
find_library( log-lib log )

# 將 log 庫連接進 whisper.so
target_link_libraries(
        whisper
        ${log-lib}
)
