cmake_minimum_required(VERSION 3.10)

project(kittentts_cephonemizer_library VERSION 0.1.0 LANGUAGES CXX)

add_library(kittentts_cephonemizer SHARED
  "cephonemizer/phonemizer.cpp"
  "cephonemizer/swift_bridge.cpp"
)

set_target_properties(kittentts_cephonemizer PROPERTIES
  PUBLIC_HEADER "cephonemizer/phonemizer.h"
  OUTPUT_NAME "kittentts_cephonemizer"
  CXX_STANDARD 17
  CXX_STANDARD_REQUIRED ON
)

target_compile_definitions(kittentts_cephonemizer PRIVATE DART_SHARED_LIB)
target_include_directories(kittentts_cephonemizer PRIVATE "cephonemizer")

if (ANDROID)
  target_link_libraries(kittentts_cephonemizer log)
  target_link_options(kittentts_cephonemizer PRIVATE "-Wl,-z,max-page-size=16384")
endif()
