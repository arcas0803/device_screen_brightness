# The Flutter tooling requires that developers have CMake 3.10 or later installed.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "device_screen_brightness")
project(${PROJECT_NAME} LANGUAGES C)

# Invoke the build for native code shared with the other target platforms.
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

# List of absolute paths to libraries that should be bundled with the plugin.
set(device_screen_brightness_bundled_libraries
  $<TARGET_FILE:device_screen_brightness>
  PARENT_SCOPE
)
