############################################################################
#    Copyright (C) 2009 by Ralf 'Decan' Kaestner                           #
#    ralf.kaestner@gmail.com                                               #
#                                                                          #
#    This program is free software; you can redistribute it and#or modify  #
#    it under the terms of the GNU General Public License as published by  #
#    the Free Software Foundation; either version 2 of the License, or     #
#    (at your option) any later version.                                   #
#                                                                          #
#    This program is distributed in the hope that it will be useful,       #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
#    GNU General Public License for more details.                          #
#                                                                          #
#    You should have received a copy of the GNU General Public License     #
#    along with this program; if not, write to the                         #
#    Free Software Foundation, Inc.,                                       #
#    59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             #
############################################################################

include(ReMakeProject)
include(ReMakeFind)
include(ReMakeFile)
include(ReMakeComponent)
include(ReMakePython)

include(ReMakePrivate)

### \brief ReMake ROS build macros
#   The ReMake ROS build macros provide access to the ROS build system
#   configuration without requirement for the ROS CMake API. Note that
#   all ROS environment variables should be initialized by sourcing the
#   corresponding ROS setup script prior to calling CMake.

if(NOT DEFINED REMAKE_ROS_CMAKE)
  remake_set(REMAKE_ROS_CMAKE ON)

  remake_set(REMAKE_ROS_DIR ReMakeROS)
  remake_set(REMAKE_ROS_STACK_DIR ${REMAKE_ROS_DIR}/stacks)
  remake_set(REMAKE_ROS_PACKAGE_DIR ${REMAKE_ROS_DIR}/packages)
  remake_set(REMAKE_ROS_FILENAME_PREFIX ros)
  remake_set(REMAKE_ROS_ALL_MANIFESTS_TARGET ros_manifests)
  remake_set(REMAKE_ROS_STACK_MANIFEST_TARGET_SUFFIX ros_stack_manifest)
  remake_set(REMAKE_ROS_PACKAGE_MANIFEST_TARGET_SUFFIX ros_package_manifest)
  remake_set(REMAKE_ROS_PACKAGE_MESSAGES_TARGET_SUFFIX ros_messages)
  remake_set(REMAKE_ROS_PACKAGE_SERVICES_TARGET_SUFFIX ros_services)

  remake_file_rmdir(${REMAKE_ROS_STACK_DIR} TOPLEVEL)
  remake_file_rmdir(${REMAKE_ROS_PACKAGE_DIR} TOPLEVEL)

  remake_project_unset(ROS_STACKS CACHE)
  remake_project_unset(ROS_PACKAGES CACHE)
endif(NOT DEFINED REMAKE_ROS_CMAKE)

### \brief Configure the ROS build system.
#   This macro discovers ROS from its environment variables, initializes
#   ${ROS_PATH}, ${ROS_DISTRIBUTION}, and ${ROS_PACKAGE_PATH}. Note that the
#   macro automatically gets invoked by the macros defined in this module.
#   It needs not be called directly from a CMakeLists.txt file.
macro(remake_ros)
  if(NOT ROS_FOUND)
    remake_find_file(include/ros/ros.h PACKAGE ROS PATHS "$ENV{ROS_ROOT}/..")
    remake_set(ROS_DISTRIBUTION $ENV{ROS_DISTRO} CACHE STRING
      "Name of the ROS distribution.")
    remake_set(ros_package_path $ENV{ROS_PACKAGE_PATH})
    if(ros_package_path)
      string(REGEX REPLACE ":" ";" ros_package_path ${ros_package_path})
    endif(ros_package_path)
    remake_set(ROS_PACKAGE_PATH ${ros_package_path} CACHE STRING
      "Paths to the ROS packages.")
  endif(NOT ROS_FOUND)

  if(NOT ROS_DISTRIBUTION)
    message(FATAL_ERROR "ROS distribution is undefined.")
  endif(NOT ROS_DISTRIBUTION)

  if(ROS_FOUND)
    if(${ROS_DISTRIBUTION} STRLESS groovy)
      remake_file_mkdir(${REMAKE_ROS_STACK_DIR} TOPLEVEL)
    endif(${ROS_DISTRIBUTION} STRLESS groovy)
    remake_file_mkdir(${REMAKE_ROS_PACKAGE_DIR} TOPLEVEL)
  endif(ROS_FOUND)
endmacro(remake_ros)

### \brief Find a ROS stack.
#   Depending on the indicated ROS distribution, this macro discovers a
#   ROS stack or meta-package in the distribution under ${ROS_PATH} or the
#   project. Regarding future portability, its use should however be avoided
#   in favor of remake_ros_find_package(). For ROS "groovy" and later
#   distributions, remake_ros_find_stack() is silently diverted to
#   remake_ros_find_package(). The macro calls rosstack to search all stacks
#   installed on the build system. If the corresponding ROS stack was found,
#   it sets the variable name conversion of ROS_${NAME}_FOUND to TRUE and
#   initializes ROS_${NAME}_PATH accordingly. All packages contained in the
#   ROS stack are further searched by remake_ros_find_package(), and the
#   corresponding package-specific result variables are concatenated to
#   initialize ROS_${NAME}_INCLUDE_DIRS, ROS_${NAME}_LIBRARIES, and
#   ROS_${STACK}_LIBRARY_DIRS.
#   \required[value] name The name of the ROS stack to be discovered.
#   \optional[option] OPTIONAL If provided, this option is passed on to
#     remake_find_result().
macro(remake_ros_find_stack ros_name)
  remake_arguments(PREFIX ros_ OPTION OPTIONAL ${ARGN})
  remake_set(ros_optional ${OPTIONAL})

  remake_ros()

  if(${ROS_DISTRIBUTION} STRLESS groovy)
    remake_find_executable(rosstack PATHS "${ROS_PATH}/bin")

    remake_var_name(ros_stack_path_var ROS ${ros_name} PATH)
    remake_var_name(ros_stack_include_dirs_var ROS ${ros_name} INCLUDE_DIRS)
    remake_var_name(ros_stack_libraries_var ROS ${ros_name} LIBRARIES)
    remake_var_name(ros_stack_library_dirs_var ROS ${ros_name} LIBRARY_DIRS)
    remake_unset(ros_stack_include_dirs ros_stack_libraries
      ros_stack_library_dirs)

    execute_process(
      COMMAND ${ROSSTACK_EXECUTABLE} find ${ros_name}
      RESULT_VARIABLE ros_result
      OUTPUT_VARIABLE ${ros_stack_path_var}
      OUTPUT_STRIP_TRAILING_WHITESPACE
      ERROR_QUIET)

    if(ros_result)
      remake_set(${ros_stack_path_var} ${ros_stack_path_var}-NOTFOUND)
    else(ros_result)
      execute_process(
        COMMAND ${ROSSTACK_EXECUTABLE} contents ${ros_name}
        OUTPUT_VARIABLE ros_packages
        OUTPUT_STRIP_TRAILING_WHITESPACE)
      if(ros_packages)
        string(REGEX REPLACE "[ \n]+" ";" ros_packages ${ros_packages})
      endif(ros_packages)

      foreach(ros_package ${ros_packages})
        remake_var_name(ros_pkg_include_dirs_var ROS ${ros_package}
          INCLUDE_DIRS)
        remake_var_name(ros_pkg_libraries_var ROS ${ros_package} LIBRARIES)
        remake_var_name(ros_pkg_library_dirs_var ROS ${ros_package}
          LIBRARY_DIRS)

        remake_ros_find_package(${ros_package} ${ros_optional})

        remake_list_push(ros_stack_include_dirs
          ${${ros_pkg_include_dirs_var}})
        remake_list_push(ros_stack_libraries ${${ros_pkg_libraries_var}})
        remake_list_push(ros_stack_library_dirs
          ${${ros_pkg_library_dirs_var}})
      endforeach(ros_package ${ros_packages})
    endif(ros_result)

    remake_find_result(${ros_name} ${${ros_stack_path_var}}
      TYPE "ROS stack" ${ros_optional})

    remake_set(${ros_stack_path_var} ${${ros_stack_path_var}}
      CACHE PATH "Path to ROS stack ${ros_name}.")
    remake_set(${ros_stack_include_dirs_var} ${ros_stack_include_dirs}
      CACHE INTERNAL "Include directories of ROS stack ${ros_name}.")
    remake_set(${ros_stack_libraries_var} ${ros_stack_libraries}
      CACHE INTERNAL "Libraries of ROS stack ${ros_name}.")
    remake_set(${ros_stack_library_dirs_var} ${ros_stack_library_dirs}
      CACHE INTERNAL "Library directories of ROS stack ${ros_name}.")
  else(${ROS_DISTRIBUTION} STRLESS groovy)
    remake_ros_find_package(${ros_name} ${ros_optional})
  endif(${ROS_DISTRIBUTION} STRLESS groovy)
