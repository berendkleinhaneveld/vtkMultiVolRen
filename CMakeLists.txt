#==============================================================================
# vtkMultiVolRen
#
# Description: vtkMultiVolRen demo
#
# Author: xXx <xXX>, (C) 2010
# Extended by: Berend Klein Haneveld <berendkleinhaneveld@gmail.com>, (C) 2013
#
# Copyright: See COPYING file that comes with this distribution
#==============================================================================

# Define the project
PROJECT(vtkGPUMultiVolumeRender)
SET(KIT vtkGPUMultiVolumeRenderDemo)

CMAKE_MINIMUM_REQUIRED(VERSION 2.6.4)

IF(POLICY CMP0017)
  CMAKE_POLICY(SET CMP0017 NEW)
ENDIF(POLICY CMP0017)

# On some platforms (OSX) this may not be defined, so search for it
IF(NOT DEFINED CMAKE_INSTALL_NAME_TOOL)
  FIND_PROGRAM(CMAKE_INSTALL_NAME_TOOL install_name_tool)
ENDIF(NOT DEFINED CMAKE_INSTALL_NAME_TOOL)

# Find VTK
# FIND_PACKAGE(VTK 6.0 REQUIRED)
FIND_PACKAGE(VTK REQUIRED)
IF(VTK_FOUND)
  INCLUDE(${VTK_USE_FILE})
ELSE(VTK_FOUND)
  MESSAGE(FATAL_ERROR
    "Cannot build the executable without VTK. Please set the VTK_DIR")
ENDIF(VTK_FOUND)

#-----------------------------------------------------------------------------
# Configure OpenGL support (copied from VTK main CMakeLists.txt).
# At the moment CMake's FindOpenGL considers OpenGL should be found
# in the framework version on OSX. This is a reasonable assumption for
# few people are going to use X. The module warns that if X is to be
# used, one has to set the libs and include dir manually, which is
# exactly what we are going to do below.
IF(APPLE AND VTK_USE_X)
  FIND_PATH(OPENGL_INCLUDE_DIR GL/gl.h
    /usr/X11R6/include)
  FIND_PATH(OPENGL_xmesa_INCLUDE_DIR GL/xmesa.h
    /usr/X11R6/include)
  FIND_LIBRARY(OPENGL_gl_LIBRARY NAMES GL MesaGL
    PATHS /usr/lib /usr/local/lib /usr/X11R6/lib)
  FIND_LIBRARY(OPENGL_glu_LIBRARY NAMES GLU MesaGLU
    PATHS ${OPENGL_gl_LIBRARY} /usr/lib /usr/local/lib /usr/X11R6/lib)
ENDIF(APPLE AND VTK_USE_X)
FIND_PACKAGE(OpenGL)

# Need to include class headers and the configuration header.
INCLUDE_DIRECTORIES(${PROJECT_SOURCE_DIR})
INCLUDE_DIRECTORIES(${PROJECT_BINARY_DIR})
INCLUDE_DIRECTORIES(${OPENGL_INCLUDE_DIR})

SET(HEADERS 
  vtkGPUMultiVolumeRayCastMapper.h
  vtkOpenGLGPUMultiVolumeRayCastMapper.h
  vtkOpenGLGPUVolumeRayCastMapper2.h
)

SET(SOURCES 
  vtkGPUMultiVolumeRayCastMapper.cxx
  vtkOpenGLGPUMultiVolumeRayCastMapper.cxx
  vtkOpenGLGPUVolumeRayCastMapper2.cxx
)

SET(ALL_SOURCES
  ${KIT}.cxx
  ${SOURCES}
)

SET(GLSL_SOURCES
  vtkGPUMultiVolumeRayCastMapper_CompositeFS
  vtkGPUMultiVolumeRayCastMapper_OneComponentFS
  vtkGPUMultiVolumeRayCastMapper_FourComponentsFS
  vtkGPUMultiVolumeRayCastMapper_NoShadeFS
  vtkGPUMultiVolumeRayCastMapper_ShadeFS
  vtkGPUVolumeRayCastMapper2_CompositeFS
  # vtkGPUVolumeRayCastMapper2_OneComponentFS
  # vtkGPUVolumeRayCastMapper2_FourComponentsFS
  # vtkGPUVolumeRayCastMapper2_NoShadeFS
  # vtkGPUVolumeRayCastMapper2_ShadeFS
)

# -----------------------------------------------------------------------------
# Create custom commands to encode each glsl file into a C string literal
# in a header file
# -----------------------------------------------------------------------------

# Needs vtkEncodeString, VTK_ENCODESTRING_EXE 
# should work ...
FOREACH(file ${GLSL_SOURCES})
  ## TODO
  SET(src ${PROJECT_SOURCE_DIR}/GLSL/${file}.glsl)
  SET(res ${CMAKE_CURRENT_BINARY_DIR}/${file}.cxx)
  SET(resh ${CMAKE_CURRENT_BINARY_DIR}/${file}.h)
  ADD_CUSTOM_COMMAND(
    OUTPUT ${res} ${resh}
    DEPENDS ${src} vtkEncodeString
    # COMMAND ${VTK_ENCODESTRING_EXE}
    COMMAND vtkEncodeString-6.1
    ARGS ${res} ${src} ${file} --build-header VTKRENDERINGVOLUMEOPENGL_EXPORT vtkRenderingVolumeOpenGLModule.h
  )
  SET(KIT_EXTRA_SRCS ${KIT_EXTRA_SRCS} ${res})
