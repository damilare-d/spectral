cmake_minimum_required(VERSION 3.14)
project(spectral_native C)

include(FetchContent)

# ── miniaudio (single-header, just populate source dir) ──────────────────────
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

# ── KISS FFT (include .c directly to avoid a separate DLL dependency) ─────────
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

# ── spectral_native shared library ────────────────────────────────────────────
add_library(spectral_native SHARED
    spectral.c
    analyzer.c
    ${kissfft_SOURCE_DIR}/kiss_fft.c
)

target_include_directories(spectral_native PRIVATE
    ${miniaudio_SOURCE_DIR}
    ${kissfft_SOURCE_DIR}
)

# miniaudio needs these on Windows for WASAPI / COM
if(WIN32)
    target_link_libraries(spectral_native PRIVATE ole32 uuid)
endif()

# Link math library on non-MSVC toolchains
if(NOT MSVC)
    target_link_libraries(spectral_native PRIVATE m)
endif()

# Export only the spectral_* symbols; keep kiss_fft / miniaudio internals hidden
if(NOT WIN32)
    set_target_properties(spectral_native PROPERTIES
        C_VISIBILITY_PRESET hidden
    )
endif()