endmacro(remake_ros_find_stack)

### \brief Find a ROS package.
#   Depending on the indicated ROS distribution and the provided arguments,
#   this macro discovers a ROS package, meta-package, or stack in the
#   distribution under ${ROS_PATH}. Regarding future portability, its use is
#   strongly encouraged over remake_ros_find_stack(). For ROS "fuerte" and
#   earlier distributions, remake_ros_find_package() is silently diverted to
#   remake_ros_find_stack() if the META option is present. The macro calls
#   rospack to search all packages installed on the build system. If the
#   corresponding ROS package was found, the variable name conversion of
#   ROS_${NAME}_FOUND is set to TRUE, and ROS_${NAME}_PATH,
#   ROS_${NAME}_INCLUDE_DIRS, ROS_${NAME}_LIBRARIES, and
#   ROS_${NAME}_LIBRARY_DIRS are initialized accordingly.
#   \required[value] name The name of the ROS package to be discovered.
#   \optional[option] OPTIONAL If provided, this option is passed on to
#     remake_find_result().
#   \optional[option] META If provided, the macro will be aware that the
#     package is a meta-package. For ROS "groovy" and later distributions,
#     the option is meaningless, whereas it ensures portability for ROS
#     "fuerte" and earlier distributions.
macro(remake_ros_find_package ros_name)
  remake_arguments(PREFIX ros_ OPTION OPTIONAL OPTION META ${ARGN})
  remake_set(ros_optional ${OPTIONAL})

  remake_ros()

  if(NOT ${ROS_DISTRIBUTION} STRLESS groovy OR NOT ros_meta)
    remake_find_executable(rospack PATHS "${ROS_PATH}/bin")

    remake_var_name(ros_pkg_path_var ROS ${ros_name} PATH)
    remake_var_name(ros_pkg_include_dirs_var ROS ${ros_name} INCLUDE_DIRS)
    remake_var_name(ros_pkg_libraries_var ROS ${ros_name} LIBRARIES)
    remake_var_name(ros_pkg_library_dirs_var ROS ${ros_name} LIBRARY_DIRS)

    execute_process(
      COMMAND ${ROSPACK_EXECUTABLE} find ${ros_name}
      RESULT_VARIABLE ros_result
      OUTPUT_VARIABLE ${ros_pkg_path_var}
      OUTPUT_STRIP_TRAILING_WHITESPACE
      ERROR_QUIET)

    if(ros_result)
      remake_set(${ros_pkg_path_var} ${ros_pkg_path_var}-NOTFOUND)
    else(ros_result)
      execute_process(
        COMMAND ${ROSPACK_EXECUTABLE} cflags-only-I ${ros_name}
        OUTPUT_VARIABLE ros_pkg_include_dirs
        OUTPUT_STRIP_TRAILING_WHITESPACE)
      execute_process(
        COMMAND ${ROSPACK_EXECUTABLE} libs-only-l ${ros_name}
        OUTPUT_VARIABLE ros_pkg_libraries
        OUTPUT_STRIP_TRAILING_WHITESPACE)
      execute_process(
        COMMAND ${ROSPACK_EXECUTABLE} libs-only-L ${ros_name}
        OUTPUT_VARIABLE ros_pkg_library_dirs
        OUTPUT_STRIP_TRAILING_WHITESPACE)

      if(ros_pkg_include_dirs)
        string(REGEX REPLACE "[ ]+" ";" ros_pkg_include_dirs
          ${ros_pkg_include_dirs})
        remake_include(${${ros_include_dirs_var}})
      endif(ros_pkg_include_dirs)
      if(ros_pkg_libraries)
        string(REGEX REPLACE "[ ]+" ";" ros_pkg_libraries
          ${ros_pkg_libraries})
      endif(ros_pkg_libraries)
      if(ros_pkg_library_dirs)
        string(REGEX REPLACE "[ ]+" ";" ros_pkg_library_dirs
          ${ros_pkg_library_dirs})
        link_directories(${ros_pkg_library_dirs})
      endif(ros_pkg_library_dirs)

      remake_set(${ros_pkg_path_var} ${${ros_pkg_path_var}}
        CACHE PATH "Path to ROS package ${ros_name}.")
      remake_set(${ros_pkg_include_dirs_var} ${ros_pkg_include_dirs}
        CACHE INTERNAL "Include directories of ROS package ${ros_name}.")
      remake_set(${ros_pkg_libraries_var} ${ros_pkg_libraries}
        CACHE INTERNAL "Libraries of ROS package ${ros_name}.")
      remake_set(${ros_pkg_library_dirs_var} ${ros_pkg_library_dirs}
        CACHE INTERNAL "Library directories of ROS package ${ros_name}.")
    endif(ros_result)

    remake_find_result(${ros_name} ${${ros_pkg_path_var}}
      TYPE "ROS package" ${ros_optional})
  else(NOT ${ROS_DISTRIBUTION} STRLESS groovy OR NOT ros_meta)
    remake_ros_find_stack(${ros_name} ${ros_optional})
  endif(NOT ${ROS_DISTRIBUTION} STRLESS groovy OR NOT ros_meta)
endmacro(remake_ros_find_package)

### \brief Define the value of a ROS stack variable.
#   This macro defines a ROS stack variable matching the ReMake naming
#   conventions. The variable name is automatically prefixed with an
#   upper-case conversion of the stack name. Thus, variables may
#   appear in the cache as project variables named after
#   ${STACK_NAME}_STACK_${VAR_NAME}. Additional arguments are
#   passed on to remake_project_set(). Note that the ROS stack needs
#   to be defined.
#   \required[value] name The name of the ROS stack for which the
#     variable shall be defined.
#   \required[value] variable The name of the stack variable to be
#     defined.
#   \optional[list] arg The arguments to be passed on to remake_project_set().
#      See ReMakeProject for details.
macro(remake_ros_stack_set ros_name ros_var)
  remake_project_get(ROS_STACKS OUTPUT ros_stacks)
  list(FIND ros_stacks ${ros_name} ros_index)

  if(ros_index GREATER -1)
    remake_var_name(ros_stack_var ${ros_name} STACK ${ros_var})
    remake_project_set(${ros_stack_var} ${ARGN})
  else(ros_index GREATER -1)
    message(FATAL_ERROR "ROS stack ${ros_name} undefined!")
  endif(ros_index GREATER -1)
