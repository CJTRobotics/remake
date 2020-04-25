############################################################################
#    Copyright (C) 2020 by Oskar Roesler                                   #
#    oskar.roesler@cjtrobotics.de                                          #
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

include(ReMakePrivate)

### \brief ReMake Qt5 macros
#   The ReMake Qt5 macros provide seamless integration of Qt5 meta-object
#   and user interface file processing with ReMake build targets.

if(NOT DEFINED REMAKE_QT5_CMAKE)
  remake_set(REMAKE_QT5_CMAKE ON)
endif(NOT DEFINED REMAKE_QT5_CMAKE)

### \brief Configure Qt5 meta-object processing.
#   This macro discovers the Qt5 package configuration and enables Qt5
#   meta-object processing. Note that the macro automatically gets
#   invoked by the macros defined in this module. It needs not be called
#   directly from a CMakeLists.txt file.
#   \optional[list] REQUIRED:module An optional list of required Qt5
#     modules.
macro(remake_qt5)
  remake_arguments(PREFIX qt5_ LIST REQUIRED ${ARGN})

  if(NOT DEFINED QT5_FOUND)
    if(qt5_required)
      remake_find_package(Qt5 REQUIRED ${qt5_required} QUIET)
    else(qt5_required)
      remake_find_package(Qt5 QUIET)
    endif(qt5_required)
  else(NOT DEFINED QT5_FOUND)
    include(FindQt5)
  endif(NOT DEFINED QT5_FOUND)

  if(DEFINED QT5_FOUND AND NOT DEFINED QT5_MOC)
    remake_project_set(QT5_MOC ${QT5_FOUND} CACHE BOOL
      "Process Qt5 meta-objects.")
    remake_project_set(QT5_UIC ${QT5_FOUND} CACHE BOOL
      "Process Qt5 user interface files.")
  endif(DEFINED QT5_FOUND AND NOT DEFINED QT5_MOC)
endmacro(remake_qt5)

### \brief Add the Qt5 header directories to the include path.
#   This macro adds the Qt5 header directories to the compiler's include path.
macro(remake_qt5_include)
  remake_qt5()

  if(QT5_FOUND)
    remake_include(${QT_INCLUDES})
  endif(QT5_FOUND)
endmacro(remake_qt5_include)

### \brief Add Qt5 meta-object sources for a target.
#   This macro automatically defines meta-object sources for a target from
#   a list of glob expressions. The glob expressions should resolve to
#   header files containing a Q_OBJECT declaration.
#   \required[value] target The name of the target to add the meta-object
#     sources for.
#   \optional[list] glob An optional list of glob expressions that are
#     resolved in order to find the header files with Q_OBJECT declarations,
#     defaulting to *.h and *.hpp.
macro(remake_qt5_moc qt5_target)
  remake_arguments(PREFIX qt5_ ARGN globs ${ARGN})
  remake_set(qt5_globs SELF DEFAULT *.h DEFAULT *.hpp)

  remake_qt5()

  remake_project_get(QT5_MOC)
  if(QT5_MOC)
    remake_file_glob(qt5_headers ${qt5_globs})
    remake_unset(qt5_sources)
    qt5_wrap_cpp(qt5_sources ${qt5_headers} OPTIONS -nw)
    remake_target_add_sources(${qt5_target} ${qt5_sources})
  endif(QT5_MOC)
endmacro(remake_qt5_moc)

### \brief Generate headers from Qt5 user interface files.
#   This macro automatically generates header files from a list of glob
#   expressions that resolve to Qt user interface files. Furthermore,
#   the output location of the headers will be added to the compiler's
#   include path.
#   \required[value] target The name of the target to add the generated
#     headers for.
#   \optional[list] glob An optional list of glob expressions that are
#     resolved in order to find the Qt5 user interface files, defaulting
#     to *.ui.
macro(remake_qt5_ui qt5_target)
  remake_arguments(PREFIX qt5_ ARGN globs ${ARGN})
  remake_set(qt5_globs SELF DEFAULT *.ui)

  remake_qt5()

  remake_project_get(QT5_UIC)
  if(QT5_UIC)
    remake_file_glob(qt5_uis ${qt5_globs})
    remake_unset(qt5_headers)
    qt5_wrap_ui(qt5_headers ${qt5_uis})
    remake_target_add_sources(${qt5_target} ${qt5_headers})
    remake_include(${CMAKE_CURRENT_BINARY_DIR})
  endif(QT5_UIC)
endmacro(remake_qt5_ui)
