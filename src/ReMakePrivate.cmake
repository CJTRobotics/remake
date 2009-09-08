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

### \brief ReMake private macros
#   ReMake's private module provides basic helper macros that are used
#   throughout the ReMake module infrastructure. As the name suggest,
#   these macros are considered to be private to ReMake.
#
#   In most cases, there exists no need for directly calling any private
#   macros from a CMakeLists.txt file. However, the macros shall be documented
#   for the beauty and purpose of completeness.

### \brief Parse ReMake macro arguments.
#   This macro generally parses the arguments of ReMake macros, thus enabling
#   CMake-style macro calls. Three different kinds of arguments exist that
#   are identified by keyword, namely variable, options, and list arguments.
#   Variable arguments are of the form KEY ${value}, whereas list arguments
#   KEY ${value1} ${value2} ... take on multiple values. Options, on the
#   contrary, are not followed by any values. Their presence simply evaluates
#   to ON.
#   If an argument is specified, two output variables are created. For an
#   existing argument named ${NAME}, the first variable ${name} (a lower-case
#   conversion of the argument name) is defined to contain the parameters 
#   passed for this argument. The second variable ${NAME} is of the form 
#   ${NAME} ${VALUE} and may thus easily be passed on to another macro with
#   identical argument understanding.
#   \optional[value] PREFIX:prefix An optional prefix that is prepended to the
#     lower-case name of the output variable. The values passed for an argument
#     ${NAME} may consequently be accessed through ${prefix}${name}.
#   \optional[value] VAR:name Adds a definition for a variable argument
#     and may have multiple occurences.
#   \optional[value] LIST:name Adds a definition for a list argument
#     and may have multiple occurences.
#   \optional[value] OPTION:name Adds a definition for an option argument
#     and may have multiple occurences.
#   \optional[value] ARGN:name Adds a definition for a list argument that
#     takes on all remaining argument values.
#   \required[list] arg The list of arguments to be parsed, usually ${ARGN}.
macro(remake_arguments)
  set(private_prefix)
  set(private_vars)
  set(private_lists)
  set(private_opts)
  set(private_argn)  
  set(private_args)

  set(private_push)
  foreach(private_arg ${ARGN})
    if(private_push)
      list(APPEND ${private_push} ${private_arg})
      set(private_push)
    else(private_push)
      if(private_arg STREQUAL PREFIX)
        if(private_prefix)
          list(APPEND private_args ${private_arg})
        else(private_prefix)
          set(private_push private_prefix)
        endif(private_prefix)
      elseif(private_arg STREQUAL VAR)
        set(private_push private_vars)
      elseif(private_arg STREQUAL LIST)
        set(private_push private_lists)
      elseif(private_arg STREQUAL OPTION)
        set(private_push private_opts)
      elseif(private_arg STREQUAL ARGN)
        set(private_push private_argn)
      else(private_arg STREQUAL PREFIX)
        list(APPEND private_args ${private_arg})
      endif(private_arg STREQUAL PREFIX)
    endif(private_push)
  endforeach(private_arg)

  foreach(private_var ${private_vars})
    set(${private_var})
    string(TOLOWER ${private_var} private_lower_var)
    set(${private_prefix}${private_lower_var})
  endforeach(private_var)
  foreach(private_list ${private_lists})
    set(${private_list})
    string(TOLOWER ${private_list} private_lower_list)
    set(${private_prefix}${private_lower_list})
  endforeach(private_list)
  foreach(private_opt ${private_opts})
    set(${private_opt})
    string(TOLOWER ${private_opt} private_lower_opt)
    set(${private_prefix}${private_lower_opt} OFF)
  endforeach(private_opt)
  if(private_argn)
    set(${private_prefix}${private_argn})
  endif(private_argn)

  set(private_var)
  set(private_list)
  foreach(private_arg ${private_args})
    list(FIND private_vars ${private_arg} private_var_index)
    list(FIND private_lists ${private_arg} private_list_index)
    list(FIND private_opts ${private_arg} private_opt_index)

    if(private_var_index GREATER -1)
      list(GET private_vars ${private_var_index} private_var)
      set(private_list)
    elseif(private_list_index GREATER -1)
      list(GET private_lists ${private_list_index} private_list)
      set(private_var)
    elseif(private_opt_index GREATER -1)
      list(GET private_opts ${private_opt_index} private_opt)
      set(${private_opt} ${private_opt})
      string(TOLOWER ${private_opt} private_lower_opt)
      set(${private_prefix}${private_lower_opt} ON)
      set(private_var)
      set(private_list)
    elseif(private_var)
      if(NOT ${private_var})
        set(${private_var} ${private_var})
      endif(NOT ${private_var})
      list(APPEND ${private_var} ${private_arg})
      string(TOLOWER ${private_var} private_lower_var)
      list(APPEND ${private_prefix}${private_lower_var} ${private_arg})
      set(private_var)
    elseif(private_list)
      if(NOT ${private_list})
        set(${private_list} ${private_list})
      endif(NOT ${private_list})
      list(APPEND ${private_list} ${private_arg})
      string(TOLOWER ${private_list} private_lower_list)
      list(APPEND ${private_prefix}${private_lower_list} ${private_arg})
    else(private_var_index GREATER -1)
      list(APPEND ${private_prefix}${private_argn} ${private_arg})
    endif(private_var_index GREATER -1)
  endforeach(private_arg)
