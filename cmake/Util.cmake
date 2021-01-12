cmake_minimum_required(VERSION 3.9)

# Define IS_64_BIT to identify platform bitness
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(IS_64_BIT TRUE)
else()
    set(IS_64_BIT FALSE)
endif()

# Util specific directories used in build:
# PROGRAMDATA_ROOT is used as a base for download cache, build, and
# installations.
if (WIN32)
    file(TO_CMAKE_PATH "$ENV{ProgramData}" PROGRAMDATA_ROOT)

    if(IS_64_BIT)
        set(PROGRAMDATA_ROOT_POSTFIX 64)
        set(ARCHITECTURE x64)
    else()
        set(PROGRAMDATA_ROOT_POSTFIX "")
        set(ARCHITECTURE x86)
    endif()
    
elseif (APPLE OR UNIX)
    if (CROSS_COMPILE_FOR_RPI)
        set(PROGRAMDATA_ROOT ${CMAKE_SYSROOT})
    else()
        set(PROGRAMDATA_ROOT ~/.local)
    endif()
endif()

set(MODULE_PATH ${CMAKE_CURRENT_LIST_DIR})

if (CROSS_COMPILE_FOR_RPI)

set(3RDPARTY_DIR_NAME usr CACHE STRING
    "Base name of the directory. This directory will be created under
the ProgramData directory and everything is placed there.")

set(PROGRAMDATA_DIR
    ${PROGRAMDATA_ROOT}/${3RDPARTY_DIR_NAME}
    CACHE PATH
    "Path to the base directory within ProgramData where everything (download,
source, build, install) is stored.")

else()

set(3RDPARTY_DIR_NAME 3rdparty CACHE STRING
    "Base name of the directory. This directory will be created under
the ProgramData directory and everything is placed there.")

set(PROGRAMDATA_DIR
    ${PROGRAMDATA_ROOT}/${3RDPARTY_DIR_NAME}${PROGRAMDATA_ROOT_POSTFIX}
    CACHE PATH
    "Path to the base directory within ProgramData where everything (download,
source, build, install) is stored.")

endif()

set(DOWNLOAD_CACHE_DIR
    ${PROGRAMDATA_DIR}/cache
    CACHE PATH
    "Directory path to be used as cache for retrieving third-party \
libraries if they are not found by find_package procedures.")

set(SM_3RDPARTY_INSTALL_DIR
    ${PROGRAMDATA_DIR}
    CACHE PATH
    "Install prefix for 3rd party libraries retrieved and used by SMUtil. \
The find_* procedures will search this path first.")

# The build directory for the 3rdparty libraries is a shortened hash of the
# combination of various build system configuration parameters. This is to keep
# separate build directories for different build systems. The info about the
# build system used for the build directory could be placed inside the build
# directory using the macro create_3rdparty_build_info_file.
string(MD5 BUILD_SYSTEM_HASH
    "${CMAKE_GENERATOR}${CMAKE_GENERATOR_PLATFORM}${CMAKE_GENERATOR_TOOLSET}")
string(SUBSTRING ${BUILD_SYSTEM_HASH} 0 8 BUILD_SYSTEM_HASH)
set(SM_3RDPARTY_BUILD_DIR
    ${PROGRAMDATA_DIR}/build/${BUILD_SYSTEM_HASH} CACHE PATH
    "Directory path used for the build processes of the third-party libraries.")

set(BUILD_INFO_FILE ${SM_3RDPARTY_BUILD_DIR}/BuildInfo.txt)

set(SM_3RDPARTY_CONFIGURATION_TYPES Debug Release CACHE PATH
    "Configuration types in which 3rd party libraries are built.")

# All the libraries are installed to ${SM_3RDPARTY_INSTALL_DIR}. So
# adding it to the prefix path will ensure that calls to find_package will
# find them there.
if (NOT ${SM_3RDPARTY_INSTALL_DIR} IN_LIST CMAKE_PREFIX_PATH)
    list(APPEND CMAKE_PREFIX_PATH ${SM_3RDPARTY_INSTALL_DIR})
    list(APPEND CMAKE_PROGRAM_PATH ${SM_3RDPARTY_INSTALL_DIR})
endif()

# Bring in ExternalProject so we can easily download and install external
# dependencies. The EP_BASE directory property determines where our build system
# and build artifacts for external projects will go.
include(ExternalProject)
set_directory_properties(PROPERTIES EP_BASE ${SM_3RDPARTY_BUILD_DIR})

find_program(CTEST_COMMAND ctest)
find_program(CPACK_COMMAND cpack)

# Delete all CMake related files in the build directory to ensure that,
# when changes are made to cache arguments here, the stale cache values
# will not persist.
function(clean_ext_proj_build_sys_files BINARY_DIR PACKAGE_NAME)
    message("Clean existing ${PACKAGE_NAME} build dir")
    file(GLOB_RECURSE BUILD_SYS_FILES LIST_DIRECTORIES true
        RELATIVE ${BINARY_DIR} ${BINARY_DIR}/*.vcxproj ${BINARY_DIR}/*.sln )
    
    foreach (RELATED_FILE
        CMakeFiles CMakeTmp CMakeScripts cmake_install.cmake CMakeCache.txt
        CTestCustom.cmake ${BUILD_SYS_FILES})
        message("   Deleting ${BINARY_DIR}/${RELATED_FILE} ...")
        file(REMOVE_RECURSE ${BINARY_DIR}/${RELATED_FILE})
    endforeach()
    
    message("   Deleting Stamp and tmp directories...")
    file(REMOVE_RECURSE
        ${SM_3RDPARTY_BUILD_DIR}/Stamp/${PACKAGE_NAME}
        ${SM_3RDPARTY_BUILD_DIR}/tmp/${PACKAGE_NAME}
    )
endfunction()

# Use this function to convert a list of command line style cache initializers
# to a cache preloader script that can be passed to cmake command.
# Each command line style initializer looks like:
# -D<var>:<type>=<value>
#	or
# -D<var>=<value>
# The generated preloader file will be composed of one or more lines looking
# like this:
#
# set(<var> <value> CACHE <type> "..." FORCE)
# set(<var> <value> CACHE <type> "..." FORCE)
# set(<var> <value> CACHE)
# set(<var> <value> CACHE)
# set...
#
# The generated cache preloader file can be passed to the cmake command using:
# cmake -C <initial-cache> ...
function(convert_cmdln_cache_args_to_cache_preloader
    CACHE_PRELOADER_FILE CACHE_ARGS)
    file(WRITE ${CACHE_PRELOADER_FILE} "")

    # The regex to match a single initializer of the form -D<var>:<type>=<value>
    # or -D<var>=<value> with capture groups for var, type, and value
    set(_cache_arg_typed_def_regex "^-D\\s*([a-zA-Z_][0-9a-zA-Z_]*)\
(:(BOOL|FILEPATH|PATH|STRING|INTERNAL))=(.*)")
    set(_cache_arg_typeless_def_regex "^-D\\s*([a-zA-Z_][0-9a-zA-Z_]*)=(.*)")

    # Care must be taken as each of the elements in CACHE_ARGS is not
    # necessarily a cache initializer definition. This is because some cache
    # initializers contain semicolons in their values and the semicolons
    # are interpreted as list separator in CMake. So each item in CACHE_ARGS
    # might be the beginning of an initializer or continuation of that value
    # of the last one.
    foreach(_cache_arg ${CACHE_ARGS})
        string(REGEX MATCH ${_cache_arg_typed_def_regex}
            _matched_arg_typed "${_cache_arg}")
        string(REGEX MATCH ${_cache_arg_typeless_def_regex}
            _matched_arg_typeless "${_cache_arg}")
        if (_matched_arg_typed OR _matched_arg_typeless)
            # Beginning of an initializer
            if (_setter_line_ending)
                # This is not our first initializer. So we have to close the
                # definition for the last one.
                file(APPEND ${CACHE_PRELOADER_FILE} ${_setter_line_ending})
            endif ()

            # For typeless initializers, we'll take the type to be STRING.
            # Otherwise we won't be able to define a cache entry.
            if (_matched_arg_typed)
                string(REGEX REPLACE ${_cache_arg_typed_def_regex}
                    "\\1" _cache_arg_name "${_cache_arg}")
                string(REGEX REPLACE ${_cache_arg_typed_def_regex}
                    "\\3" _cache_arg_type "${_cache_arg}")
                string(REGEX REPLACE ${_cache_arg_typed_def_regex}
                    "\\4" _cache_arg_value "${_cache_arg}")
            else ()
                string(REGEX REPLACE ${_cache_arg_typeless_def_regex}
                    "\\1" _cache_arg_name "${_cache_arg}")
                string(REGEX REPLACE ${_cache_arg_typeless_def_regex}
                    "\\2" _cache_arg_value "${_cache_arg}")
                set(_cache_arg_type STRING)
            endif()

            set(_setter_line_ending " CACHE ${_cache_arg_type} \
\"Generated by convert_cmdln_cache_args_to_cache_preloader\" FORCE)\n")

            # Open new entry definition
            file(APPEND ${CACHE_PRELOADER_FILE}
                "\nset(${_cache_arg_name} \"${_cache_arg_value}\"")
        else ()
            # So this is a continuation of the value of the last initializer.
            # We will just insert the semicolon back in an proceed.
            file(APPEND ${CACHE_PRELOADER_FILE} " ${_cache_arg}")
        endif ()
    endforeach()

    # Close the last entry definition
    if (_setter_line_ending)
        file(APPEND ${CACHE_PRELOADER_FILE} ${_setter_line_ending})
    endif (_setter_line_ending)

endfunction()

# Use the include_build_target_cmake_time function to build the
# specified targets within one or more CMake files during processing of
# the current list.
# Syntax:
# include_build_target_cmake_time(CMAKE_MIN_REQ <min-ver>
#		[PROJ_NAME <proj-name>] [PROJ_PATH <proj-path>]
#		MODULES <module1> [<module2> [<module3> ...]]
#		[TARGETS [<target1> [<target2> [<target3> ...]]]]
#		[CACHE_ARGS [-D<var1>:<type1>=<value1> [-D<var1>:<type1>=<value1> ...]]]
#
# The include_build_target_cmake_time command creates a new CMakeLists file
# using the specified input and then proceeds with configuration and building
# of the specified targets immediately.
# CMAKE_MIN_REQ specifies the minimum version to declare using
# cmake_minimum_required for the created CMakeLists file, e.g. 3.9. If
# specified, cmake_minimum_required(VERSION <min-ver>) will be added to the
# created list file.
# PROJ_NAME specifies an optional name for the project. If specified,
# project(<proj-name>) will be added.
# Use PROJ_PATH to specify a directory for the project to be created in and
# built. If ommitted, a random directory within the current binary directory
# is used for the project.
# MODULES names the list of CMake modules (files) to include within the created
# list file using include command. For each of the modules specified, a line
# of the form include(<moduleN>) is added to the created list file. At least
# one module must be passed.
# Use TARGETS to specify which targets to build after the project has been
# created and configured. If ommitted, the default targets are built.
# Use CACHE_ARGS to initialize the CMake cache for the created project using
# command line style initializers. Since the modules are loaded using CMake
# include command, you should probably initialize CMAKE_MODULE_PATH so the
# module(s) can be located.
# Example:
#	include_build_target_cmake_time(
#		CMAKE_MIN_REQ 3.9
#		PROJ_NAME MyProject
#		MODULES InitModule MainModule
#		CACHE_ARGS
#			-DCMAKE_PREFIX_PATH:STRING=${CMAKE_PREFIX_PATH}
#			-DCMAKE_MODULE_PATH:STRING=${CMAKE_MODULE_PATH}
#	)
function(include_build_target_cmake_time)
    cmake_parse_arguments(INC ""
        "CMAKE_MIN_REQ;PROJ_NAME;PROJ_PATH"
        "MODULES;TARGETS;CACHE_ARGS" ${ARGN})

    if(INC_PROJ_NAME)
        set(_project_line "project(${INC_PROJ_NAME})\n")
    endif()

    if(INC_CMAKE_MIN_REQ)
        set(_version_line
            "cmake_minimum_required(VERSION ${INC_CMAKE_MIN_REQ})\n")
    endif()

    if(NOT INC_MODULES)
        message(WARNING
        "At least one module is needed by include_build_target_cmake_time")
        return()
    else()
        string(REPLACE ";" " " _modules_space_separated "${INC_MODULES}")
    endif()

    set(INC_LIST_FILE_CONTENTS
"${_version_line}${_project_line}\
foreach(_module_name ${_modules_space_separated})
    include(\${_module_name})
endforeach()
")

    if(NOT INC_PROJ_PATH)
        string(RANDOM LENGTH 8 INC_PROJ_PATH)
    endif()

    file(WRITE ${INC_PROJ_PATH}/CMakeLists.txt ${INC_LIST_FILE_CONTENTS})

    convert_cmdln_cache_args_to_cache_preloader(
        ${INC_PROJ_PATH}/InitCache.txt "${INC_CACHE_ARGS}")

    set(_config_command
        ${CMAKE_COMMAND} -C InitCache.txt -G "${CMAKE_GENERATOR}"
        -DCMAKE_GENERATOR_INSTANCE=${CMAKE_GENERATOR_INSTANCE}
    )

    if(CMAKE_GENERATOR_PLATFORM)
        list(APPEND _config_command -A ${CMAKE_GENERATOR_PLATFORM})
    endif()

    if(CMAKE_GENERATOR_PLATFORM)
        list(APPEND _config_command -T ${CMAKE_GENERATOR_TOOLSET})
    endif()

    execute_process(COMMAND ${_config_command} .
        WORKING_DIRECTORY ${INC_PROJ_PATH})

    if(INC_TARGETS)
        foreach(_target ${INC_TARGETS})
            execute_process(
                COMMAND ${CMAKE_COMMAND} --build . --target ${_target}
                WORKING_DIRECTORY ${INC_PROJ_PATH})
        endforeach(_target)
    else()
        execute_process(COMMAND ${CMAKE_COMMAND} --build .
            WORKING_DIRECTORY ${INC_PROJ_PATH})
    endif()

endfunction()

# Output the directory listing for the specified path - useful for debugging
# build on the CI machine.
function(list_dir DIR_PATH)
    file(GLOB  DIR_LIST LIST_DIRECTORIES true RELATIVE ${DIR_PATH} ${DIR_PATH}/*)
    string(REPLACE ";" "\n" DIR_LIST "${DIR_LIST}")
    message("Directory listing for '${DIR_PATH}:'\n${DIR_LIST}\n")
endfunction()

# Create a directory if it doesn't exist.
macro(create_dir_if_not_exists DIR_PATH)
    if(NOT EXISTS ${DIR_PATH})
        file(MAKE_DIRECTORY ${DIR_PATH})
    endif()
endmacro()

# Create a text file within the build directory for 3rd-party libraries with
# information about the build system. This file is necessary because the build
# directory name is a shortened hash of all the build system configuration and
# and the configuration is not obvious from directory name.
macro(create_3rdparty_build_info_file)
    create_dir_if_not_exists(${PROGRAMDATA_DIR})
    create_dir_if_not_exists(${PROGRAMDATA_DIR}/build)
    create_dir_if_not_exists(${SM_3RDPARTY_BUILD_DIR})

    if(NOT EXISTS ${BUILD_INFO_FILE})
        file(WRITE ${BUILD_INFO_FILE}
"Build system info
==================
CMAKE_GENERATOR: ${CMAKE_GENERATOR}
CMAKE_GENERATOR_PLATFORM: ${CMAKE_GENERATOR_PLATFORM}
CMAKE_GENERATOR_TOOLSET: ${CMAKE_GENERATOR_TOOLSET}
")
    endif()
endmacro()

# Determines whether a given path (DESCENDANT_PATH) is a direct or indirect
# descendant of a directory (ANCESTOR_PATH) after resolving symlinks.
function(is_descendant_of_dir RESULT_VAR DESCENDANT_PATH ANCESTOR_PATH)
    get_filename_component(_REAL_ANCESTOR_PATH ${ANCESTOR_PATH} REALPATH)
    get_filename_component(_REAL_DESCENDANT_PATH ${DESCENDANT_PATH} REALPATH)
    get_filename_component(
        _DESCENDANT_PARENT ${_REAL_DESCENDANT_PATH} DIRECTORY)
    if(${_DESCENDANT_PARENT} STREQUAL ${_REAL_ANCESTOR_PATH})
        # Found it
        set(${RESULT_VAR} YES PARENT_SCOPE)
    elseif(${_DESCENDANT_PARENT} STREQUAL ${_REAL_DESCENDANT_PATH})
        # Hit the root directory
        set(${RESULT_VAR} NO PARENT_SCOPE)
    else()
        # Recurse
        is_descendant_of_dir(
            _RECURSION_RESULT ${_DESCENDANT_PARENT} ${_REAL_ANCESTOR_PATH})
        set(${RESULT_VAR} ${_RECURSION_RESULT} PARENT_SCOPE)
    endif()
endfunction()

# Populate the output variable with the list of interface include directories
# for the given target
function(get_target_iface_include_dirs _target _out_var)
    if(NOT TARGET ${_target})
        return()
    endif()

    get_target_property(iface_inc ${_target} INTERFACE_INCLUDE_DIRECTORIES)
    get_target_property(
        iface_sys_inc ${_target} INTERFACE_SYSTEM_INCLUDE_DIRECTORIES)

    set(inc_dir)
    if(iface_inc)
        list(APPEND inc_dir ${iface_inc})
    endif()

    if(iface_sys_inc)
        list(APPEND inc_dir ${iface_sys_inc})
    endif()

    set(${_out_var} ${inc_dir} PARENT_SCOPE)
endfunction()

option(USE_OLD_FINDPACKAGE
    "Whether to use plain old find_package instead of building packages if not found"
    OFF)

function(get_correct_package_name pkg_name result_var)

    if(pkg_name MATCHES Boost)
        set(${result_var} Boost PARENT_SCOPE)
    else()
        string(TOUPPER ${pkg_name} result)
        set(${result_var} ${result} PARENT_SCOPE)
    endif()

endfunction()

function(is_package_include_dirs_acceptable package_name _acceptable_prefix result_var)
    get_correct_package_name(${package_name} correct_package_name)
    list(GET ${correct_package_name}_INCLUDE_DIRS 0 _first_include_dir)
    is_descendant_of_dir(result
        ${_first_include_dir} ${_acceptable_prefix})
    set(${result_var} ${result} PARENT_SCOPE)
endfunction()


function(is_correct_package_found package_name target_name acceptable_prefix result_var)
    
    set(packages_has_include_dirs GTest GMock Boost)

    if(${package_name}_FOUND OR TARGET ${target_name})

        if(package_name IN_LIST packages_has_include_dirs)
            is_package_include_dirs_acceptable(
                ${package_name} 
                ${acceptable_prefix} 
                _correct_package)
        else()
            set(_correct_package YES)
        endif()
        
    else()
        unset(_correct_package)
    endif()

    set(${result_var} ${_correct_package} PARENT_SCOPE)

endfunction()

# We shall use this macro to find a package instead of plain find_package.
# Its syntax is identical to that of find_package.
# It calls the find_package and if the package cannot be found, or if the
# found package include directories are not in the Util third party
# install directory, it includes the relevant module for downloading, building,
# and installing of the package.
# Use the VERIF_TARGET to specify an imported target for verifying
# the finding of the package and the location of include directories.
# Use the EXTRA_PREFIX to specify a supplementary path to be appended to the
# default Util third party install directory. It will accept the package
# only if it is found within that directory and, if not found, it will build
# and install it to that directory.
macro(find_or_get PACKAGE_NAME)
if (USE_OLD_FINDPACKAGE)
    find_package(${PACKAGE_NAME} ${FOG_UNPARSED_ARGUMENTS})
else()
    cmake_parse_arguments(
        FOG "" "VERIF_TARGET;EXTRA_PREFIX" "" ${ARGN})

    set(_push_CMAKE_FIND_FRAMEWORK ${CMAKE_FIND_FRAMEWORK})
    set(_push_CMAKE_FIND_APPBUNDLE ${CMAKE_FIND_APPBUNDLE})
    set(CMAKE_FIND_FRAMEWORK LAST)
    set(CMAKE_FIND_APPBUNDLE LAST)

    # First we need to see if the package can be found, so it a REQUIRED clause
    # is present, we remove it for the time being so the call doesn't fail.
    set(MODIFIED_ARGS ${FOG_UNPARSED_ARGUMENTS})
    if (NOT QUIET IN_LIST MODIFIED_ARGS)
        list(APPEND MODIFIED_ARGS QUIET)
    endif ()

    list(REMOVE_ITEM MODIFIED_ARGS REQUIRED)

    find_package(${PACKAGE_NAME} ${MODIFIED_ARGS})
    if(FOG_VERIF_TARGET)
        get_target_iface_include_dirs(
            ${FOG_VERIF_TARGET} ${PACKAGE_NAME}_INCLUDE_DIRS)
    endif()

    if (FOG_EXTRA_PREFIX)
        set(_acceptable_prefix
            ${SM_3RDPARTY_INSTALL_DIR}/${FOG_EXTRA_PREFIX})
    else ()
        set(_acceptable_prefix ${SM_3RDPARTY_INSTALL_DIR})
    endif ()

    is_correct_package_found(
        ${PACKAGE_NAME} 
        "${FOG_VERIF_TARGET}" 
        ${_acceptable_prefix} 
        _correct_package)

    set(PACKAGE_NAME_INCLUDE_DIRS ${${PACKAGE_NAME}_INCLUDE_DIRS})

    if(_correct_package)
        message("Util built ${PACKAGE_NAME} found at:${PACKAGE_NAME_INCLUDE_DIRS}")
    else()
        # So we have to create and build a new project that includes the module
        # with build targets for retrieving, building, and installing of the
        # package.
        message("Unable to find Util ${PACKAGE_NAME}: Try to build ...")
        set(_ext_proj_path ${CMAKE_BINARY_DIR}/${3RDPARTY_DIR_NAME}/${PACKAGE_NAME})
        file(REMOVE_RECURSE ${_ext_proj_path})

        list(GET MODIFIED_ARGS 0 _find_package_ver_arg)
        if (_find_package_ver_arg VERSION_GREATER 0)
            set(_requested_version_cache_setting
                "-D${PACKAGE_NAME}_REQUESTED_VERSION:\
STRING=${_find_package_ver_arg}")
        else ()
            set(_requested_version_cache_setting)
        endif ()

        list(FIND MODIFIED_ARGS EXACT _exact_ver_requested)
        if(_exact_ver_requested)
            set(_exact_ver_requested_cache_setting
                "-D${PACKAGE_NAME}_REQUESTED_EXACT:BOOL=ON")
        else()
            set(_exact_ver_requested_cache_setting)
        endif()

        if (FOG_EXTRA_PREFIX)
            set(_set_different_install_prefix
                -DEXTRA_PREFIX=${FOG_EXTRA_PREFIX})
        else ()
            set(_set_different_install_prefix)
        endif ()

        create_3rdparty_build_info_file()
        include_build_target_cmake_time(
            CMAKE_MIN_REQ 3.9
            PROJ_NAME Retrieve${PACKAGE_NAME}
            MODULES Retrieve${PACKAGE_NAME}
            PROJ_PATH ${_ext_proj_path}
            CACHE_ARGS
                -DDOWNLOAD_CACHE_DIR=${DOWNLOAD_CACHE_DIR}
                -DSM_3RDPARTY_BUILD_DIR=${SM_3RDPARTY_BUILD_DIR}
                -DSM_3RDPARTY_INSTALL_DIR=${SM_3RDPARTY_INSTALL_DIR}
                -DSM_3RDPARTY_CONFIGURATION_TYPES=${SM_3RDPARTY_CONFIGURATION_TYPES}
                -DCMAKE_PREFIX_PATH:STRING=${CMAKE_PREFIX_PATH}
                -DCMAKE_MODULE_PATH:STRING=${CMAKE_MODULE_PATH}
                -DCMAKE_C_COMPILER:STRING=${CMAKE_C_COMPILER}
                -DCMAKE_CXX_COMPILER:STRING=${CMAKE_CXX_COMPILER}
                -DCMAKE_OSX_DEPLOYMENT_TARGET:STRING=${CMAKE_OSX_DEPLOYMENT_TARGET}
                -DCROSS_COMPILE_FOR_RPI:BOOL=${CROSS_COMPILE_FOR_RPI}
                ${_set_different_install_prefix}
                ${_requested_version_cache_setting}
        )

        # Now it should be safe to call find_package (with the REQUIRED clause
        # if it was ommitted at first)
        find_package(${PACKAGE_NAME} ${FOG_UNPARSED_ARGUMENTS})
    endif()

    set(CMAKE_FIND_APPBUNDLE ${_push_CMAKE_FIND_APPBUNDLE})
    set(CMAKE_FIND_FRAMEWORK ${_push_CMAKE_FIND_FRAMEWORK})
endif()
endmacro()

# If passing a list as the default value, make sure to "qoute" it, Otherwise
# only the first item in the list is taken as the default value and the rest
# are discarded.
macro(set_default_var_value VAR_NAME DEFAULT_VAL)
    if(NOT ${VAR_NAME})
        set(${VAR_NAME} ${DEFAULT_VAL})
    endif()
endmacro()

function(add_ext_proj_patch_step EXT_PROJ_NAME EXT_PROJ_TARGET_NAME)
    set(PATCHED_FILES_DIR ${MODULE_PATH}/patch/${EXT_PROJ_NAME})
    if (EXISTS ${PATCHED_FILES_DIR})
        file(GLOB_RECURSE PATCHED_ITEMS
            LIST_DIRECTORIES true RELATIVE ${PATCHED_FILES_DIR}
            ${PATCHED_FILES_DIR}/*)

        set(PATCH_COMMANDS)
        foreach (PATCHED_ITEM ${PATCHED_ITEMS})
            if(IS_DIRECTORY ${PATCHED_FILES_DIR}/${PATCHED_ITEM})
                list(APPEND PATCH_COMMANDS
                    COMMAND ${CMAKE_COMMAND} -E
                        make_directory ./${PATCHED_ITEM}
                )
            else ()
                list(APPEND PATCH_COMMANDS
                    COMMAND ${CMAKE_COMMAND} -E copy
                        ${PATCHED_FILES_DIR}/${PATCHED_ITEM}
                        ${PATCHED_ITEM}
                )
            endif ()
        endforeach ()

        ExternalProject_Add_Step(
            ${EXT_PROJ_TARGET_NAME} copy_patched_files
            COMMENT
                "Copying patched ${EXT_PROJ_NAME} files to source directory..."
            WORKING_DIRECTORY <SOURCE_DIR>
            DEPENDEES update
            DEPENDERS patch
            ${PATCH_COMMANDS}
        )
    endif ()
endfunction ()

# The add_ext_cmake_project adds a new target that downloads, extracts,
# builds, and installs a CMake based projects. It uses the ExternalProject
# modules and customizes many of its options and adapts them to our needs.
# It will download from the given URL to the given download directory (or
# the default), compares with the given SHA1 hash, extracts it to the given
# source directory (or the default). If it finds a directory with the same name
# as the project under the patch directory in the same directory as
# Util.cmake, it will copy the contents to the source directory as a
# patch step. It then builds the projects in the given configurations (or
# the defaults). It then installs the project to the given directory (or
# the default). Extra CMake cache initializers may also be given.
# The default configuration:
#   * Debug and Release configurations
#   * Static libraries
#   * Download directory:
#       ${PROGRAMDATA_DIR}/cache/Download/<proj-name>
#   * Source directory:
#       ${PROGRAMDATA_DIR}/cache/Source/<proj-name>
#   * Binary directory: ${CMAKE_BINARY_DIR}/Build/<proj-name>
#   * Install prefix: ${PROGRAMDATA_DIR}(64)?
#   * Debug libraries postfixed with `d`
# The following CMake variables are also passed by default to the build
# environment:
#   * CMAKE_PREFIX_PATH
#   * CMAKE_OSX_DEPLOYMENT_TARGET
## Syntax:
#	add_ext_cmake_project(<proj-name>
#		URL <url> SHA1 <sha1> [DOWNLOAD_DIR <dl-dir>] [SOURCE_DIR <src-dir>]
#		[BINARY_DIR <build-dir>] [INSTALL_DIR <inst-dir>]
#		[CONFIGS <Debug|Release|...> ...] [PATCH_COMMAND <patch-cmd>]
#		[EXTRA_CACHE_ARGS
#			[-D<var1>:<type1>=<value1> [-D<var1>:<type1>=<value1> ...]]]
#		[EXTRA_CACHE_ARGS_APPLE
#			[-D<var1>:<type1>=<value1> [-D<var1>:<type1>=<value1> ...]]]
#		[EXTRA_CACHE_ARGS_WIN32
#			[-D<var1>:<type1>=<value1> [-D<var1>:<type1>=<value1> ...]]]
#	)
# Example:
#	add_ext_cmake_project(
#		VTK7
#		URL https://github.com/Kitware/VTK/archive/v7.1.1.tar.gz
#		SHA1 7b60d17db0214de56f6bac73122952f9cbcdc7b2
#		EXTRA_CACHE_ARGS
#			-DVTK_USE_SYSTEM_TIFF:BOOL=ON
#			-DVTK_USE_SYSTEM_ZLIB:BOOL=ON
#	)
function(add_ext_cmake_project EXT_PROJ_NAME)
    set(OPTION_KEYWORDS "")
    set(SINGLE_VALUE_KEYWORDS
        "URL;SHA1;DOWNLOAD_DIR;SOURCE_DIR;BINARY_DIR;\
INSTALL_DIR;SOURCE_SUBDIR;PDB_INSTALL_DIR")
    set(MULTI_VALUE_KEYWORDS
        "CONFIGS;EXTRA_CACHE_ARGS;EXTRA_CACHE_ARGS_APPLE;\
EXTRA_CACHE_ARGS_WIN32;PATCH_COMMAND"
    )
    cmake_parse_arguments(
        EXT_PROJ
        "${OPTION_KEYWORDS}"
        "${SINGLE_VALUE_KEYWORDS}"
        "${MULTI_VALUE_KEYWORDS}"
        ${ARGN}
    )

    string(TOLOWER ${EXT_PROJ_NAME} _ext_proj_name)

    set_default_var_value(EXT_PROJ_DOWNLOAD_DIR
        ${DOWNLOAD_CACHE_DIR}/Download/${_ext_proj_name})

    set_default_var_value(EXT_PROJ_SOURCE_DIR
        ${DOWNLOAD_CACHE_DIR}/Source/${_ext_proj_name})

    set_default_var_value(EXT_PROJ_SOURCE_SUBDIR .)

    set_default_var_value(
        EXT_PROJ_BINARY_DIR ${SM_3RDPARTY_BUILD_DIR}/${_ext_proj_name})

    if (EXTRA_PREFIX)
        set(_default_install_prefix
            ${SM_3RDPARTY_INSTALL_DIR}/${EXTRA_PREFIX})
    else ()
        set(_default_install_prefix ${SM_3RDPARTY_INSTALL_DIR})
    endif ()

    set_default_var_value(
        EXT_PROJ_INSTALL_DIR ${_default_install_prefix})

    set_default_var_value(
        EXT_PROJ_CONFIGS "${SM_3RDPARTY_CONFIGURATION_TYPES}")

    if(TARGET ${_ext_proj_name})
        message(AUTHOR_WARNING
            "Target ${_ext_proj_name} already exists. Giving up...")
        return()
    endif ()

    clean_ext_proj_build_sys_files(${EXT_PROJ_BINARY_DIR} ${_ext_proj_name})

    # Append platform specific extra cache arguments:
    if (APPLE)
        list(APPEND EXT_PROJ_EXTRA_CACHE_ARGS
            ${EXT_PROJ_EXTRA_CACHE_ARGS_APPLE})
    elseif (WIN32)
        list(APPEND EXT_PROJ_EXTRA_CACHE_ARGS
            ${EXT_PROJ_EXTRA_CACHE_ARGS_WIN32})
    endif ()

    set(_pdb_output_dir <BINARY_DIR>/PDBFilesDebug)
    if (MSVC AND EXT_PROJ_PDB_INSTALL_DIR)
        set(_specify_pdb_output_dir
            -DCMAKE_COMPILE_PDB_OUTPUT_DIRECTORY_DEBUG:PATH=${_pdb_output_dir}
        )
    else ()
        set(_specify_pdb_output_dir)
    endif ()

    # The URL HASH created using online facility:
    # 	https://hash.online-convert.com/sha1-generator
    ExternalProject_Add(
        ${_ext_proj_name}
        URL ${EXT_PROJ_URL}
        URL_HASH SHA1=${EXT_PROJ_SHA1}
        DOWNLOAD_DIR ${EXT_PROJ_DOWNLOAD_DIR}
        SOURCE_DIR ${EXT_PROJ_SOURCE_DIR}
        BINARY_DIR ${EXT_PROJ_BINARY_DIR}
        INSTALL_DIR ${EXT_PROJ_INSTALL_DIR}
        SOURCE_SUBDIR ${EXT_PROJ_SOURCE_SUBDIR}
        PATCH_COMMAND ${EXT_PROJ_PATCH_COMMAND}
        BUILD_COMMAND ""	# Multiple custom commands are added instead for
        INSTALL_COMMAND ""	# each platform configuration
        CMAKE_CACHE_DEFAULT_ARGS
            -DCMAKE_INSTALL_PREFIX:STRING=<INSTALL_DIR>
            ${_specify_pdb_output_dir}
            -DBUILD_SHARED_LIBS:BOOL=OFF
            -DBUILD_EXAMPLES:BOOL=OFF
            -DBUILD_TESTING:BOOL=OFF
            -DCMAKE_C_COMPILER:PATH=${CMAKE_C_COMPILER}
            -DCMAKE_CXX_COMPILER:PATH=${CMAKE_CXX_COMPILER}
            "-DCMAKE_CONFIGURATION_TYPES:STRING=${EXT_PROJ_CONFIGS}"
            "-DCMAKE_PREFIX_PATH:STRING=${CMAKE_PREFIX_PATH}"
            -DCMAKE_OSX_DEPLOYMENT_TARGET:STRING=${CMAKE_OSX_DEPLOYMENT_TARGET}
            ${EXT_PROJ_EXTRA_CACHE_ARGS}
    )

    add_ext_proj_patch_step(${EXT_PROJ_NAME} ${_ext_proj_name})

    if (APPLE)
        set(EXTRA_BUILDTOOL_FLAGS)
    elseif (MSVC AND NOT _specify_pdb_output_dir)
        set(EXTRA_BUILDTOOL_FLAGS
            /m  # MSBuild parallel build
        )
    endif ()

    foreach(_build_cfg ${EXT_PROJ_CONFIGS})
        ExternalProject_Add_Step(${_ext_proj_name} build_${_build_cfg}
            COMMENT "Building ${EXT_PROJ_NAME} in configuration ${_build_cfg}"
            COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR>
                --config ${_build_cfg} -- ${EXTRA_BUILDTOOL_FLAGS}
            DEPENDEES configure
            DEPENDERS build
        )
        ExternalProject_Add_Step(${_ext_proj_name} install_${_build_cfg}
            COMMENT "Installing ${EXT_PROJ_NAME} in configuration ${_build_cfg}"
            COMMAND ${CMAKE_COMMAND}
                --build <BINARY_DIR> --target install --config ${_build_cfg}
            DEPENDEES build
            DEPENDERS install
        )
    endforeach()

    if (MSVC AND EXT_PROJ_PDB_INSTALL_DIR)
        if (NOT IS_ABSOLUTE ${EXT_PROJ_PDB_INSTALL_DIR})
            set(EXT_PROJ_PDB_INSTALL_DIR
                <INSTALL_DIR>/${EXT_PROJ_PDB_INSTALL_DIR})
        endif ()
        ExternalProject_Add_Step(${_ext_proj_name} install_pdbs
            COMMENT "Installing ${EXT_PROJ_NAME} debug PDBs"
            COMMAND ${CMAKE_COMMAND} -E
                copy_directory ${_pdb_output_dir} ${EXT_PROJ_PDB_INSTALL_DIR}
            DEPENDEES build
            DEPENDERS install
        )
    endif ()

endfunction()

# If the generator is MSVC, it finds the corresponding vcvarsall.bat and
# stores the path in the output variable. It also appends appropriate arguments
# to the output variable according to the specified ARCH (target architecture)
# and HOST_ARCH (host architecture). If architecture is not specified, current
# architecture will be used for both host and target. Pass the STRING option
# to have the output as a single command line string rather than the usual
# ;-list used in cmake COMMAND arguments.
function(find_vcvarsall _outvar)
    if(NOT MSVC)
        message(AUTHOR_WARNING "find_vcvarsall only works with MSVC!")
        return()
    endif()

    set(options REQUIRED STRING)
    set(oneValueArgs ARCH HOST_ARCH)
    set(multiValueArgs)
    cmake_parse_arguments(SMF
        "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(IS_64_BIT)
        set(_current_arch amd64)
    else()
        set(_current_arch x86)
    endif()

    get_filename_component(_vc_linker_dir ${CMAKE_LINKER} DIRECTORY)
    find_file(_vcvarsall_bat vcvarsall.bat
        ${_vc_linker_dir}/..
        ${_vc_linker_dir}/../..
        # MSVS2017 Community:
        ${_vc_linker_dir}/../../../../../../Auxiliary/Build
        # MSVS2017 Enterprise, etc:
        ${_vc_linker_dir}/../../../../../Auxiliary/Build
    )

    set_default_var_value(SMF_ARCH ${_current_arch})
    set_default_var_value(SMF_HOST_ARCH ${_current_arch})
    if(${SMF_ARCH} STREQUAL ${SMF_HOST_ARCH})
        set(_vcvarsall_arg ${SMF_ARCH})
    else()
        set(_vcvarsall_arg ${SMF_HOST_ARCH}_${SMF_ARCH})
    endif()

    if(SMF_STRING)
        string(REPLACE ";" " " _vcvarsall_arg ${_vcvarsall_arg})
        file(TO_NATIVE_PATH ${_vcvarsall_bat} _vcvarsall_bat)
        set(_vcvars_cmd "CALL \"${_vcvarsall_bat}\" ${_vcvarsall_arg}")
    else()
        set(_vcvars_cmd CALL ${_vcvarsall_bat} ${_vcvarsall_arg})
    endif()

    message("_vcvarsall_bat: ${_vcvarsall_bat}")
    if(_vcvarsall_bat)
        set(${_outvar} ${_vcvars_cmd} PARENT_SCOPE)
    else()
        if (SMF_REQUIRED)
            message(FATAL_ERROR "Failed to locate vcvarsall.bat")
        endif ()
        unset(${_outvar} PARENT_SCOPE)
    endif()
endfunction ()
