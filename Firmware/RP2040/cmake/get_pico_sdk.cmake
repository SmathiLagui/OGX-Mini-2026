function(get_pico_sdk EXTERNAL_DIR VERSION_TAG)
    if(NOT DEFINED ENV{PICO_SDK_PATH})
        set(SDK_DIR ${EXTERNAL_DIR}/pico-sdk)

        if(NOT EXISTS ${SDK_DIR})
            message(STATUS "Cloning pico-sdk to ${SDK_DIR}")
            execute_process(
                COMMAND git clone --recursive https://github.com/raspberrypi/pico-sdk.git
                WORKING_DIRECTORY ${EXTERNAL_DIR}
                RESULT_VARIABLE CLONE_RESULT
            )
            if(NOT CLONE_RESULT EQUAL 0)
                message(FATAL_ERROR "Failed to clone pico-sdk")
            endif()
        endif()

        execute_process(
            COMMAND git fetch --tags
            WORKING_DIRECTORY ${SDK_DIR}
        )

        execute_process(
            COMMAND git checkout tags/${VERSION_TAG}
            WORKING_DIRECTORY ${SDK_DIR}
        )

        execute_process(
            COMMAND git submodule update --init --recursive
            WORKING_DIRECTORY ${SDK_DIR}
        )

        set(PICO_SDK_PATH ${SDK_DIR} PARENT_SCOPE)
    else()
        message(STATUS "Using PICO_SDK_PATH from environment: $ENV{PICO_SDK_PATH}")
        set(PICO_SDK_PATH $ENV{PICO_SDK_PATH} PARENT_SCOPE)
    endif()

    set(PICOTOOL_FETCH_FROM_GIT_PATH ${EXTERNAL_DIR}/picotool PARENT_SCOPE)
endfunction()