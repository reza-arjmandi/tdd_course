# This module creates a target to download, unpack, build, and install
# ZLIB using sm_add_ext_cmake_project. See sm_add_ext_cmake_project
# for more info.
if(RETRIEVE_ZLIB_INCLUDED)
    return()
endif()
set(RETRIEVE_ZLIB_INCLUDED 1)

include(Util)

# The URL HASH created using online facility:
# 	https://hash.online-convert.com/sha1-generator
# It helps CMake verify the integrity of the file and not download it again.
add_ext_cmake_project(
    ZLIB
    URL https://github.com/madler/zlib/archive/v1.2.11.zip
    SHA1 eba1cd6f2e3c7a75fe33a8b02b4d7e4b1ad58481
    PDB_INSTALL_DIR lib
    EXTRA_CACHE_ARGS
        -DCMAKE_DEBUG_POSTFIX:STRING=d
)