endmacro(remake_ros_stack_set)

### \brief Retrieve the value of a ROS stack variable.
#   This macro retrieves a ROS stack variable matching the ReMake
#   naming conventions. Specifically, variables named after
#   ${STACK_NAME}_STACK_${VAR_NAME} can be found by passing ${VAR_NAME}
#   to this macro. Note that the component needs to be defined.
#   \required[value] name The name of the ROS stack to retrieve the
#     variable value for.
#   \required[value] variable The name of the stack variable to retrieve
#     the value for.
#   \optional[value] OUTPUT:variable The optional name of an output variable
#     that will be assigned the value of the queried stack variable.
macro(remake_ros_stack_get ros_name ros_var)
  remake_arguments(PREFIX ros_ VAR OUTPUT ${ARGN})

  remake_project_get(ROS_STACKS OUTPUT ros_stacks)
  list(FIND ros_stacks ${ros_name} ros_index)

  if(ros_index GREATER -1)
    remake_var_name(ros_stack_var ${ros_name} STACK ${ros_var})
    remake_set(ros_output SELF DEFAULT ${ros_var})

    remake_project_get(${ros_stack_var} OUTPUT ${ros_output})
  else(ros_index GREATER -1)
    message(FATAL_ERROR "ROS stack ${ros_name} undefined!")
  endif(ros_index GREATER -1)
endmacro(remake_ros_stack_get)

### \brief Define the value of a ROS package variable.
#   This macro defines a ROS package variable matching the ReMake naming
#   conventions. The variable name is automatically prefixed with an
#   upper-case conversion of the package name. Thus, variables may
#   appear in the cache as project variables named after
#   ${PACKAGE_NAME}_PACKAGE_${VAR_NAME}. Additional arguments are
#   passed on to remake_project_set(). Note that the ROS package needs
#   to be defined.
#   \required[value] name The name of the ROS package for which the
#     variable shall be defined.
#   \required[value] variable The name of the package variable to be
#     defined.
#   \optional[list] arg The arguments to be passed on to remake_project_set().
#      See ReMakeProject for details.
macro(remake_ros_package_set ros_name ros_var)
  remake_project_get(ROS_PACKAGES OUTPUT ros_packages)
  list(FIND ros_packages ${ros_name} ros_index)

  if(ros_index GREATER -1)
    remake_var_name(ros_package_var ${ros_name} PACKAGE ${ros_var})
    remake_project_set(${ros_package_var} ${ARGN})
  else(ros_index GREATER -1)
    message(FATAL_ERROR "ROS package ${ros_name} undefined!")
  endif(ros_index GREATER -1)
endmacro(remake_ros_package_set)

### \brief Retrieve the value of a ROS package variable.
#   This macro retrieves a ROS package variable matching the ReMake
#   naming conventions. Specifically, variables named after
#   ${PACKAGE_NAME}_PACKAGE_${VAR_NAME} can be found by passing ${VAR_NAME}
#   to this macro. Note that the component needs to be defined.
#   \required[value] name The name of the ROS package to retrieve the
#     variable value for.
#   \required[value] variable The name of the package variable to retrieve
#     the value for.
#   \optional[value] OUTPUT:variable The optional name of an output variable
#     that will be assigned the value of the queried package variable.
macro(remake_ros_package_get ros_name ros_var)
  remake_arguments(PREFIX ros_ VAR OUTPUT ${ARGN})

  remake_project_get(ROS_PACKAGES OUTPUT ros_packages)
  list(FIND ros_packages ${ros_name} ros_index)

  if(ros_index GREATER -1)
    remake_var_name(ros_package_var ${ros_name} PACKAGE ${ros_var})
    remake_set(ros_output SELF DEFAULT ${ros_var})

    remake_project_get(${ros_package_var} OUTPUT ${ros_output})
  else(ros_index GREATER -1)
    message(FATAL_ERROR "ROS package ${ros_name} undefined!")
  endif(ros_index GREATER -1)
endmacro(remake_ros_package_get)

