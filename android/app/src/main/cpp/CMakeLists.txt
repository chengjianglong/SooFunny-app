# The talking buddy's brain: llama.cpp (CPU only) plus a small JNI bridge, built into one
# library, libsoofunny_llama.so. llama.cpp is linked statically and only its core libraries are
# built (no tools, examples, tests, server or networking).
#
# Where llama.cpp comes from:
#  - LLAMA_SRC_DIR, if that directory exists (default: ../Vendor/llama.cpp-src, the same checkout
#    the iOS build uses; Vendor/ is not in git);
#  - otherwise the same tag is fetched from GitHub when the build is configured.
cmake_minimum_required(VERSION 3.22.1)
project(soofunny_llama C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(LLAMA_TAG "b11577")
set(LLAMA_SRC_DIR "${CMAKE_CURRENT_LIST_DIR}/../../../../../Vendor/llama.cpp-src" CACHE PATH "Local llama.cpp checkout")

# A debug build of the model is far too slow to talk with: always optimise, without debug info.
foreach(lang C CXX)
    set(CMAKE_${lang}_FLAGS_DEBUG "-O3 -DNDEBUG")
    set(CMAKE_${lang}_FLAGS_RELWITHDEBINFO "-O3 -DNDEBUG")
    set(CMAKE_${lang}_FLAGS "${CMAKE_${lang}_FLAGS} -ffunction-sections -fdata-sections")
endforeach()

# Only the libraries, linked statically into this one.
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_COMMON OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_APP OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_UI OFF CACHE BOOL "" FORCE)
set(LLAMA_OPENSSL OFF CACHE BOOL "" FORCE)
set(LLAMA_CURL OFF CACHE BOOL "" FORCE)
set(LLAMA_ALL_WARNINGS OFF CACHE BOOL "" FORCE)
set(GGML_ALL_WARNINGS OFF CACHE BOOL "" FORCE)
set(GGML_CCACHE OFF CACHE BOOL "" FORCE)

# CPU backend only, with ggml's own thread pool (no OpenMP runtime to ship).
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
set(GGML_BACKEND_DL OFF CACHE BOOL "" FORCE)
set(GGML_CPU_KLEIDIAI OFF CACHE BOOL "" FORCE)
set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
set(GGML_OPENCL OFF CACHE BOOL "" FORCE)
if(ANDROID_ABI STREQUAL "arm64-v8a")
    # Dot product and half-precision arithmetic: every 64-bit phone core since the Cortex-A55/A75
    # (2017). LlamaEngine checks /proc/cpuinfo before loading this library on older cores.
    set(GGML_CPU_ARM_ARCH "armv8.2-a+dotprod+fp16" CACHE STRING "" FORCE)
elseif(ANDROID_ABI STREQUAL "x86_64")
    # Emulators and Chromebooks; LlamaEngine checks for AVX2 before loading.
    foreach(feature SSE42 AVX AVX2 FMA F16C BMI2)
        set(GGML_${feature} ON CACHE BOOL "" FORCE)
    endforeach()
endif()

if(EXISTS "${LLAMA_SRC_DIR}/CMakeLists.txt")
    message(STATUS "llama.cpp: using local source ${LLAMA_SRC_DIR}")
    add_subdirectory("${LLAMA_SRC_DIR}" llama-build EXCLUDE_FROM_ALL)
else()
    message(STATUS "llama.cpp: ${LLAMA_SRC_DIR} not found, fetching ${LLAMA_TAG} from GitHub")
    include(FetchContent)
    FetchContent_Declare(llama_cpp
        GIT_REPOSITORY https://github.com/ggml-org/llama.cpp.git
        GIT_TAG ${LLAMA_TAG}
        GIT_SHALLOW TRUE)
    FetchContent_GetProperties(llama_cpp)
    if(NOT llama_cpp_POPULATED)
        FetchContent_Populate(llama_cpp)
        add_subdirectory("${llama_cpp_SOURCE_DIR}" "${llama_cpp_BINARY_DIR}" EXCLUDE_FROM_ALL)
    endif()
endif()

add_library(soofunny_llama SHARED llama_jni.cpp)
target_link_libraries(soofunny_llama PRIVATE llama)
if(ANDROID)
    target_link_libraries(soofunny_llama PRIVATE android log)
    target_link_options(soofunny_llama PRIVATE -Wl,--gc-sections -Wl,--exclude-libs,ALL)
else()
    # A host build (for checking the bridge on a desktop JVM) needs the JDK's JNI headers.
    find_package(JNI REQUIRED)
    target_include_directories(soofunny_llama PRIVATE ${JNI_INCLUDE_DIRS})
endif()
set_target_properties(soofunny_llama PROPERTIES CXX_VISIBILITY_PRESET hidden C_VISIBILITY_PRESET hidden)
