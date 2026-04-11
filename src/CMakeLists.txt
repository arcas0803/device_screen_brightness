# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(device_screen_brightness_library VERSION 0.0.1 LANGUAGES C)

add_library(device_screen_brightness SHARED
  "device_screen_brightness.c"
)

set_target_properties(device_screen_brightness PROPERTIES
  PUBLIC_HEADER device_screen_brightness.h
  OUTPUT_NAME "device_screen_brightness"
)

target_compile_definitions(device_screen_brightness PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(device_screen_brightness PRIVATE "-Wl,-z,max-page-size=16384")
elseif(WIN32)
  target_link_libraries(device_screen_brightness PRIVATE dxva2)
endif()
# Linux: no external dependencies (sysfs is pure POSIX)