### \brief Define a ROS stack or meta-package.
#   Depending on the indicated ROS distribution, this macro defines a ROS
#   stack or meta-package. Regarding future portability, its use should
#   however be avoided in favor of remake_ros_package(). For ROS "groovy"
#   and later distributions, remake_ros_stack() is silently diverted to
#   remake_ros_package(). Otherwise, the macro initializes the required
#   stack variables and defines a rule for generating the stack manifest.
#   \required[value] name The name of the ROS stack to be defined. Note
#     that, in order for the stack name to be valid, it may not contain
#     certain characters. See the ROS documentation for details.
#   \optional[value] COMPONENT:component The optional name of the install
#     component that will be assigned the stack build and install rules.
#     If no component name is provided, it will default to component name
#     conversion of the provided stack name. See ReMakeComponent for details.
#   \optional[value] DESCRIPTION:string An optional description of the ROS
#     stack which is appended to the project summary when inscribed into the
#     stack manifest.
#   \optional[list] SOURCES:dir The name of a directory containing the
#     sources of the ROS stack and defaulting to the stack name. The
#     directory will be recursed by remake_add_directories() with the
#     respective component set.
#   \optional[list] DEPENDS:stack A list naming the dependencies of the
#     defined ROS stack, defaulting to ros and ros_comm. This list will be
#     passed to remake_ros_stack_add_dependencies(). Note that, for
#     ROS "fuerte" and earlier distributions, stacks may only specify
#     dependencies on other stacks.
macro(remake_ros_stack ros_name)
  remake_arguments(PREFIX ros_ VAR COMPONENT VAR DESCRIPTION VAR SOURCES
    LIST DEPENDS ${ARGN})
  string(REGEX REPLACE "_" "-" ros_default_component ${ros_name})
  remake_set(ros_component SELF DEFAULT ${ros_default_component})
  remake_set(ros_sources SELF DEFAULT ${ros_name})
  remake_set(ros_depends SELF DEFAULT ros ros_comm)

  remake_ros()

  if(${ROS_DISTRIBUTION} STRLESS groovy)
    remake_project_get(ROS_STACKS OUTPUT ros_stacks)
    list(FIND ros_stacks ${ros_name} ros_index)
    if(NOT ros_index LESS 0)
      message(FATAL_ERROR "ROS stack ${ros_name} multiply defined!")
    endif(NOT ros_index LESS 0)
    remake_project_set(ROS_STACKS ${ros_stacks} ${ros_name}
      CACHE INTERNAL "ROS stacks defined by the project.")

    remake_file(ros_stack_dir ${REMAKE_ROS_STACK_DIR}/${ros_name} TOPLEVEL)
    remake_file_mkdir(${ros_stack_dir})
    remake_file_name(ros_filename
      ${REMAKE_ROS_FILENAME_PREFIX}-${ROS_DISTRIBUTION}-${ros_name})
    remake_file_name(ros_dest_dir ${ros_name})
    remake_set(ros_dest_root ${ROS_PATH}/share)

    string(REGEX REPLACE "[.]$" "" ros_summary ${REMAKE_PROJECT_SUMMARY})
    if(ros_description)
      remake_set(ros_summary "${ros_summary} (${ros_description})")
    endif(ros_description)

    remake_set(ros_manifest_head
      "<stack>"
      "  <description brief=\"${ros_summary}\"/>")
    string(REPLACE ", " ";" ros_authors "${REMAKE_PROJECT_AUTHORS}")
    foreach(ros_author ${ros_authors})
      remake_list_push(ros_manifest_head "  <author>${ros_author}</author>")
    endforeach(ros_author ${ros_authors})
    remake_set(ros_contact ${REMAKE_PROJECT_CONTACT})
    list(GET ros_authors 0 ros_maintainer)
    remake_list_push(ros_manifest_head
      "  <maintainer email=\"${ros_contact}\">${ros_maintainer}</maintainer>"
      "  <license>${REMAKE_PROJECT_LICENSE}</license>"
      "  <url>${REMAKE_PROJECT_HOME}</url>")
    remake_set(ros_manifest_tail "</stack>")

    remake_set(ros_manifest ${ros_stack_dir}/stack.xml)
    remake_ros_stack_set(${ros_name} MANIFEST ${ros_manifest}
      CACHE INTERNAL "Manifest file of ${ros_name} ROS stack.")
    remake_file_mkdir(${ros_manifest}.d)
    remake_file_write(${ros_manifest}.d/00-head
      LINES ${ros_manifest_head})
    remake_file_write(${ros_manifest}.d/99-tail
      LINES ${ros_manifest_tail})

    remake_set(ros_manifest_script
      "include(ReMake)"
      "remake_file_cat(${ros_manifest} ${ros_manifest}.d/*)")
    remake_file_write(${ros_manifest}.cmake LINES ${ros_manifest_script})
    remake_target_name(ros_manifest_target ${ros_name}
      ${REMAKE_ROS_STACK_MANIFEST_TARGET_SUFFIX})
    remake_component(${ros_component}
      FILENAME ${ros_filename}
      PREFIX OFF
      INSTALL ${ros_dest_root}/${ros_dest_dir})
    remake_component_add_command(
      OUTPUT ${ros_manifest} AS ${ros_manifest_target}
      COMMAND ${CMAKE_COMMAND} -P ${ros_manifest}.cmake
      COMMENT "Generating ${ros_name} stack manifest"
      COMPONENT ${ros_component})
    remake_component_install(
      FILES ${ros_manifest}
      DESTINATION OFF
      COMPONENT ${ros_component})
    if(NOT TARGET ${REMAKE_ROS_ALL_MANIFESTS_TARGET})
      remake_target(${REMAKE_ROS_ALL_MANIFESTS_TARGET})
    endif(NOT TARGET ${REMAKE_ROS_ALL_MANIFESTS_TARGET})
    add_dependencies(${REMAKE_ROS_ALL_MANIFESTS_TARGET} ${ros_manifest_target})

    remake_ros_stack_set(${ros_name} COMPONENT ${ros_component}
      CACHE INTERNAL "Component of ${ros_name} ROS stack.")
    remake_ros_stack_add_dependencies(${ros_name} DEPENDS ${ros_depends})

    message(STATUS "ROS stack: ${ros_name}")

    remake_add_directories(${ros_sources} COMPONENT ${ros_component})
  else(${ROS_DISTRIBUTION} STRLESS groovy)
    remake_ros_package(
      ${ros_name} META
      COMPONENT ${ros_component}
      DESCRIPTION "${ros_description}"
      SOURCES ${ros_sources}
      RUN_DEPENDS ${ros_depends})
  endif(${ROS_DISTRIBUTION} STRLESS groovy)
endmacro(remake_ros_stack)

