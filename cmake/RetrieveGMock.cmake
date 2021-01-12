# This module creates a target to download, unpack, build, and install
# GTest and GMock (known together as GoogleTest Framework) using
# sm_add_ext_cmake_project and adds some build customization
# parameters. See sm_add_ext_cmake_project for more info.
if(RETRIEVE_GMOCK_INCLUDED)
    return()
endif()
set(RETRIEVE_GMOCK_INCLUDED 1)

include(Util)

set(GTEST_URL https://github.com/google/googletest/archive/release-1.10.0.zip)
set(GTEST_SHA1 9ea36bf6dd6383beab405fd619bdce05e66a6535)

# The URL HASH created using online facility:
# 	https://hash.online-convert.com/sha1-generator
# It helps CMake verify the integrity of the file and not download it again.
add_ext_cmake_project(
    GMock
    URL ${GTEST_URL}
    SHA1 ${GTEST_SHA1}
    PDB_INSTALL_DIR lib
    EXTRA_CACHE_ARGS
        -DCMAKE_DEBUG_POSTFIX:STRING=d
        # Our projects use shared CRT, so other libraries that we link to must
        # be the same or we get link errors.
        -Dgtest_force_shared_crt:BOOL=ON
)
