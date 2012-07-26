#!/bin/bash
# @@@LICENSE
#
#      Copyright (c) 2012 Hewlett-Packard Development Company, L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# LICENSE@@@

############################
# To force a rebuild of components pass the parameter clean to the script.
############################

if [ "$1" = 'clean' ] ; then
  export SKIPSTUFF=0
  set -ex
else
  export SKIPSTUFF=1
  set -e
fi



export BASE=$HOME/luna-desktop-binaries
export LUNA_STAGING="${BASE}/staging"
mkdir -p ${BASE}/tarballs
mkdir -p ${LUNA_STAGING}

export BEDLAM_ROOT="${BASE}/staging"
export JAVA_HOME=/usr/lib/jvm/java-6-sun
export JDKROOT=${JAVA_HOME}
export SCRIPT_DIR=$PWD
export PKG_CONFIG_PATH=$LUNA_STAGING/lib/pkgconfig
export MAKEFILES_DIR=$BASE/pmmakefiles

PROCS=`grep -c processor /proc/cpuinfo`
[ $PROCS -gt 1 ] && JOBS="-j${PROCS}"

export WEBKIT_DIR="WebKit"

############################################
# Optimized fetch process.
# Parameters:
#   $1 Specific component within repository, ex: openwebos/cjson
#   $2 Tag of component, ex: 35
#   $3 Name of destination folder, ex: cjson
#   $4 (Optional) Prefix for tag
#
# If the ZIP file already exists in the tarballs folder, it will not be re-fetched
#
############################################
do_fetch() {
    cd $BASE
    if [ -n "$4" ] ; then
        GIT_BRANCH="${4}${2}"
    else
        GIT_BRANCH="${2}"
    fi
    if [ -n "$3" -a -d "$3" ] ; then
        rm -rf ./$3
    fi
    
    if [ "$1" = "isis-project/WebKit" ] ; then
        GIT_SOURCE=https://github.com/downloads/isis-project/WebKit/WebKit_${2}s.zip
    elif [ -n “${GITHUB_USER}” ]; then
        GIT_SOURCE=https://${GITHUB_USER}:${GITHUB_PASS}@github.com/${1}/zipball/${GIT_BRANCH}
    else
        GIT_SOURCE=https://github.com/${1}/zipball/${GIT_BRANCH}
        
    fi

    ZIPFILE="${BASE}/tarballs/`basename ${1}`_${2}.zip"

    if [ -e ${ZIPFILE} ] ; then
        if [[ "file -bi ${ZIPFILE}" == "text/html; charset=utf-8" ]] ; then 
            rm -f ${ZIPFILE}
        fi
    fi
    if [ ! -e ${ZIPFILE} ] ; then
        if [ -e ~/tarballs/`basename ${1}`_${2}.zip ] ; then
            cp ~/tarballs/`basename ${1}`_${2}.zip ${ZIPFILE}
            if [ $? != 0 ] ; then
                echo error
                rm -f ${ZIPFILE}
                exit 1
            fi
        else
            echo "About to fetch ${1}#${GIT_BRANCH} from github"
            curl -L -R -# ${GIT_SOURCE} -o "${ZIPFILE}"
        fi      
    fi
    if [ -e ${ZIPFILE} ] ; then
        if [[ "file -bi ${ZIPFILE}" == "text/html; charset=utf-8" ]] ; then 
            echo "FAILED DOWNLOAD OF ${1}"
            rm -f ${ZIPFILE}
            exit 1
        fi
    fi
    mkdir ./$3
    pushd $3
    unzip -q ${ZIPFILE}
    mv $(ls |head -n1)/* ./
    popd
}

########################
#  Fetch and build cjson
########################
function build_cjson
{
    do_fetch openwebos/cjson $1 cjson submissions/
    cd $BASE/cjson
    sh autogen.sh
    mkdir -p build
    cd build
    PKG_CONFIG_PATH=$LUNA_STAGING/lib/pkgconfig \
        ../configure --prefix=$LUNA_STAGING --enable-shared --disable-static
    make $JOBS all
    make install
}

##########################
#  Fetch and build pbnjson
##########################
function build_pbnjson
{
    ###do_fetch openwebos/pbnjson $1 pbnjson submissions/ 
    do_fetch isis-project/pbnjson $1 pbnjson 
    mkdir -p $BASE/pbnjson/build
    cd $BASE/pbnjson/build
    sed -i 's/set(EXTERNAL_YAJL TRUE)/set(EXTERNAL_YAJL FALSE)/' ../src/CMakeLists.txt
    sed -i 's/add_subdirectory(pjson_engine\//add_subdirectory(deps\//' ../src/CMakeLists.txt
    sed -i 's/-Werror//' ../src/CMakeLists.txt
    cmake ../src -DCMAKE_FIND_ROOT_PATH=${LUNA_STAGING} -DYAJL_INSTALL_DIR=${LUNA_STAGING} -DWITH_TESTS=False -DWITH_DOCS=False -DCMAKE_INSTALL_PREFIX=${LUNA_STAGING} -DCMAKE_BUILD_TYPE=Release
    make $JOBS install
}

###########################
#  Fetch and build pmloglib
###########################
function build_pmloglib
{
    do_fetch openwebos/pmloglib $1 pmloglib submissions/
    mkdir -p $BASE/pmloglib/build
    cd $BASE/pmloglib/build
    cmake .. -DNO_TESTS=True -DNO_UTILS=True -DCMAKE_INSTALL_PREFIX=${LUNA_STAGING} -DCMAKE_BUILD_TYPE=Release
    make $JOBS
    make install
}

##########################
#  Fetch and build nyx-lib
##########################
function build_nyx-lib
{
    do_fetch openwebos/nyx-lib $1 nyx-lib submissions/
    mkdir -p $BASE/nyx-lib/build
    cd $BASE/nyx-lib/build
    cmake .. -DNO_TESTS=True -DNO_UTILS=True -DCMAKE_INSTALL_PREFIX=${LUNA_STAGING} -DCMAKE_BUILD_TYPE=Release
    make $JOBS
    make install
}

######################
#  Fetch and build qt4
######################
function build_qt4
{
    if [ ! -d $BASE/qt4 ] ; then
      do_fetch openwebos/qt $1 qt4
    fi
    export STAGING_DIR=${LUNA_STAGING}
    if [ ! -f $BASE/qt-build-desktop/Makefile ] ; then
        rm -rf $BASE/qt-build-desktop
    fi
    if [ ! -d $BASE/qt-build-desktop ] ; then
      mkdir -p $BASE/qt-build-desktop
      cd $BASE/qt-build-desktop
      if [ ! -e ../qt4/palm-desktop-configure.orig ] ; then
        cp ../qt4/palm-desktop-configure ../qt4/palm-desktop-configure.orig
        sed -i 's/-opensource/-opensource -fast -qconfig palm -no-dbus/' ../qt4/palm-desktop-configure
        sed -i 's/libs tools/libs/' ../qt4/palm-desktop-configure
      fi
      ../qt4/palm-desktop-configure
    fi
    cd $BASE/qt-build-desktop
    make $JOBS
    make install
}

################################
#  Fetch and build luna-service2
################################
function build_luna-service2
{
    do_fetch openwebos/luna-service2 $1 luna-service2 submissions/
    mkdir -p $BASE/luna-service2/build
    cd $BASE/luna-service2/build

    cmake .. -DNO_TESTS=True -DNO_UTILS=True -DCMAKE_INSTALL_PREFIX=${LUNA_STAGING} -DCMAKE_BUILD_TYPE=Release
    make $JOBS
    make install

    cp ${LUNA_STAGING}/include/luna-service2/lunaservice.h ${LUNA_STAGING}/include/ 
    cp ${LUNA_STAGING}/include/luna-service2/lunaservice-errors.h ${LUNA_STAGING}/include/ 

    cd $LUNA_STAGING/lib
    ln -sf libluna-service2.so liblunaservice.so
}

################################
#  Fetch and build npapi-headers
################################
function build_npapi-headers
{
    do_fetch isis-project/npapi-headers $1 npapi-headers
    cd $BASE/npapi-headers
    mkdir -p $LUNA_STAGING/include/webkit/npapi
    cp *.h $LUNA_STAGING/include/webkit/npapi
}

##################################
#  Fetch and build luna-webkit-api
##################################
function build_luna-webkit-api
{
    do_fetch openwebos/luna-webkit-api $1 luna-webkit-api
    cd $BASE/luna-webkit-api
    mkdir -p $LUNA_STAGING/include/ime
    cp *.h $LUNA_STAGING/include/ime
}

##################################
#  Fetch and build webkit
##################################
function build_webkit
{

    #if [ ! -d $BASE/$WEBKIT_DIR ] ; then
          do_fetch isis-project/WebKit $1 $WEBKIT_DIR
    #fi
    cd $BASE/$WEBKIT_DIR
    if [ ! -e Tools/Tools.pro.prepatch ] ; then
      cp Tools/Tools.pro Tools/Tools.pro.prepatch
      sed -i '/PALM_DEVICE/s/:!contains(DEFINES, MACHINE_DESKTOP)//' Tools/Tools.pro
    fi
    if [ ! -e Source/WebCore/platform/webos/LunaServiceMgr.cpp.prepatch ] ; then
      cp Source/WebCore/platform/webos/LunaServiceMgr.cpp \
        Source/WebCore/platform/webos/LunaServiceMgr.cpp.prepatch 
      patch --directory=Source/WebCore/platform/webos < ${BASE}/luna-sysmgr/desktop-support/webkit-PALM_SERVICE_BRIDGE.patch
    fi
    export QTDIR=$BASE/qt4
    export QMAKE=$LUNA_STAGING/bin/qmake-palm
    export QMAKEPATH=$WEBKIT_DIR/Tools/qmake
    export WEBKITOUTPUTDIR="WebKitBuild/isis-x86"

    ./Tools/Scripts/build-webkit --qt \
        --release \
        --no-video \
        --no-3d-canvas \
        --only-webkit \
        --no-webkit2 \
        --qmake="${QMAKE}" \
        --makeargs="${JOBS}" \
        --makeargs="${PARALLEL_MAKE}" \
        --qmakearg="DEFINES+=MACHINE_DESKTOP" \
        --qmakearg="DEFINES+=ENABLE_PALM_SERVICE_BRIDGE=1" \
        --qmakearg="DEFINES+=PALM_DEVICE" \
        --qmakearg="DEFINES+=XP_UNIX" \
        --qmakearg="DEFINES+=XP_WEBOS" \
        --qmakearg="DEFINES+=QT_WEBOS"

    if [ "$?" != "0" ] ; then
       echo Failed to make $NAME
       exit 1
    fi
    pushd $WEBKITOUTPUTDIR/Release
    make install
    if [ "$?" != "0" ] ; then
       echo Failed to install $NAME
       exit 1
    fi
    popd
}

##################################
#  Fetch and build luna-sysmgr-ipc
##################################
function build_luna-sysmgr-ipc
{
    do_fetch openwebos/luna-sysmgr-ipc $1 luna-sysmgr-ipc
    cd $BASE/luna-sysmgr-ipc
    make -e PREFIX=$LUNA_STAGING -f Makefile.Ubuntu install BUILD_TYPE=release
}

###########################################
#  Fetch and build luna-sysmgr-ipc-messages
###########################################
function build_luna-sysmgr-ipc-messages
{
    do_fetch openwebos/luna-sysmgr-ipc-messages $1 luna-sysmgr-ipc-messages
    cd $BASE/luna-sysmgr-ipc-messages
    make -e PREFIX=$LUNA_STAGING -f Makefile.Ubuntu install BUILD_TYPE=release
}

##############################
#  Fetch and build luna-sysmgr
##############################
function build_luna-sysmgr
{
    if [ ! -d $BASE/luna-sysmgr ] ; then
      do_fetch openwebos/luna-sysmgr $1 luna-sysmgr
    fi
    cd $BASE/luna-sysmgr
    if [ ! -e Makefile.Ubuntu ] ; then
        $LUNA_STAGING/bin/qmake-palm
    fi
    make $JOBS -f Makefile.Ubuntu
    mkdir -p $LUNA_STAGING/lib/sysmgr-images
    cp -frad images/* $LUNA_STAGING/lib/sysmgr-images
    cp debug-x86/LunaSysMgr $LUNA_STAGING/lib
    
    cp desktop-support/service-bus.sh  ../service-bus.sh
    cp desktop-support/run-luna-sysmgr.sh  ../run-luna-sysmgr.sh
    cp desktop-support/install-luna-sysmgr.sh ../install-luna-sysmgr.sh
    mkdir -p ../ls2
    cp desktop-support/ls*.conf ../ls2
}

###############
# build wrapper
###############
function build
{
    if [ "$1" = "webkit" ] ; then
        BUILD_DIR=$WEBKIT_DIR
    else
        BUILD_DIR=$1
    fi
    if [ $SKIPSTUFF -eq 0 ] || [ ! -d $BASE/$BUILD_DIR ] || \
       [ ! -e $BASE/$BUILD_DIR/luna-desktop-build.stamp ] ; then
        echo
        echo "Building ${BUILD_DIR} ..."
        echo
        time build_$1 $2 $3 $4
        echo
        if [ -d $BASE/$BUILD_DIR ] ; then
            touch $BASE/$BUILD_DIR/luna-desktop-build.stamp
        fi
    return
    fi
    echo
    echo "Skipping $1 ..."
    echo
}


echo ""
echo "**********************************************************"
echo "Binaries will be built in $BASE."
echo ""
echo "If you want to change this edit the 'BASE' variable in this script."
echo ""
echo "(Checking processors: $PROCS found)"
echo ""
echo "**********************************************************"
echo ""

mkdir -p $BASE
mkdir -p $LUNA_STAGING/lib
mkdir -p $LUNA_STAGING/bin
mkdir -p $LUNA_STAGING/include
mkdir -p $LUNA_STAGING/share/dbus-1/system-services
set -x

if [ ! -d $BASE/luna-sysmgr ] ; then
    do_fetch openwebos/luna-sysmgr 0.820 luna-sysmgr
fi
rm -f $BASE/luna-sysmgr/luna-desktop-build.stamp


build cjson 35
build pbnjson 0.2
build pmloglib 21
build nyx-lib 58
build luna-service2 140
build qt4 0.33
build npapi-headers 0.4
build luna-webkit-api 0.90
build webkit 0.3
build luna-sysmgr-ipc 0.90
build luna-sysmgr-ipc-messages 0.90
build luna-sysmgr 0.820

echo ""
echo "Complete. "
echo ""
echo "Binaries are in $LUNA_STAGING/lib, $LUNA_STAGING/bin"
echo ""