endmacro(remake_arguments)

### \brief Generate a ReMake variable name from a list of strings.
#   This macro is a helper macro to generate valid variable names from
#   arbitrary strings. It replaces whitespace characters, scores, and CMake
#   list separators by underscores and performs an upper-case conversion of 
#   the result.
#   \required[value] variable The name of a variable to be assigned the
#     generated variable name.
#   \required[list] string A list of strings to be concatenated to the
#     variable name.
macro(remake_var_name private_var)
  string(TOUPPER "${ARGN}" private_upper)
  string(REGEX REPLACE "[ ;-]" "_" ${private_var} "${private_upper}")
endmacro(remake_var_name)

### \brief Find defined variables matching a regular expression.
#   This macro is a helper macro to discover defined variables matching a 
#   regular expression. It queries the CMake property VARIABLES by calling
#   get_cmake_property() and performs regular expression matching on the
#   results.
#   \required[value] variable The name of a variable to be defined the
#     result list of matching variable names.
#   \required[value] regex The regular expression used for matching the
#     names of defined variables.
macro(remake_var_regex private_var private_regex)
  get_cmake_property(private_globals VARIABLES)

  foreach(private_global ${private_globals})
    string(REGEX MATCH ${private_regex} private_matched ${private_global})
    if(private_matched)
      remake_list_push(${private_var} ${private_global})
    endif(private_matched)
  endforeach(private_global)
endmacro(remake_var_regex)

### \brief Define the value of a ReMake variable.
#   This helper macro defines the value of a ReMake variable by calling
#   CMake's set() macro. Optionally, it allows for setting the variable value 
#   from another variable passed by reference. If the variable value is
#   undefined, the macro may assign a given default value.
#   \required[value] variable The name of the variable to be defined.
#   \optional[value] FROM:variable The optional name of a variable to be
#     used for setting the variable's value.
#   \optional[option] SELF If present, this option causes the macro to
#     ignore external variable assignments. A typical use for this
#     functionality is to assign default values to otherwise undefined or 
#     empty variables.
#   \optional[value] DEFAULT:value An optional default value to be assigned
#     to an otherwise undefined or empty variable.
#   \optional[list] value An optional list of values to be passed on to
#     CMake's set() macro. See the CMake documentation for correct usage.
macro(remake_set private_var)
  remake_arguments(PREFIX private_ VAR FROM VAR DEFAULT OPTION SELF 
    ARGN values ${ARGN})

  if(private_from)
    if(${private_from})
      set(${private_var} ${${private_from}} ${private_values})
    endif(${private_from})
  else(private_from)
    if(NOT private_self)
      set(${private_var} ${private_values})
    endif(NOT private_self)
  endif(private_from)

  if(NOT ${private_var})
    if(DEFINED private_default)
      set(${private_var} ${private_default} ${private_values})
    endif(DEFINED private_default)
  endif(NOT ${private_var})
endmacro(remake_set)

### \brief Generate debugging output from a list of variables.
#   This macro is a helper macro to conveniently generate debugging output
#   from a list of variables. The output generated is of the form
#   VARIABLE = ${VARIABLE} and comes in a CMake status message.
#   \required[list] var The list of variables for which to generate
#     debugging output.
macro(remake_debug)
  foreach(private_var ${ARGN})
    if(DEFINED ${private_var})
      message("++ ${private_var} = ${${private_var}}")
    else(DEFINED ${private_var})
      message("++ ${private_var} undefined")
    endif(DEFINED ${private_var})
  endforeach(private_var)
endmacro(remake_debug)
