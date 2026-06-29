cmake_minimum_required(VERSION 3.18)
project(spectral_native C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(FetchContent)

# ── miniaudio (single-header) ─────────────────────────────────────────────────
FetchContent_Declare(
    miniaudio
    GIT_REPOSITORY https://github.com/mackron/miniaudio.git
    GIT_TAG        master
    GIT_SHALLOW    TRUE
)
FetchContent_GetProperties(miniaudio)
if(NOT miniaudio_POPULATED)
    FetchContent_Populate(miniaudio)
endif()

# ── KISS FFT (source included directly) ──────────────────────────────────────
FetchContent_Declare(
    kissfft
    GIT_REPOSITORY https://github.com/mborgerding/kissfft.git
    GIT_TAG        v131
    GIT_SHALLOW    TRUE
)
FetchContent_GetProperties(kissfft)
if(NOT kissfft_POPULATED)
    FetchContent_Populate(kissfft)
endif()

# ── whisper.cpp ───────────────────────────────────────────────────────────────
FetchContent_Declare(
    whisper_cpp
    GIT_REPOSITORY https://github.com/ggerganov/whisper.cpp.git
    GIT_TAG        v1.7.4
    GIT_SHALLOW    TRUE
)
FetchContent_GetProperties(whisper_cpp)
if(NOT whisper_cpp_POPULATED)
    FetchContent_Populate(whisper_cpp)
endif()

# Disable everything in whisper.cpp that doesn't apply to Android cross-compilation
set(WHISPER_BUILD_TESTS     OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_EXAMPLES  OFF CACHE BOOL "" FORCE)
set(WHISPER_SDL2            OFF CACHE BOOL "" FORCE)
set(WHISPER_FFMPEG          OFF CACHE BOOL "" FORCE)
set(GGML_METAL              OFF CACHE BOOL "" FORCE)
set(GGML_OPENCL             OFF CACHE BOOL "" FORCE)
set(GGML_VULKAN             OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP             OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE             OFF CACHE BOOL "" FORCE)
# Scalar fallback — avoids NEON dotprod clang version issues on older NDKs
set(GGML_CPU_AARCH64        OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS       OFF CACHE BOOL "" FORCE)

add_subdirectory(${whisper_cpp_SOURCE_DIR} ${whisper_cpp_BINARY_DIR} EXCLUDE_FROM_ALL)

# ── spectral_native shared library ───────────────────────────────────────────
set(NATIVE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../native")

add_library(spectral_native SHARED
    ${NATIVE_DIR}/spectral.c
    ${NATIVE_DIR}/analyzer.c
    ${NATIVE_DIR}/whisper_wrapper.cpp
    ${kissfft_SOURCE_DIR}/kiss_fft.c
)

target_include_directories(spectral_native PRIVATE
    ${miniaudio_SOURCE_DIR}
    ${kissfft_SOURCE_DIR}
    ${NATIVE_DIR}
    ${whisper_cpp_SOURCE_DIR}
    ${whisper_cpp_SOURCE_DIR}/include
    ${whisper_cpp_SOURCE_DIR}/ggml/include
)

# Android system libraries required by miniaudio.
# aaudio is intentionally absent: miniaudio dlopen()s it at runtime on API 26+
# and falls back to OpenSL ES on older devices.
target_link_libraries(spectral_native PRIVATE
    whisper
    android
    log
    OpenSLES
)

# Keep the .so surface clean — only spectral_*, analyzer_*, whisper_wrapper_* exported
set_target_properties(spectral_native PROPERTIES
    C_VISIBILITY_PRESET   hidden
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
)