### \brief Define a ROS package, meta-package, or stack.
#   Depending on the indicated ROS distribution and the provided arguments,
#   this macro defines a ROS package, meta-package, or stack.
#   Regarding future portability, its use is strongly encouraged over
#   remake_ros_stack(). For ROS "fuerte" and earlier distributions,
#   remake_ros_package() is silently diverted to remake_ros_stack() if the
#   META option is present. Otherwise, the macro initializes the required
#   package variables and defines a rule for generating the package manifest.
#   \required[value] name The name of the ROS package to be defined. Note
#     that, in order for the package name to be valid, it may not contain
#     certain characters. See the ROS documentation for details.
#   \optional[value] COMPONENT:component The optional name of the install
#     component that will be assigned the package build and install rules.
#     If no component name is provided, it will default to component name
#     conversion of the provided package name. See ReMakeComponent for details.
#   \optional[value] DESCRIPTION:string An optional description of the ROS
#     package which is appended to the project summary when inscribed into the
#     package manifest.
#   \optional[list] SOURCES:dir The name of a directory containing the
#     sources of the ROS package and defaulting to the package name. The
#     directory will be recursed by remake_add_directories() with the
#     respective component set.
#   \optional[list] DEPENDS:pkg A list naming both build and runtime
#     dependencies of the defined ROS package, defaulting to roscpp and
#     rospy. This list will be passed to remake_ros_package_add_dependencies().
#   \optional[list] BUILD_DEPENDS:pkg A list naming build-only
#     dependencies of the defined ROS package. This list will be passed to
#     remake_ros_package_add_dependencies().
#   \optional[list] RUN_DEPENDS:pkg A list naming runtime-only
#     dependencies of the defined ROS package. This list will be passed to
#     remake_ros_package_add_dependencies().
#   \optional[var] REVERSE_DEPENDS:meta_pkg The defined ROS meta-package or
#     stack the ROS package reversly depends on. By default, the name of the
#     meta-package or stack is inferred by converting ${REMAKE_COMPONENT}
#     into a ROS-compliant package or stack name.
#   \optional[option] META If provided, this option entails definition
#     of a ROS meta-package or stack. Such meta-packages or stacks should
#     not contain any build targets, but may depend on other ROS packages
#     through the REVERSE_DEPENDS argument. However, ReMake does not actually
#     enforce this particular constraint.
macro(remake_ros_package ros_name)
  remake_arguments(PREFIX ros_ VAR COMPONENT VAR DESCRIPTION VAR SOURCES
    LIST DEPENDS LIST BUILD_DEPENDS LIST RUN_DEPENDS VAR REVERSE_DEPENDS
    OPTION META ${ARGN})
  string(REGEX REPLACE "_" "-" ros_default_component ${ros_name})
  remake_set(ros_component SELF DEFAULT ${ros_default_component})
  remake_set(ros_sources SELF DEFAULT ${ros_name})
  string(REGEX REPLACE "-" "_" ros_default_reverse_depends ${REMAKE_COMPONENT})
  remake_set(ros_reverse_depends SELF DEFAULT ${ros_default_reverse_depends})

  remake_ros()

  if(${ROS_DISTRIBUTION} STRLESS groovy AND NOT ros_meta)
    remake_set(ros_depends SELF DEFAULT roscpp rospy)

    if(ros_reverse_depends)
      if(${ROS_DISTRIBUTION} STRLESS groovy)
        remake_ros_stack_get(${ros_reverse_depends} COMPONENT
          OUTPUT ros_dest_component)
      else(${ROS_DISTRIBUTION} STRLESS groovy)
        remake_ros_package_get(${ros_reverse_depends} META
          OUTPUT ros_dest_meta)
        if(NOT ros_dest_meta)
          message(FATAL_ERROR
            "ROS package ${ros_name} reversely depends on package!")
        endif(NOT ros_dest_meta)
        remake_ros_package_get(${ros_reverse_depends} COMPONENT
          OUTPUT ros_dest_component)
      endif(${ROS_DISTRIBUTION} STRLESS groovy)
      remake_component_get(${ros_dest_component} INSTALL_PREFIX
        OUTPUT ros_dest_root)
    else(ros_reverse_depends)
      remake_file_name(ros_dest_dir ${ros_name})
      remake_set(ros_dest_root ${ROS_PATH}/share)
    endif(ros_reverse_depends)
    remake_file_name(ros_filename
      ${REMAKE_ROS_FILENAME_PREFIX}-${ROS_DISTRIBUTION}-${ros_name})
    string(REGEX REPLACE "_" "-" ros_filename ${ros_filename})
    remake_file_name(ros_dest_dir ${ros_name})

    remake_project_get(ROS_PACKAGES OUTPUT ros_packages)
    list(FIND ros_packages ${ros_name} ros_index)
    if(NOT ros_index LESS 0)
      message(FATAL_ERROR "ROS package ${ros_name} multiply defined!")
    endif(NOT ros_index LESS 0)
    remake_project_set(ROS_PACKAGES ${ros_packages} ${ros_name}
      CACHE INTERNAL "ROS packages defined by the project.")

    remake_file(ros_pkg_dir ${REMAKE_ROS_PACKAGE_DIR}/${ros_name} TOPLEVEL)
    remake_file_mkdir(${ros_pkg_dir})

    string(REGEX REPLACE "[.]$" "" ros_summary ${REMAKE_PROJECT_SUMMARY})
    if(ros_description)
      remake_set(ros_summary "${ros_summary} (${ros_description})")
    endif(ros_description)

    remake_set(ros_manifest_head "<package>")
    if(NOT ${ROS_DISTRIBUTION} STRLESS groovy)
      remake_list_push(ros_manifest_head
        "  <name>${ros_name}</name>"
        "  <version>${REMAKE_PROJECT_VERSION}</version>")
    endif(NOT ${ROS_DISTRIBUTION} STRLESS groovy)
    remake_list_push(ros_manifest_head
      "  <description brief=\"${ros_summary}\"/>")
    string(REPLACE ", " ";" ros_authors "${REMAKE_PROJECT_AUTHORS}")
    foreach(ros_author ${ros_authors})
      remake_list_push(ros_manifest_head "  <author>${ros_author}</author>")
    endforeach(ros_author ${ros_authors})
    remake_set(ros_contact ${REMAKE_PROJECT_CONTACT})
    list(GET ros_authors 0 ros_maintainer)
    remake_list_push(ros_manifest_head
      "  <maintainer email=\"${ros_contact}\">${ros_maintainer}</maintainer>"
      "  <license>${REMAKE_PROJECT_LICENSE}</license>"
      "  <url>${REMAKE_PROJECT_HOME}</url>")
    remake_unset(ros_manifest_tail)
    if(ros_meta)
      remake_list_push(ros_manifest_tail
        "  <export>"
        "    <metapackage/>"
        "  </export>")
    endif(ros_meta)
    remake_list_push(ros_manifest_tail "</package>")

    if(${ROS_DISTRIBUTION} STRLESS groovy)
      remake_set(ros_manifest ${ros_pkg_dir}/manifest.xml)
    else(${ROS_DISTRIBUTION} STRLESS groovy)
      remake_set(ros_manifest ${ros_pkg_dir}/package.xml)
    endif(${ROS_DISTRIBUTION} STRLESS groovy)
    remake_ros_package_set(${ros_name} MANIFEST ${ros_manifest}
      CACHE INTERNAL "Manifest file of ROS package ${ros_name}.")
    remake_file_mkdir(${ros_manifest}.d)
    remake_file_write(${ros_manifest}.d/00-head
      LINES ${ros_manifest_head})
    remake_file_write(${ros_manifest}.d/99-tail
      LINES ${ros_manifest_tail})

    remake_set(ros_manifest_script
      "include(ReMake)"
      "remake_file_cat(${ros_manifest} ${ros_manifest}.d/*)")
    remake_file_write(${ros_manifest}.cmake LINES ${ros_manifest_script})
    remake_target_name(ros_manifest_target ${ros_name}
      ${REMAKE_ROS_PACKAGE_MANIFEST_TARGET_SUFFIX})
    remake_component(${ros_component}
      FILENAME ${ros_filename}
      PREFIX OFF
      INSTALL ${ros_dest_root}/${ros_dest_dir})
    remake_component(${ros_component}-dev
      FILENAME ${ros_filename}-dev
      PREFIX OFF
      INSTALL ${ROS_PATH}
      HEADER_DESTINATION include/${ros_name})
    remake_component_add_command(
      OUTPUT ${ros_manifest} AS ${ros_manifest_target}
      COMMAND ${CMAKE_COMMAND} -P ${ros_manifest}.cmake
      COMMENT "Generating ${ros_name} package manifest"
      COMPONENT ${ros_component})
    remake_component_install(
      FILES ${ros_manifest}
      DESTINATION OFF
      COMPONENT ${ros_component})
    if(NOT TARGET ${REMAKE_ROS_ALL_MANIFESTS_TARGET})
      remake_target(${REMAKE_ROS_ALL_MANIFESTS_TARGET})
    endif(NOT TARGET ${REMAKE_ROS_ALL_MANIFESTS_TARGET})
    add_dependencies(${REMAKE_ROS_ALL_MANIFESTS_TARGET} ${ros_manifest_target})

    remake_ros_package_set(${ros_name} COMPONENT ${ros_component}
      CACHE INTERNAL "Component of ROS package ${ros_name}.")
    remake_ros_package_set(${ros_name} META ${ros_meta}
      CACHE INTERNAL "ROS package ${ros_name} is a meta-package.")
    remake_set(ros_build_depends ${ros_depends} ${ros_build_depends})
    remake_set(ros_run_depends ${ros_depends} ${ros_run_depends})
    remake_ros_package_add_dependencies(
      ${ros_name}
      BUILD_DEPENDS ${ros_build_depends}
      RUN_DEPENDS ${ros_run_depends})
    if(ros_reverse_depends)
      if(NOT ${ROS_DISTRIBUTION} STRLESS groovy)
        remake_ros_package_add_dependencies(${ros_reverse_depends}
          RUN_DEPENDS ${ros_name})
      endif(NOT ${ROS_DISTRIBUTION} STRLESS groovy)
    endif(ros_reverse_depends)

    if(ros_meta)
      message(STATUS "ROS meta-package: ${ros_name}")
    else(ros_meta)
      if(ros_reverse_depends)
        message(STATUS "ROS package: ${ros_name} (${ros_reverse_depends})")
      else(ros_reverse_depends)
        message(STATUS "ROS package: ${ros_name}")
      endif(ros_reverse_depends)
    endif(ros_meta)

    remake_add_directories(${ros_sources} COMPONENT ${ros_component})
  else(${ROS_DISTRIBUTION} STRLESS groovy AND NOT ros_meta)
    remake_ros_stack(
      ${ros_name}
      COMPONENT ${ros_component}
      DESCRIPTION ${ros_description}
      SOURCES ${ros_sources}
      ${DEPENDS})
  endif(${ROS_DISTRIBUTION} STRLESS groovy AND NOT ros_meta)
