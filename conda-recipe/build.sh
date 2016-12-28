#!/bin/bash -e

BUILD_CONFIG=Release

PYTHON_INCLUDE="${PREFIX}/include/python${PY_VER}"
if [ ! -d ${PYTHON_INCLUDE} ]; then
    PYTHON_INCLUDE="${PREFIX}/include/python${PY_VER}m"
fi

PYTHON_LIBRARY_EXT="so"
if [ `uname` = "Darwin" ] ; then
    PYTHON_LIBRARY_EXT="dylib"
fi

PYTHON_LIBRARY="${PREFIX}/lib/libpython${PY_VER}.${PYTHON_LIBRARY_EXT}"
if [ ! -f ${PYTHON_LIBRARY} ]; then
    PYTHON_LIBRARY="${PREFIX}/lib/libpython${PY_VER}m.${PYTHON_LIBRARY_EXT}"
fi

mkdir build
cd build

cmake ../. \
    -Wno-dev \
    -DCMAKE_BUILD_TYPE=${BUILD_CONFIG} \
    -DCMAKE_CXX_FLAGS="-Wreturn-type" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET='10.12' \
    -DCMAKE_OSX_SYSROOT='macosx10.12' \
    -DCMAKE_INSTALL_PREFIX=${PREFIX} \
    -DPYTHON_INCLUDE_DIR:PATH=${PYTHON_INCLUDE} \
    -DPYTHON_LIBRARY:FILEPATH=${PYTHON_LIBRARY} \

# ${MACOSX_DEPLOYMENT_TARGET:+-DCMAKE_OSX_DEPLOYMENT_TARGET='10.9'} \
# export VERBOSE=1
make -j${CPU_COUNT}

# cd ..

# cp ./build/lib_pyopcode.so "${PREFIX}/lib/python${PY_VER}/_pyopcode.so"

# cd ..
