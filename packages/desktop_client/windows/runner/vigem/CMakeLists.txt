cmake_minimum_required(VERSION 3.20.2)
project(ViGEmClient VERSION 1.21.222.0)

# Install directory setup
include(GNUInstallDirs)
set(VIGEM_INC_DIR ${CMAKE_INSTALL_INCLUDEDIR})

set(VIGEM_HEADERS
    ${CMAKE_CURRENT_SOURCE_DIR}/include/ViGEm/km/BusShared.h
    ${CMAKE_CURRENT_SOURCE_DIR}/include/ViGEm/Client.h
    ${CMAKE_CURRENT_SOURCE_DIR}/include/ViGEm/Common.h
    ${CMAKE_CURRENT_SOURCE_DIR}/include/ViGEm/Util.h
)

set(VIGEM_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Internal.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/resource.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ViGEmClient.cpp
    # Intentionally omitted .rc to prevent Flutter resource collisions
)

# 1. Force CMake to build a DLL
add_library(ViGEmClient SHARED
    ${VIGEM_HEADERS}
    ${VIGEM_SOURCES}
)

# 2. FORCE Windows to export all symbols (this guarantees the .dll is generated!)
set_target_properties(ViGEmClient PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)

target_include_directories(ViGEmClient
    PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${VIGEM_INC_DIR}>
)

target_link_libraries(ViGEmClient PRIVATE setupapi.lib)
add_library(ViGEmClient::ViGEmClient ALIAS ViGEmClient)