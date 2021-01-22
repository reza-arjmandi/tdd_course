cmake_minimum_required(VERSION 3.16)

project(tdd_course)

list(APPEND CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/cmake)
include(Util)
find_or_get(GMock)
find_or_get(GTest)
find_package(Threads)
set(CXX_STANDARD_REQUIRED ON)
add_executable(main main.cpp math_tests.cpp)
target_include_directories(main PUBLIC ${GMOCK_INCLUDE_DIRS})
set_property(TARGET main PROPERTY CXX_STANDARD 17)
target_link_libraries(main Threads::Threads ${GMOCK_BOTH_LIBRARIES} ${GTEST_BOTH_LIBRARIES})