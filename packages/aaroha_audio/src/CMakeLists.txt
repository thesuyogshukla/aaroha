# Builds the Aaroha native audio core. Used by the Android Gradle build
# (externalNativeBuild) and by tools/build_native_host.sh for the Mac.
#
# The Flutter tooling requires that developers have CMake 3.10 or later
# installed, so the minimum stays at 3.10.
cmake_minimum_required(VERSION 3.10)

project(aaroha_audio_library VERSION 0.0.1 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(aaroha_audio SHARED
  "engine.cpp"
  "pitch_tracker.cpp"
  "drone.cpp"
  "flute_voice.cpp"
  "miniaudio_impl.c"
)

set_target_properties(aaroha_audio PROPERTIES
  PUBLIC_HEADER aaroha_audio.h
  OUTPUT_NAME "aaroha_audio"
  C_VISIBILITY_PRESET hidden
  CXX_VISIBILITY_PRESET hidden
)

target_compile_definitions(aaroha_audio PUBLIC DART_SHARED_LIB)

# The tracker does ~25M multiply-adds per second; keep it optimised even in
# debug app builds.
target_compile_options(aaroha_audio PRIVATE -O2)

find_package(Threads REQUIRED)
target_link_libraries(aaroha_audio PRIVATE Threads::Threads)

if (ANDROID)
  target_link_libraries(aaroha_audio PRIVATE log dl m)
  # Support Android 15 16k page size
  target_link_options(aaroha_audio PRIVATE "-Wl,-z,max-page-size=16384")
elseif (APPLE)
  target_link_libraries(aaroha_audio PRIVATE
    "-framework CoreFoundation" "-framework CoreAudio" "-framework AudioToolbox")
else ()
  target_link_libraries(aaroha_audio PRIVATE dl m)
endif ()
