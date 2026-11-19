cmake_minimum_required(VERSION 3.10)
project(tunner_dsp C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

add_library(tunner_dsp SHARED
    tunner_dsp.c
    tunner_dsp.h
)

target_include_directories(tunner_dsp PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:include>
)

if(MSVC)
    target_compile_options(tunner_dsp PRIVATE /O2 /W4)
else()
    target_compile_options(tunner_dsp PRIVATE -O3 -fPIC -Wall -Wextra)
endif()

set_target_properties(tunner_dsp PROPERTIES
    PUBLIC_HEADER tunner_dsp.h
    OUTPUT_NAME "tunner_dsp"
)
