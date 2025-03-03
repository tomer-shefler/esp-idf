include(ExternalProject)

function(__kconfig_init)
    idf_build_get_property(idf_path IDF_PATH)
    if(CMAKE_HOST_WIN32)
        # Prefer a prebuilt mconf-idf on Windows
        if(DEFINED ENV{MSYSTEM})
            find_program(WINPTY winpty)
        else()
            unset(WINPTY CACHE)  # in case previous CMake run was in a tty and this one is not
        endif()
        unset(MCONF CACHE)  # needed when MSYS and CMD is intermixed (cache could contain an incompatible path)
        find_program(MCONF mconf-idf)

        # Fall back to the old binary which was called 'mconf' not 'mconf-idf'
        if(NOT MCONF)
            find_program(MCONF mconf)
            if(MCONF)
                message(WARNING "Falling back to mconf binary '${MCONF}' not mconf-idf. "
                    "This is probably because an old version of IDF mconf is installed and this is fine. "
                    "However if there are config problems please check the Getting Started guide for your platform.")
            endif()
        endif()

        if(NOT MCONF)
            find_program(NATIVE_GCC gcc)
            if(NOT NATIVE_GCC)
                message(FATAL_ERROR
                    "Windows requires a prebuilt mconf-idf for your platform "
                    "on the PATH, or an MSYS2 version of gcc on the PATH to build mconf-idf. "
                    "Consult the setup docs for ESP-IDF on Windows.")
            endif()
        elseif(WINPTY)
            set(MCONF "\"${WINPTY}\" \"${MCONF}\"")
        endif()
    endif()

    if(NOT MCONF)
        # Use the existing Makefile to build mconf (out of tree) when needed
        #
        set(MCONF ${CMAKE_BINARY_DIR}/kconfig_bin/mconf-idf)

        externalproject_add(mconf-idf
            SOURCE_DIR ${idf_path}/tools/kconfig
            CONFIGURE_COMMAND ""
            BINARY_DIR "kconfig_bin"
            BUILD_COMMAND make -f ${idf_path}/tools/kconfig/Makefile mconf-idf
            BUILD_BYPRODUCTS ${MCONF}
            INSTALL_COMMAND ""
            EXCLUDE_FROM_ALL 1
            )

        file(GLOB mconf_srcfiles ${idf_path}/tools/kconfig/*.c)
        externalproject_add_stepdependencies(mconf-idf build
            ${mconf_srcfiles}
            ${idf_path}/tools/kconfig/Makefile
            ${CMAKE_CURRENT_LIST_FILE})
        unset(mconf_srcfiles)

        set(menuconfig_depends DEPENDS mconf-idf)
    endif()

    idf_build_set_property(__MCONF ${MCONF})
    idf_build_set_property(__MENUCONFIG_DEPENDS "${menuconfig_depends}")

    idf_build_get_property(idf_path IDF_PATH)
    idf_build_set_property(__ROOT_KCONFIG ${idf_path}/Kconfig)
    idf_build_set_property(__OUTPUT_SDKCONFIG 1)
endfunction()

#
# Initialize Kconfig-related properties for components.
# This function assumes that all basic properties of the components have been
# set prior to calling it.
#
function(__kconfig_component_init component_target)
    __component_get_property(component_dir ${component_target} COMPONENT_DIR)
    file(GLOB kconfig "${component_dir}/Kconfig")
    __component_set_property(${component_target} KCONFIG "${kconfig}")
    file(GLOB kconfig "${component_dir}/Kconfig.projbuild")
    __component_set_property(${component_target} KCONFIG_PROJBUILD "${kconfig}")
endfunction()

#
# Generate the config files and create config related targets and configure
# dependencies.
#
function(__kconfig_generate_config sdkconfig sdkconfig_defaults)
    # List all Kconfig and Kconfig.projbuild in known components
    idf_build_get_property(component_targets __COMPONENT_TARGETS)
    idf_build_get_property(build_component_targets __BUILD_COMPONENT_TARGETS)
    foreach(component_target ${component_targets})
        if(component_target IN_LIST build_component_targets)
            __component_get_property(kconfig ${component_target} KCONFIG)
            __component_get_property(kconfig_projbuild ${component_target} KCONFIG_PROJBUILD)
            if(kconfig)
                list(APPEND kconfigs ${kconfig})
            endif()
            if(kconfig_projbuild)
                list(APPEND kconfig_projbuilds ${kconfig_projbuild})
            endif()
        endif()
    endforeach()

    # Store the list version of kconfigs and kconfig_projbuilds
    idf_build_set_property(KCONFIGS "${kconfigs}")
    idf_build_set_property(KCONFIG_PROJBUILDS "${kconfig_projbuilds}")

    idf_build_get_property(idf_target IDF_TARGET)

    if(sdkconfig_defaults)
        set(defaults_arg --defaults "${sdkconfig_defaults}")
    endif()

    if(EXISTS "${sdkconfig_defaults}.${idf_target}")
        list(APPEND defaults_arg --defaults "${sdkconfig_defaults}.${idf_target}")
    endif()

    idf_build_get_property(idf_path IDF_PATH)
    idf_build_get_property(root_kconfig __ROOT_KCONFIG)
    idf_build_get_property(python PYTHON)

    string(REPLACE ";" " " kconfigs "${kconfigs}")
    string(REPLACE ";" " " kconfig_projbuilds "${kconfig_projbuilds}")

    set(confgen_basecommand
        ${python} ${idf_path}/tools/kconfig_new/confgen.py
        --kconfig ${root_kconfig}
        --config ${sdkconfig}
        ${defaults_arg}
        --env "COMPONENT_KCONFIGS=${kconfigs}"
        --env "COMPONENT_KCONFIGS_PROJBUILD=${kconfig_projbuilds}"
        --env "IDF_CMAKE=y"
        --env "IDF_TARGET=${idf_target}")

    idf_build_get_property(build_dir BUILD_DIR)
    set(config_dir ${build_dir}/config)
    file(MAKE_DIRECTORY "${config_dir}")

    # Generate the config outputs
    set(sdkconfig_cmake ${config_dir}/sdkconfig.cmake)
    set(sdkconfig_header ${config_dir}/sdkconfig.h)
    set(sdkconfig_json ${config_dir}/sdkconfig.json)
    set(sdkconfig_json_menus ${config_dir}/kconfig_menus.json)

    idf_build_get_property(output_sdkconfig __OUTPUT_SDKCONFIG)
    if(output_sdkconfig)
        execute_process(
            COMMAND ${confgen_basecommand}
            --output header ${sdkconfig_header}
            --output cmake ${sdkconfig_cmake}
            --output json ${sdkconfig_json}
            --output json_menus ${sdkconfig_json_menus}
            --output config ${sdkconfig}
            RESULT_VARIABLE config_result)
    else()
        execute_process(
            COMMAND ${confgen_basecommand}
            --output header ${sdkconfig_header}
            --output cmake ${sdkconfig_cmake}
            --output json ${sdkconfig_json}
            --output json_menus ${sdkconfig_json_menus}
            RESULT_VARIABLE config_result)
    endif()

    if(config_result)
        message(FATAL_ERROR "Failed to run confgen.py (${confgen_basecommand}). Error ${config_result}")
    endif()

    # Add the generated config header to build specifications.
    idf_build_set_property(INCLUDE_DIRECTORIES ${config_dir} APPEND)

    # When sdkconfig file changes in the future, trigger a cmake run
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${sdkconfig}")

    # Ditto if either of the generated files are missing/modified (this is a bit irritating as it means
    # you can't edit these manually without them being regenerated, but I don't know of a better way...)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${sdkconfig_header}")
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${sdkconfig_cmake}")

    # Or if the config generation tool changes
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${idf_path}/tools/kconfig_new/confgen.py")
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${idf_path}/tools/kconfig_new/kconfiglib.py")

    set_property(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" APPEND PROPERTY
                ADDITIONAL_MAKE_CLEAN_FILES "${sdkconfig_header}" "${sdkconfig_cmake}")

    idf_build_set_property(SDKCONFIG_HEADER ${sdkconfig_header})
    idf_build_set_property(SDKCONFIG_JSON ${sdkconfig_json})
    idf_build_set_property(SDKCONFIG_CMAKE ${sdkconfig_cmake})
    idf_build_set_property(SDKCONFIG_JSON_MENUS ${sdkconfig_json_menus})
    idf_build_set_property(CONFIG_DIR ${config_dir})

    idf_build_get_property(menuconfig_depends __MENUCONFIG_DEPENDS)

    idf_build_get_property(mconf __MCONF)

    # Generate the menuconfig target (uses C-based mconf-idf tool, either prebuilt or via mconf-idf target above)
    add_custom_target(menuconfig
        ${menuconfig_depends}
        # create any missing config file, with defaults if necessary
        COMMAND ${confgen_basecommand} --env "IDF_TARGET=${idf_target}" --output config ${sdkconfig}
        COMMAND ${CMAKE_COMMAND} -E env
        "COMPONENT_KCONFIGS=${kconfigs}"
        "COMPONENT_KCONFIGS_PROJBUILD=${kconfig_projbuilds}"
        "IDF_CMAKE=y"
        "KCONFIG_CONFIG=${sdkconfig}"
        "IDF_TARGET=${idf_target}"
        ${mconf} ${root_kconfig}
        # VERBATIM cannot be used here because it cannot handle ${mconf}="winpty mconf-idf" and the escaping must be
        # done manually
        USES_TERMINAL
        # additional run of confgen esures that the deprecated options will be inserted into sdkconfig (for backward
        # compatibility)
        COMMAND ${confgen_basecommand} --env "IDF_TARGET=${idf_target}" --output config ${sdkconfig}
        )

    # Custom target to run confserver.py from the build tool
    add_custom_target(confserver
        COMMAND ${CMAKE_COMMAND} -E env
        "COMPONENT_KCONFIGS=${kconfigs}"
        "COMPONENT_KCONFIGS_PROJBUILD=${kconfig_projbuilds}"
        ${PYTHON} ${IDF_PATH}/tools/kconfig_new/confserver.py --kconfig ${IDF_PATH}/Kconfig --config ${sdkconfig}
        VERBATIM
        USES_TERMINAL)
endfunction()
