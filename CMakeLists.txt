cmake_minimum_required(VERSION 3.16)
project(live LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)   # a pilha vai dentro de uma .so
set(CAN_DRIVER "SocketCAN" CACHE STRING "")
add_subdirectory(third_party/AgIsoStack-plus-plus agisostack EXCLUDE_FROM_ALL)

add_library(agiso SHARED
  nativo/ponte/agiso.cpp
  # [passo 7]
  nativo/ponte/vt.cpp
  # [/passo 7]
  # [passo 8]
  nativo/ponte/tc.cpp
  # [/passo 8]
)
target_include_directories(agiso PUBLIC nativo/ponte)
target_link_libraries(agiso PRIVATE isobus::Isobus isobus::HardwareIntegration isobus::Utility)
set_target_properties(agiso PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_link_options(agiso PRIVATE "LINKER:--exclude-libs,ALL")

# O trator: anda no talhão e manda posição NMEA 2000 e velocidade de solo
add_executable(trator nativo/trator/trator.cpp)
target_link_libraries(trator PRIVATE isobus::Isobus isobus::HardwareIntegration isobus::Utility)

add_executable(teste nativo/teste/teste.c)
target_link_libraries(teste PRIVATE agiso)

# O implemento da demo: a plantadeira do seeder_example da AgIsoStack++,
# que já traz o cliente de VT e o cliente de TC
set(SEEDER third_party/AgIsoStack-plus-plus/examples/seeder_example)
set(EXEMPLOS third_party/AgIsoStack-plus-plus/examples/common)
find_package(Threads REQUIRED)
add_executable(seeder ${SEEDER}/main.cpp ${SEEDER}/seeder.cpp ${SEEDER}/vt_application.cpp
  nativo/plantadeira/section_control_implement_sim.cpp ${EXEMPLOS}/console_logger.cpp ${EXEMPLOS}/create_can_driver.cpp)
# nativo/plantadeira/: cópia do simulador de seções com os switches valendo no automático
target_include_directories(seeder PRIVATE ${SEEDER})
target_link_libraries(seeder PRIVATE isobus::Isobus isobus::HardwareIntegration isobus::Utility Threads::Threads)
# ele lê o BasePool.iop da pasta atual: rode de dentro de build/
add_custom_command(TARGET seeder POST_BUILD COMMAND ${CMAKE_COMMAND} -E copy
  ${CMAKE_CURRENT_SOURCE_DIR}/${SEEDER}/BasePool.iop $<TARGET_FILE_DIR:seeder>/BasePool.iop)
