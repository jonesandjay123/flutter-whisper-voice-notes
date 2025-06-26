cmake_minimum_required(VERSION 3.10)

project(whisper_voice_notes)

set(CMAKE_CXX_STANDARD 17)

# 設定 whisper.cpp 路徑
set(WHISPER_LIB_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../third_party/whisper.cpp)

# 檢查 whisper.cpp 是否存在
if(NOT EXISTS ${WHISPER_LIB_DIR})
    message(FATAL_ERROR "whisper.cpp not found at ${WHISPER_LIB_DIR}. Make sure git submodule is properly initialized.")
endif()

# 源文件列表
set(SOURCE_FILES
    ${WHISPER_LIB_DIR}/src/whisper.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/native-lib.cpp
)

# 尋找 Android 系統庫
find_library(LOG_LIB log)
find_library(ANDROID_LIB android)

include(FetchContent)

# 建立我們的 native library
add_library(native-lib SHARED ${SOURCE_FILES})

# 編譯定義
target_compile_definitions(native-lib PUBLIC GGML_USE_CPU)

# 優化設定（Release 模式）
if(NOT ${CMAKE_BUILD_TYPE} STREQUAL "Debug")
    target_compile_options(native-lib PRIVATE -O3)
    target_compile_options(native-lib PRIVATE -fvisibility=hidden -fvisibility-inlines-hidden)
    target_compile_options(native-lib PRIVATE -ffunction-sections -fdata-sections)
    
    target_link_options(native-lib PRIVATE -Wl,--gc-sections)
    target_link_options(native-lib PRIVATE -Wl,--exclude-libs,ALL)
    target_link_options(native-lib PRIVATE -flto)
endif()

# 加入 GGML
FetchContent_Declare(ggml SOURCE_DIR ${WHISPER_LIB_DIR}/ggml)
FetchContent_MakeAvailable(ggml)

# 設定 include 目錄
target_include_directories(native-lib PRIVATE
    ${WHISPER_LIB_DIR}
    ${WHISPER_LIB_DIR}/src
    ${WHISPER_LIB_DIR}/include
    ${WHISPER_LIB_DIR}/ggml/include
    ${WHISPER_LIB_DIR}/ggml/src
    ${WHISPER_LIB_DIR}/ggml/src/ggml-cpu
)

# 連結庫
target_link_libraries(native-lib 
    ${LOG_LIB} 
    ${ANDROID_LIB}
    ggml
)
