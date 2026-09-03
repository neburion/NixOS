# ================================================================================================
# Settings
# ================================================================================================
cmake_minimum_required(VERSION 3.20)
project(project) # Project name
#set(LIBS                          ) # Libraries here...
set(CMAKE_C_STANDARD              23)
set(CMAKE_C_STANDARD_REQUIRED     ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
# Default to Debug
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Debug)
endif()
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/bin)
macro(apply_flags TARGET)
    if(MSVC)
        target_compile_options(${TARGET} PRIVATE
            $<$<CONFIG:Debug>:/W4>)
    else()
        if(APPLE)
            set(SANITIZE_FLAGS -fsanitize=undefined,address)
        else()
            set(SANITIZE_FLAGS -fsanitize=undefined,address,leak)
        endif()
        target_compile_options(${TARGET} PRIVATE
            $<$<CONFIG:Debug>:-Wall -Wextra -Wpedantic ${SANITIZE_FLAGS}>)
        target_link_options(${TARGET} PRIVATE
            $<$<CONFIG:Debug>:${SANITIZE_FLAGS}>)
    endif()
endmacro()
# ================================================================================================
# Sources
# ================================================================================================
file(GLOB_RECURSE SRC        CONFIGURE_DEPENDS src/*.c)
file(GLOB_RECURSE TEST_FILES CONFIGURE_DEPENDS tests/*.c)
list(FILTER SRC EXCLUDE REGEX "src/main.c") # Excludes the main function from SRC for Tests bin
# ================================================================================================
# Main Binary
# ================================================================================================
add_executable            (${PROJECT_NAME} src/main.c ${SRC})
target_include_directories(${PROJECT_NAME} PRIVATE include)
#target_link_libraries     (${PROJECT_NAME} PRIVATE ${LIBS})
apply_flags               (${PROJECT_NAME})
# ================================================================================================
# Test Binary
# ================================================================================================
add_executable            (${PROJECT_NAME}_tests ${TEST_FILES} ${SRC})
target_include_directories(${PROJECT_NAME}_tests PRIVATE include)
#target_link_libraries     (${PROJECT_NAME}_tests PRIVATE ${LIBS})
apply_flags               (${PROJECT_NAME}_tests)
