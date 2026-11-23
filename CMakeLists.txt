cmake_minimum_required(VERSION 3.21)
project(cadence VERSION 1.0.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.2 REQUIRED COMPONENTS Core Gui Widgets Qml Quick QuickControls2 Sql DBus Concurrent)
find_package(Qt6 OPTIONAL_COMPONENTS Test)
find_package(PkgConfig REQUIRED)
pkg_check_modules(GST REQUIRED IMPORTED_TARGET gstreamer-1.0 gstreamer-pbutils-1.0)
pkg_check_modules(TAGLIB REQUIRED IMPORTED_TARGET taglib)

file(GLOB_RECURSE CORE_SRC CONFIGURE_DEPENDS src/*.cpp src/*.h)
list(FILTER CORE_SRC EXCLUDE REGEX "src/main\\.cpp$")

add_library(cadence_core STATIC ${CORE_SRC})
target_include_directories(cadence_core PUBLIC src)
target_link_libraries(cadence_core PUBLIC Qt6::Core Qt6::Gui Qt6::Widgets Qt6::Qml Qt6::Quick
  Qt6::QuickControls2 Qt6::Sql Qt6::DBus Qt6::Concurrent PkgConfig::GST PkgConfig::TAGLIB)

add_executable(cadence src/main.cpp)
target_link_libraries(cadence PRIVATE cadence_core)

file(GLOB_RECURSE RES_FILES CONFIGURE_DEPENDS RELATIVE ${CMAKE_SOURCE_DIR} qml/*.qml assets/*.svg)
qt_add_resources(cadence "res" PREFIX "/" FILES ${RES_FILES})

install(TARGETS cadence RUNTIME DESTINATION bin)
install(FILES packaging/cadence.desktop DESTINATION share/applications)
install(FILES assets/cadence.svg DESTINATION share/icons/hicolor/scalable/apps)

if(Qt6Test_FOUND AND EXISTS ${CMAKE_SOURCE_DIR}/tests/CMakeLists.txt)
  enable_testing()
  add_subdirectory(tests)
endif()

set(CPACK_GENERATOR DEB)
set(CPACK_PACKAGE_NAME cadence)
set(CPACK_PACKAGE_CONTACT "you@localhost")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Offline Linux music player")
set(CPACK_DEBIAN_PACKAGE_SECTION sound)
set(CPACK_DEBIAN_FILE_NAME DEB-DEFAULT)
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
set(CPACK_DEBIAN_PACKAGE_DEPENDS
  "libqt6sql6-sqlite, qml6-module-qtquick, qml6-module-qtquick-controls, qml6-module-qtquick-layouts, qml6-module-qtquick-window, qml6-module-qtquick-templates, qml6-module-qtqml-workerscript, qml6-module-qtquick-dialogs, gstreamer1.0-plugins-base, gstreamer1.0-plugins-good, gstreamer1.0-plugins-bad, gstreamer1.0-plugins-ugly, gstreamer1.0-libav, gstreamer1.0-pulseaudio, gstreamer1.0-pipewire")
set(CPACK_PACKAGING_INSTALL_PREFIX /usr)
  include(CPack)