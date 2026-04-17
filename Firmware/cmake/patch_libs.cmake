function(apply_lib_patches EXTERNAL_DIR)
    set(BTSTACK_PATCH "${EXTERNAL_DIR}/patches/btstack_l2cap.diff")
    set(BTSTACK_PATH "${EXTERNAL_DIR}/bluepad32/external/btstack")

    message(STATUS "Applying BTStack patch: ${BTSTACK_PATCH}")

    execute_process(
        COMMAND git apply --check --ignore-whitespace ${BTSTACK_PATCH}
        WORKING_DIRECTORY ${BTSTACK_PATH}
        RESULT_VARIABLE BTSTACK_CHECK_RESULT
    )
    if (BTSTACK_CHECK_RESULT EQUAL 0)
        execute_process(
            COMMAND git apply --ignore-whitespace ${BTSTACK_PATCH}
            WORKING_DIRECTORY ${BTSTACK_PATH}
            RESULT_VARIABLE BTSTACK_PATCH_RESULT
            ERROR_VARIABLE BTSTACK_PATCH_ERROR
        )
        if (BTSTACK_PATCH_RESULT EQUAL 0)
            message(STATUS "BTStack patch applied successfully.")
        else ()
            message(FATAL_ERROR "Failed to apply BTStack patch: ${BTSTACK_PATCH_ERROR}")
        endif ()
    else ()
        execute_process(
            COMMAND git apply --check --reverse --ignore-whitespace ${BTSTACK_PATCH}
            WORKING_DIRECTORY ${BTSTACK_PATH}
            RESULT_VARIABLE BTSTACK_REV_RESULT
        )
        if (BTSTACK_REV_RESULT EQUAL 0)
            message(STATUS "BTStack patch already applied.")
        else ()
            message(FATAL_ERROR "Failed to apply BTStack patch: patch does not apply forward or in reverse.")
        endif ()
    endif ()

    set(BLUEPAD32_PATCH "${EXTERNAL_DIR}/patches/bluepad32_uni.diff")
    set(BLUEPAD32_PATH "${EXTERNAL_DIR}/bluepad32")

    message(STATUS "Applying Bluepad32 patch: ${BLUEPAD32_PATCH}")

    execute_process(
        COMMAND git apply --check --ignore-whitespace ${BLUEPAD32_PATCH}
        WORKING_DIRECTORY ${BLUEPAD32_PATH}
        RESULT_VARIABLE BLUEPAD32_CHECK_RESULT
    )
    if (BLUEPAD32_CHECK_RESULT EQUAL 0)
        execute_process(
            COMMAND git apply --ignore-whitespace ${BLUEPAD32_PATCH}
            WORKING_DIRECTORY ${BLUEPAD32_PATH}
            RESULT_VARIABLE BLUEPAD32_PATCH_RESULT
            ERROR_VARIABLE BLUEPAD32_PATCH_ERROR
        )
        if (BLUEPAD32_PATCH_RESULT EQUAL 0)
            message(STATUS "Bluepad32 patch applied successfully.")
        else ()
            message(FATAL_ERROR "Failed to apply Bluepad32 patch: ${BLUEPAD32_PATCH_ERROR}")
        endif ()
    else ()
        execute_process(
            COMMAND git apply --check --reverse --ignore-whitespace ${BLUEPAD32_PATCH}
            WORKING_DIRECTORY ${BLUEPAD32_PATH}
            RESULT_VARIABLE BLUEPAD32_REV_RESULT
        )
        if (BLUEPAD32_REV_RESULT EQUAL 0)
            message(STATUS "Bluepad32 patch already applied.")
        else ()
            message(FATAL_ERROR "Failed to apply Bluepad32 patch: patch does not apply forward or in reverse.")
        endif ()
    endif ()

    set(PIOASM_PATCH "${EXTERNAL_DIR}/patches/pico_sdk_pioasm.diff")
    set(PIOASM_PATH "${EXTERNAL_DIR}/pico-sdk")

    if (EXISTS ${PIOASM_PATH}/tools/pioasm/pio_types.h)
        message(STATUS "Applying pico-sdk pioasm patch: ${PIOASM_PATCH}")

        execute_process(
            COMMAND git apply --check --ignore-whitespace ${PIOASM_PATCH}
            WORKING_DIRECTORY ${PIOASM_PATH}
            RESULT_VARIABLE PIOASM_CHECK_RESULT
        )
        if (PIOASM_CHECK_RESULT EQUAL 0)
            execute_process(
                COMMAND git apply --ignore-whitespace ${PIOASM_PATCH}
                WORKING_DIRECTORY ${PIOASM_PATH}
                RESULT_VARIABLE PIOASM_PATCH_RESULT
                ERROR_VARIABLE PIOASM_PATCH_ERROR
            )
            if (PIOASM_PATCH_RESULT EQUAL 0)
                message(STATUS "pico-sdk pioasm patch applied successfully.")
            else ()
                message(FATAL_ERROR "Failed to apply pico-sdk pioasm patch: ${PIOASM_PATCH_ERROR}")
            endif ()
        else ()
            execute_process(
                COMMAND git apply --check --reverse --ignore-whitespace ${PIOASM_PATCH}
                WORKING_DIRECTORY ${PIOASM_PATH}
                RESULT_VARIABLE PIOASM_REV_RESULT
            )
            if (PIOASM_REV_RESULT EQUAL 0)
                message(STATUS "pico-sdk pioasm patch already applied.")
            else ()
                message(FATAL_ERROR "Failed to apply pico-sdk pioasm patch: patch does not apply forward or in reverse.")
            endif ()
        endif ()
    endif ()

endfunction()