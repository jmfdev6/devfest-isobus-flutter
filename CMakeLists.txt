cmake_minimum_required(VERSION 3.16)
project(live LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)   # a pilha vai dentro de uma .so
set(CAN_DRIVER "SocketCAN" CACHE STRING "")
add_subdirectory(third_party/AgIsoStack-plus-plus agisostack EXCLUDE_FROM_ALL)

add_library(agiso SHARED
  ponte/agiso.cpp
  # [passo 7]
  ponte/vt.cpp
  # [/passo 7]
  # [passo 8]
  ponte/tc.cpp
  # [/passo 8]
)
target_include_directories(agiso PUBLIC ponte)
target_link_libraries(agiso PRIVATE isobus::Isobus isobus::HardwareIntegration isobus::Utility)
set_target_properties(agiso PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_link_options(agiso PRIVATE "LINKER:--exclude-libs,ALL")

add_executable(teste teste/teste.c)
target_link_libraries(teste PRIVATE agiso)