ENDFOREACH(file)

# Give user option of building shared or static libraries.  Default to
# the choice made for VTK.
OPTION(BUILD_SHARED_LIBS 
  "Build with shared libraries."
  ${VTK_BUILD_SHARED_LIBS}
)

# Set VTKLOCAL_BUILD_SHARED_LIBS to 1 or 0 for use in creating the
# configuration header.
IF(BUILD_SHARED_LIBS)
  SET(VTKLOCAL_BUILD_SHARED_LIBS_CONFIG 1)
ELSE(BUILD_SHARED_LIBS)
  SET(VTKLOCAL_BUILD_SHARED_LIBS_CONFIG 0)
ENDIF(BUILD_SHARED_LIBS)

# List the kits from VTK that are needed by this project.
SET(VTK_LOCAL_LIBS
  vtkIOCore
  vtkRenderingCore
  vtkRenderingVolume
  vtkRenderingFreeTypeOpenGL
  vtkRenderingVolumeOpenGL
  vtkInteractionWidgets
  vtkIOXML
)

# Hide warnings about using deprecated function calls
IF(APPLE)
  SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-deprecated")
ENDIF(APPLE)

# If this is a build tree, provide an option for putting this
# project's executables and libraries in with VTK's.
IF(EXISTS ${VTK_DIR}/bin)
  OPTION(USE_VTK_OUTPUT_PATHS
    "Use VTK's output directory for this project's executables and libraries."
    OFF)
  MARK_AS_ADVANCED(USE_VTK_OUTPUT_PATHS)
  IF(USE_VTK_OUTPUT_PATHS)
    SET(LIBRARY_OUTPUT_PATH ${VTK_DIR}/bin)
    SET(EXECUTABLE_OUTPUT_PATH ${VTK_DIR}/bin)
  ENDIF(USE_VTK_OUTPUT_PATHS)
ENDIF(EXISTS ${VTK_DIR}/bin)

# Create the library.
ADD_LIBRARY(${PROJECT_NAME} 
  ${HEADERS}
  ${SOURCES}
  ${GLSL_SOURCES}
)

TARGET_LINK_LIBRARIES(${PROJECT_NAME}
  ${VTK_LOCAL_LIBS}
  ${OPENGL_gl_LIBRARY}
)

# Give the user the option to build the demo as an app
IF(APPLE)
  OPTION(BUILD_DEMO_AS_APP
    "Build the demo as an app bundle."
    OFF
  )
  IF(BUILD_DEMO_AS_APP)
    SET(EXECUTABLE_FLAG MACOSX_BUNDLE)
  ENDIF(BUILD_DEMO_AS_APP)
ENDIF(APPLE)

# Provide the user with the option to build a demo app
# Default is ON
OPTION(BUILD_DEMO
  "Build a demo application."
  ON
)

IF(BUILD_DEMO)
  # Create the demo
  ADD_EXECUTABLE(${KIT}
    ${EXECUTABLE_FLAG} 
    ${ALL_SOURCES}
    ${KIT_EXTRA_SRCS}
  )

  TARGET_LINK_LIBRARIES(${KIT}
    ${VTK_LOCAL_LIBS}
    ${OPENGL_gl_LIBRARY}
  )
ENDIF(BUILD_DEMO)

# Give the user the option of wrapping the library in Python
OPTION(WRAP_PYTHON 
  "Wrap the library in Python."
  ${VTK_WRAP_PYTHON}
)

# Create Python wrappers if VTK is wrapped in Python.
IF(WRAP_PYTHON AND VTK_WRAP_PYTHON)
  SET(VTK_WRAP_PYTHON_FIND_LIBS ON)
  INCLUDE(${VTK_CMAKE_DIR}/vtkWrapPython.cmake)
  INCLUDE_DIRECTORIES("${PYTHON_INCLUDE_DIR}")
  VTK_WRAP_PYTHON3(${PROJECT_NAME}Python 
    VTK_LOCAL_PYTHON_SRCS
    "${SOURCES}"
  )
  ADD_LIBRARY(${PROJECT_NAME}PythonD 
    ${VTK_LOCAL_PYTHON_SRCS}
  )
  ADD_LIBRARY(${PROJECT_NAME}Python 
    MODULE
    ${PROJECT_NAME}PythonInit.cxx
  )
  TARGET_LINK_LIBRARIES(${PROJECT_NAME}PythonD
    ${VTK_LOCAL_LIBS}
  	${PROJECT_NAME}
  )
  FOREACH(c ${VTK_LOCAL_LIBS})
    TARGET_LINK_LIBRARIES(${PROJECT_NAME}PythonD ${c}PythonD)
  ENDFOREACH(c)
  TARGET_LINK_LIBRARIES(${PROJECT_NAME}Python 
  	${PROJECT_NAME}PythonD
  )
  
  # Python extension modules on Windows must have the extension ".pyd"
  # instead of ".dll" as of Python 2.5.  Older python versions do support
  # this suffix.
  IF(WIN32 AND NOT CYGWIN)
    SET_TARGET_PROPERTIES(${PROJECT_NAME}Python PROPERTIES SUFFIX ".pyd")
  ENDIF(WIN32 AND NOT CYGWIN)    
ENDIF(WRAP_PYTHON AND VTK_WRAP_PYTHON)
