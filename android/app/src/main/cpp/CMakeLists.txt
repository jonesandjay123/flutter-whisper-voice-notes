cmake_minimum_required(VERSION 3.18.1)

project("whisper_voice_notes")

set(CMAKE_CXX_STANDARD 17)

# 設定 whisper.cpp 路徑
set(WHISPER_LIB_DIR ${CMAKE_SOURCE_DIR}/../../../../../third_party/whisper.cpp)

# Get whisper.cpp version
file(READ "${WHISPER_LIB_DIR}/CMakeLists.txt" MAIN_CMAKE_CONTENT)
string(REGEX MATCH "project\\(\"whisper\\.cpp\" VERSION ([0-9]+\\.[0-9]+\\.[0-9]+)\\)" VERSION_MATCH "${MAIN_CMAKE_CONTENT}")
if(CMAKE_MATCH_1)
    set(WHISPER_VERSION ${CMAKE_MATCH_1})
else()
    set(WHISPER_VERSION "unknown")
endif()

message(STATUS "Whisper version: ${WHISPER_VERSION}")

# 檢查 whisper.cpp 是否存在
if(NOT EXISTS "${WHISPER_LIB_DIR}")
    message(FATAL_ERROR "whisper.cpp not found at ${WHISPER_LIB_DIR}. Make sure git submodule is properly initialized.")
endif()

message(STATUS "Found whisper.cpp at: ${WHISPER_LIB_DIR}")

# 源文件列表
set(SOURCE_FILES
    ${WHISPER_LIB_DIR}/src/whisper.cpp
    ${CMAKE_SOURCE_DIR}/native-lib.cpp
)

# 尋找 Android 系統庫
find_library(LOG_LIB log)

include(FetchContent)

function(build_library target_name)
    add_library(
        ${target_name}
        SHARED
        ${SOURCE_FILES}
    )

    FetchContent_Declare(ggml SOURCE_DIR ${WHISPER_LIB_DIR}/ggml)
    FetchContent_MakeAvailable(ggml)

    target_link_libraries(${target_name} ${LOG_LIB} android ggml)
    target_compile_definitions(${target_name} PUBLIC GGML_USE_CPU)
    target_compile_definitions(${target_name} PRIVATE WHISPER_VERSION="${WHISPER_VERSION}")

    # 根據目標設定特定的編譯選項
    if (${target_name} STREQUAL "whisper_v8fp16_va")
        target_compile_options(${target_name} PRIVATE -march=armv8.2-a+fp16)
        message(STATUS "Building ${target_name} with ARMv8.2-A+FP16 optimizations")
    elseif (${target_name} STREQUAL "whisper_vfpv4")
        target_compile_options(${target_name} PRIVATE -mfpu=neon-vfpv4)
        message(STATUS "Building ${target_name} with NEON VFPv4 optimizations")
    endif ()

    # Release 模式優化
    if (NOT ${CMAKE_BUILD_TYPE} STREQUAL "Debug")
        target_compile_options(${target_name} PRIVATE -O3)
        target_compile_options(${target_name} PRIVATE -fvisibility=hidden -fvisibility-inlines-hidden)
        target_compile_options(${target_name} PRIVATE -ffunction-sections -fdata-sections)
        message(STATUS "Building ${target_name} with Release optimizations")
    endif ()
endfunction()

# 構建預設版本
build_library("whisper")

# 根據 ABI 構建優化版本
if (${ANDROID_ABI} STREQUAL "arm64-v8a")
    build_library("whisper_v8fp16_va")
    message(STATUS "Building ARM64 optimized version")
elseif (${ANDROID_ABI} STREQUAL "armeabi-v7a")
    build_library("whisper_vfpv4")
    message(STATUS "Building ARMv7 optimized version")
endif ()

# 設定 include 目錄
include_directories(${WHISPER_LIB_DIR})
include_directories(${WHISPER_LIB_DIR}/src)
include_directories(${WHISPER_LIB_DIR}/include)
include_directories(${WHISPER_LIB_DIR}/ggml/include)
include_directories(${WHISPER_LIB_DIR}/ggml/src)
include_directories(${WHISPER_LIB_DIR}/ggml/src/ggml-cpu)