endmacro(remake_ros_package)

### \brief Add dependencies to a ROS stack or meta-package.
#   Depending on the indicated ROS distribution, this macro adds dependencies
#   to an already defined ROS stack or meta-package. Regarding future
#   portability, its use should however be avoided in favor of
#   remake_ros_package_add_dependencies(). For ROS "groovy" and later
#   distributions, remake_ros_stack_add_dependencies() is silently diverted
#   to remake_ros_package_add_dependencies(). Otherwise, only stack-level
#   dependencies should be contained in the argument list. Essentially,
#   the macro calls remake_ros_find_stack() to discover the required stack.
#   All directories in ROS_${NAME}_INCLUDE_DIRS are then added to the include
#   path by calling remake_include(). In addition, the directories in which
#   the linker will look for the stack libraries is specified by passing
#   ROS_${NAME}_LIBRARY_DIRS to CMake's link_directories().
#   \required[value] name The name of an already defined ROS stack to which
#     the stack-level dependencies should be added.
#   \required[list] DEPENDS:stack A list of stack-level dependencies that
#     are inscribed into the ROS stack manifest.
macro(remake_ros_stack_add_dependencies ros_name)
  remake_arguments(PREFIX ros_ LIST DEPENDS ${ARGN})

  remake_ros()

  if(${ROS_DISTRIBUTION} STRLESS groovy)
    if(ros_depends)
      remake_project_get(ROS_STACKS OUTPUT ros_stacks)
      remake_ros_stack_get(${ros_name} MANIFEST OUTPUT ros_manifest)
      remake_ros_stack_get(${ros_name} BUILD_DEPENDS OUTPUT ros_build_deps)

      remake_unset(ros_manifest_depends)
      foreach(ros_dependency ${ros_depends})
        list(FIND ros_stacks ${ros_dependency} ros_index)

        if(ros_index LESS 0)
          remake_ros_find_stack(${ros_dependency})
          remake_var_name(ros_include_dirs_var ROS ${ros_dependency}
            INCLUDE_DIRS)
          remake_var_name(ros_library_dirs_var ROS ${ros_dependency}
            LIBRARY_DIRS)

          if(${ros_include_dirs_var})
            remake_include(${ros_include_dirs_var})
          endif(${ros_include_dirs_var})
          if(${ros_library_dirs_var})
            link_directories(${ros_library_dirs_var})
          endif(${ros_library_dirs_var})
        else(ros_index LESS 0)
          remake_ros_stack_get(${ros_dependency} INCLUDE_DIRS
            OUTPUT ros_include_dirs)
          remake_include(${ros_include_dirs})
        endif(ros_index LESS 0)

        remake_list_push(ros_manifest_depends
          "  <depend stack=\"${ros_dependency}\"/>")
        remake_list_push(ros_build_deps ${ros_dependency})
      endforeach(ros_dependency)

      remake_file_write(${ros_manifest}.d/50-depends LINES
        ${ros_manifest_depends})
      if(ros_build_deps)
        list(REMOVE_DUPLICATES ros_build_deps)
      endif(ros_build_deps)
      remake_ros_stack_set(${ros_name} BUILD_DEPENDS ${ros_build_deps}
        CACHE INTERAL "Build dependencies of ROS stack ${ros_name}.")
    endif(ros_depends)
  else(${ROS_DISTRIBUTION} STRLESS groovy)
    remake_ros_package_add_dependencies(${ros_name} DEPENDS ${ros_depends})
  endif(${ROS_DISTRIBUTION} STRLESS groovy)
endmacro(remake_ros_stack_add_dependencies)

### \brief Add dependencies to a ROS package, meta-package, or stack.
#   Depending on the indicated ROS distribution, this macro adds dependencies
#   to an already defined ROS package, meta-package, or stack. Regarding
#   future portability, its use is strongly encouraged over
#   remake_ros_stack_add_dependencies(). For ROS "fuerte" and earlier
#   distributions, remake_ros_package_add_dependencies() is silently diverted
#   to remake_ros_stack_add_dependencies() if no package with the given name
#   is defined. Essentially, the macro calls remake_ros_find_package() to
#   discover the packages required during build. All directories in
#   ROS_${NAME}_INCLUDE_DIRS are then added to the include path by calling
#   remake_include(). In addition, the directories in which the linker will
#   look for the package libraries is specified by passing
#   ROS_${NAME}_LIBRARY_DIRS to CMake's link_directories().
#   \required[value] name The name of an already defined ROS package or
#     meta-package to which the package dependencies should be added.
#   \optional[list] DEPENDS:pkg A list of both package build and runtime 
#     dependencies that are inscribed into the ROS package manifest.
#   \optional[list] BUILD_DEPENDS:pkg A list of package build dependencies
#     that are inscribed into the ROS package manifest. Note that a ROS
#     meta-package may only define runtime dependencies on other packages.
#   \optional[list] RUN_DEPENDS:pkg A list of package runtime dependencies
#     that are inscribed into the ROS package manifest.
macro(remake_ros_package_add_dependencies ros_name)
  remake_arguments(PREFIX ros_ LIST DEPENDS LIST BUILD_DEPENDS
    LIST RUN_DEPENDS ${ARGN})

  remake_ros()

  remake_project_get(ROS_PACKAGES OUTPUT ros_packages)
  remake_set(ros_index 0)
  if(${ROS_DISTRIBUTION} STRLESS groovy)
    remake_list_push(ros_build_depends ${ros_depends} ${ros_run_depends})
    remake_unset(ros_run_depends)
    list(REMOVE_DUPLICATES ros_build_depends)
    list(FIND ros_packages ${ros_name} ros_index)
  else(${ROS_DISTRIBUTION} STRLESS groovy)
    remake_list_push(ros_build_depends ${ros_depends})
    list(REMOVE_DUPLICATES ros_build_depends)
    remake_list_push(ros_run_depends ${ros_depends})
    list(REMOVE_DUPLICATES ros_run_depends)
  endif(${ROS_DISTRIBUTION} STRLESS groovy)

  if(NOT ros_index LESS 0)
    remake_ros_package_get(${ros_name} MANIFEST OUTPUT ros_manifest)

    if(ros_build_depends)
      remake_ros_package_get(${ros_name} META OUTPUT ros_meta)
      if(ros_meta)
        message(FATAL_ERROR
          "ROS meta-package ${ros_name} defines build dependencies!")
      endif(ros_meta)

      remake_ros_package_get(${ros_name} BUILD_DEPENDS OUTPUT ros_build_deps)
      remake_ros_package_get(${ros_name} LINK_LIBRARIES OUTPUT ros_link_libs)

      remake_unset(ros_manifest_depends)
      foreach(ros_dependency ${ros_build_depends})
        list(FIND ros_packages ${ros_dependency} ros_index)

        if(ros_index LESS 0)
          remake_ros_find_package(${ros_dependency})
          remake_var_name(ros_include_dirs_var ROS ${ros_dependency}
            INCLUDE_DIRS)
          remake_var_name(ros_link_libraries_var ROS ${ros_dependency}
            LIBRARIES)
          remake_var_name(ros_library_dirs_var ROS ${ros_dependency}
            LIBRARY_DIRS)

          if(${ros_include_dirs_var})
            remake_include(${${ros_include_dirs_var}})
          endif(${ros_include_dirs_var})
          remake_list_push(ros_link_libs ${${ros_link_libraries_var}})
          if(${ros_library_dirs_var})
            link_directories(${ros_library_dirs_var})
          endif(${ros_library_dirs_var})
        else(ros_index LESS 0)
          remake_ros_package_get(${ros_dependency} INCLUDE_DIRS
            OUTPUT ros_include_dirs)
          include_directories(${ros_include_dirs})
        endif(ros_index LESS 0)

        if(${ROS_DISTRIBUTION} STRLESS groovy)
          remake_list_push(ros_manifest_depends
            "  <depend package=\"${ros_dependency}\"/>")
        else(${ROS_DISTRIBUTION} STRLESS groovy)
          remake_list_push(ros_manifest_build_depends
            "  <build_depend>${ros_dependency}</build_depend>")
        endif(${ROS_DISTRIBUTION} STRLESS groovy)
        remake_list_push(ros_build_deps ${ros_dependency})
      endforeach(ros_dependency)

      remake_file_write(${ros_manifest}.d/50-build_depends LINES
        ${ros_manifest_build_depends})
      if(ros_build_deps)
        list(REMOVE_DUPLICATES ros_build_deps)
      endif(ros_build_deps)
      remake_ros_package_set(${ros_name} BUILD_DEPENDS ${ros_build_deps}
        CACHE INTERAL "Build dependencies of ROS package ${ros_name}.")
      if(ros_link_libraries)
        list(REMOVE_DUPLICATES ros_link_libraries)
      endif(ros_link_libraries)
      remake_ros_package_set(${ros_name} LINK_LIBRARIES ${ros_link_libs}
      CACHE INTERNAL "Link libraries of ROS package ${ros_name}.")
    endif(ros_build_depends)

    if(ros_run_depends)
      remake_unset(ros_manifest_run_depends)
      foreach(ros_dependency ${ros_run_depends})
        remake_list_push(ros_manifest_run_depends
          "  <run_depend>${ros_dependency}</run_depend>")
      endforeach(ros_dependency)
      remake_file_write(${ros_manifest}.d/51-run_depends LINES
        ${ros_manifest_run_depends})
    endif(ros_run_depends)
  else(NOT ros_index LESS 0)
    remake_ros_stack_add_dependencies(${ros_name} DEPENDS ${ros_build_depends})
  endif(NOT ros_index LESS 0)
endmacro(remake_ros_package_add_dependencies)

### \brief Add ROS services to a ROS package.
#   This macro adds ROS services to an already defined ROS package. It
#   defines a target and the corresponding commands for generating C++
#   headers and Python modules from a list of ROS service definitions.
#   \optional[value] PACKAGE:package The name of the already defined
#     ROS package for which the service definitions shall be processed,
#     defaulting to the package name conversion of ${REMAKE_COMPONENT}.
#   \optional[list] glob A list of glob expressions that are resolved
#     in order to find the service definitions, defaulting to *.srv and
#     srv/*.srv.
macro(remake_ros_package_add_services)  
  remake_arguments(PREFIX ros_ VAR PACKAGE ARGN globs ${ARGN})
  string(REGEX REPLACE "-" "_" ros_default_package ${REMAKE_COMPONENT})
  remake_set(ros_package SELF DEFAULT ${ros_default_package})
  remake_set(ros_globs SELF DEFAULT *.srv srv/*.srv)

  remake_ros()

  remake_ros_package_get(${ros_package} COMPONENT OUTPUT ros_component)
  remake_file(ros_pkg_dir ${REMAKE_ROS_PACKAGE_DIR}/${ros_package} TOPLEVEL)
  remake_file_mkdir(${ros_pkg_dir}/srv)
  remake_file_configure(${ros_globs}
    DESTINATION ${ros_pkg_dir}/srv STRIP_PATHS
    OUTPUT ros_services)

  remake_find_executable(rosrun PATHS "${ROS_PATH}/bin")

  if(ROSRUN_FOUND AND ros_services)
    remake_target_name(ros_manifest_target
      ${ros_package} ${REMAKE_ROS_PACKAGE_MANIFEST_TARGET_SUFFIX})
    remake_target_name(ros_services_target
      ${ros_package} ${REMAKE_ROS_PACKAGE_SERVICES_TARGET_SUFFIX})
    remake_set(ros_include_dir
      ${ros_pkg_dir}/srv_gen/cpp/include)
    remake_set(ros_module_dir ${ros_pkg_dir}/src/${ros_package}/srv)

    remake_unset(ros_service_headers)
    remake_unset(ros_service_modules)
    foreach(ros_service ${ros_services})
      get_filename_component(ros_service_name ${ros_service} NAME)
      get_filename_component(ros_service_name_we ${ros_service} NAME_WE)

      remake_set(ros_service_header
        ${ros_include_dir}/${ros_package}/${ros_service_name_we}.h)
      remake_set(ros_shell_command
        ". ${ROS_PATH}/setup.sh"
        "${ROSRUN_EXECUTABLE} roscpp gensrv_cpp.py srv/${ros_service_name}")
      string(REGEX REPLACE ";" " && " ros_shell_command "${ros_shell_command}")
      add_custom_command(
        OUTPUT ${ros_service_header}
        COMMAND sh -c "${ros_shell_command}" VERBATIM
        WORKING_DIRECTORY ${ros_pkg_dir}
        DEPENDS ${ros_service}
        COMMENT "Generating ${ros_service_name_we} service (C++)")
      remake_list_push(ros_service_headers ${ros_service_header})

      remake_set(ros_service_module
        ${ros_module_dir}/_${ros_service_name_we}.py)
      remake_set(ros_shell_command
        "source ${ROS_PATH}/setup.sh"
        "ROS_PACKAGE_PATH=$ROS_PACKAGE_PATH:${ros_pkg_dir}/.."
        "${ROSRUN_EXECUTABLE} rospy gensrv_py.py srv/${ros_service_name}")
      string(REGEX REPLACE ";" " && " ros_shell_command "${ros_shell_command}")
      add_custom_command(
        OUTPUT ${ros_service_module}
        COMMAND sh -c "${ros_shell_command}" VERBATIM
        WORKING_DIRECTORY ${ros_pkg_dir}
        DEPENDS ${ros_service}
        COMMENT "Generating ${ros_service_name_we} service (Python)")
      remake_list_push(ros_service_modules ${ros_service_module})
    endforeach(ros_service)

    remake_target(${ros_services_target} DEPENDS ${ros_service_headers}
      ${ros_service_modules})
    remake_component_add_dependencies(COMPONENT ${ros_component}
      DEPENDS ${ros_services_target})
    remake_component_add_dependencies(COMPONENT ${ros_component}-dev
      DEPENDS ${ros_services_target})
    add_dependencies(${ros_services_target} ${ros_manifest_target})

    remake_add_headers(${ros_service_headers}
      COMPONENT ${ros_component}-dev GENERATED)
    include_directories(${ros_include_dir})

    remake_ros_package_get(${ros_package} INCLUDE_DIRS OUTPUT ros_include_dirs)
    remake_list_push(ros_include_dirs ${ros_include_dir})
    list(REMOVE_DUPLICATES ros_include_dirs)
    remake_ros_package_set(${ros_package} INCLUDE_DIRS ${ros_include_dirs}
      CACHE INTERNAL "Include directories of ROS package ${ros_package}.")
  endif(ROSRUN_FOUND AND ros_services)

  remake_component_install(
    FILES ${ros_services}
    DESTINATION srv
    COMPONENT ${ros_component})
endmacro(remake_ros_package_add_services ros_package)

### \brief Add an executable to a ROS package.
#   This macro adds an executable target to an already defined ROS package.
#   Its primary advantage over remake_add_executable() is the convenient
#   ability to specify dependencies on ROS messages or services generated
#   by the enlisted ROS packages. Moreover, the macro will specify all ROS
#   libraries which need to be linked into the executable target from the
#   dependencies defined for its ROS package.
#   \required[value] name The name of the executable target to be defined.
#   \optional[value] PACKAGE:package The name of the already defined ROS
#     package which will be assigned the executable, defaulting to the
#     package name conversion of ${REMAKE_COMPONENT}.
#   \optional[list] SOURCES:glob A list of glob expressions resolving to
#     the source files associated with the executable target, defaulting
#     to ${TARGET_NAME}.cpp.
#   \optional[list] DEPENDS:pkg A list of already defined ROS packages
#     which contain the messages or services definitions used by the
#     executable, defaulting to the ROS package specified to be assigned
#     the executable.
#   \optional[list] arg The list of additional arguments to be passed on to
#     remake_add_executable(). Note that this list should not contain
#     a COMPONENT specifier as the component name will be inferred from the
#     ROS package name. Similarly, it is not necessary to provide a glob
#     expression for the source files. See ReMake for details.
macro(remake_ros_add_executable ros_name)
  remake_arguments(PREFIX ros_ VAR PACKAGE LIST SOURCES ARGN args ${ARGN})
  string(REGEX REPLACE "-" "_" ros_default_package ${REMAKE_COMPONENT})
  remake_set(ros_package SELF DEFAULT ${ros_default_package})
  remake_set(ros_sources SELF DEFAULT ${ros_name}.cpp)

  remake_project_get(ROS_PACKAGES OUTPUT ros_packages)
  remake_ros_package_get(${ros_package} COMPONENT OUTPUT ros_component)
  remake_ros_package_get(${ros_package} BUILD_DEPENDS OUTPUT ros_build_deps)
  remake_ros_package_get(${ros_package} LINK_LIBRARIES OUTPUT ros_link_libs)

  remake_unset(ros_generated ros_depends)
  foreach(ros_dependency ${ros_package} ${ros_build_deps})
    list(FIND ros_packages ${ros_dependency} ros_index)

    if(NOT ros_index LESS 0)
      remake_target_name(ros_messages_target
        ${ros_dependency} ${REMAKE_ROS_PACKAGE_MESSAGES_TARGET_SUFFIX})
      remake_target_name(ros_services_target
        ${ros_dependency} ${REMAKE_ROS_PACKAGE_SERVICES_TARGET_SUFFIX})

      if(TARGET ${ros_messages_target})
        remake_list_push(ros_depends ${ros_messages_target})
      endif(TARGET ${ros_messages_target})
      if(TARGET ${ros_services_target})
        remake_list_push(ros_depends ${ros_services_target})
      endif(TARGET ${ros_services_target})
    endif(NOT ros_index LESS 0)
  endforeach(ros_dependency)

  if(ros_depends)
    remake_add_executable(
      ${ros_name} ${ros_sources} ${ros_args}
      DEPENDS ${ros_depends}
      LINK ${ros_link_libs}
      COMPONENT ${ros_component})
  else(ros_depends)
    remake_add_executable(
      ${ros_name} ${ros_sources} ${ros_args}
      LINK ${ros_link_libs}
      COMPONENT ${ros_component})
  endif(ros_depends)
endmacro(remake_ros_add_executable)

### \brief Add a library to a ROS package.
#   This macro adds a library target to an already defined ROS package.
#   Its primary advantage over remake_add_library() is the convenient
#   ability to specify dependencies on ROS messages or services generated
#   by the enlisted ROS packages. Moreover, the macro will specify all ROS
#   libraries which need to be linked into the library target from the
#   dependencies defined for its ROS package.
#   \required[value] name The name of the library target to be defined.
#   \optional[value] PACKAGE:package The name of the already defined ROS
#     package which will be assigned the library, defaulting to the
#     package name conversion of ${REMAKE_COMPONENT}.
#   \optional[list] SOURCES:glob A list of glob expressions resolving to
#     the source files associated with the library target, defaulting
#     to *.cpp.
#   \optional[list] DEPENDS:pkg A list of already defined ROS packages
#     which contain the messages or services definitions used by the
#     executable, defaulting to the ROS package specified to be assigned
#     the executable.
#   \optional[list] arg The list of additional arguments to be passed on to
#     remake_add_library(). Note that this list should not contain
#     a COMPONENT specifier as the component name will be inferred from the
#     ROS package name. Similarly, it is not necessary to provide a glob
#     expression for the source files. See ReMake for details.
macro(remake_ros_add_library ros_name)
  remake_arguments(PREFIX ros_ VAR PACKAGE LIST SOURCES LIST DEPENDS
    ARGN args ${ARGN})
  remake_arguments(PREFIX ros_ VAR PACKAGE LIST SOURCES ARGN args ${ARGN})
  string(REGEX REPLACE "-" "_" ros_default_package ${REMAKE_COMPONENT})
  remake_set(ros_package SELF DEFAULT ${ros_default_package})
  remake_set(ros_sources SELF DEFAULT ${ros_name}.cpp)

  remake_project_get(ROS_PACKAGES OUTPUT ros_packages)
  remake_ros_package_get(${ros_package} COMPONENT OUTPUT ros_component)
  remake_ros_package_get(${ros_package} BUILD_DEPENDS OUTPUT ros_build_deps)
  remake_ros_package_get(${ros_package} LINK_LIBRARIES OUTPUT ros_link_libs)

  remake_unset(ros_generated ros_depends)
  foreach(ros_dependency ${ros_package} ${ros_build_deps})
    list(FIND ros_packages ${ros_dependency} ros_index)

    if(NOT ros_index LESS 0)
      remake_target_name(ros_messages_target
        ${ros_dependency} ${REMAKE_ROS_PACKAGE_MESSAGES_TARGET_SUFFIX})
      remake_target_name(ros_services_target
        ${ros_dependency} ${REMAKE_ROS_PACKAGE_SERVICES_TARGET_SUFFIX})

      if(TARGET ${ros_messages_target})
        remake_list_push(ros_depends ${ros_messages_target})
      endif(TARGET ${ros_messages_target})
      if(TARGET ${ros_services_target})
        remake_list_push(ros_depends ${ros_services_target})
      endif(TARGET ${ros_services_target})
    endif(NOT ros_index LESS 0)
  endforeach(ros_dependency)

  if(ros_depends)
    remake_add_library(
      ${ros_name} ${ros_sources} ${ros_args}
      DEPENDS ${ros_depends}
      LINK ${ros_link_libs}
      COMPONENT ${ros_component})
  else(ros_depends)
    remake_add_library(
      ${ros_name} ${ros_sources} ${ros_args}
      LINK ${ros_link_libs}
      COMPONENT ${ros_component})
  endif(ros_depends)
endmacro(remake_ros_add_library)
