#!/bin/bash

OPENSSL_VERSION=1.0.1j
PYTHON_VERSION=2.6.9
LIBFFI_VERSION=3.2.1

CLEAN_SSL=$1

set -e

# Figure out what directory this script is in
SCRIPT="$0"
if [[ $(readlink $SCRIPT) != "" ]]; then
    SCRIPT=$(dirname $SCRIPT)/$(readlink $SCRIPT)
fi
if [[ $0 = ${0%/*} ]]; then
    SCRIPT=$(pwd)/$0
fi
OSX_DIR=$(cd ${SCRIPT%/*} && pwd -P)

DEPS_DIR="${OSX_DIR}/deps"
BUILD_DIR="${OSX_DIR}/py26-x86_64"
STAGING_DIR="$BUILD_DIR/staging"
BIN_DIR="$STAGING_DIR/bin"
TMP_DIR="$BUILD_DIR/tmp"
OUT_DIR="$BUILD_DIR/../../out/py26_osx_x64"

export CPPFLAGS="-I${STAGING_DIR}/include -I${STAGING_DIR}/include/openssl -I$(xcrun --show-sdk-path)/usr/include -I${STAGING_DIR}/lib/libffi-${LIBFFI_VERSION}/include/"
# The macosx-version-min flags remove the dependency on libgcc_s.1.dylib
export CFLAGS="-arch x86_64 -mmacosx-version-min=10.6"
export LDFLAGS="-arch x86_64 -mmacosx-version-min=10.6 -L${STAGING_DIR}/lib"

mkdir -p $DEPS_DIR
mkdir -p $BUILD_DIR
mkdir -p $STAGING_DIR

LIBFFI_DIR="${DEPS_DIR}/libffi-$LIBFFI_VERSION"
LIBFFI_BUILD_DIR="${BUILD_DIR}/libffi-$LIBFFI_VERSION"

OPENSSL_DIR="${DEPS_DIR}/openssl-$OPENSSL_VERSION"
OPENSSL_BUILD_DIR="${BUILD_DIR}/openssl-$OPENSSL_VERSION"

PYTHON_DIR="${DEPS_DIR}/Python-$PYTHON_VERSION"
PYTHON_BUILD_DIR="${BUILD_DIR}/Python-$PYTHON_VERSION"


if [[ ! -e $OPENSSL_BUILD_DIR ]] || [[ $CLEAN_SSL != "" ]]; then
    if [[ ! -e $OPENSSL_DIR ]]; then
        cd $DEPS_DIR
        curl -O --location "http://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz"
        tar xvfz openssl-$OPENSSL_VERSION.tar.gz
        rm openssl-$OPENSSL_VERSION.tar.gz
        cd $OSX_DIR
    fi

    if [[ -e $OPENSSL_BUILD_DIR ]]; then
        rm -R $OPENSSL_BUILD_DIR
    fi
    cp -R $OPENSSL_DIR $BUILD_DIR

    cd $OPENSSL_BUILD_DIR

    CC=gcc ./Configure darwin64-x86_64-cc enable-static-engine no-md2 no-rc5 no-ssl2 --prefix=$STAGING_DIR
    make depend
    make
    make install

    cd $OSX_DIR
fi


if [[ ! -e $LIBFFI_DIR ]]; then
    cd $DEPS_DIR
    curl -O --location "ftp://sourceware.org/pub/libffi/libffi-$LIBFFI_VERSION.tar.gz"
    tar xvfz libffi-$LIBFFI_VERSION.tar.gz
    rm libffi-$LIBFFI_VERSION.tar.gz
    cd $OSX_DIR
fi

if [[ -e $LIBFFI_BUILD_DIR ]]; then
    rm -R $LIBFFI_BUILD_DIR
fi
cp -R $LIBFFI_DIR $BUILD_DIR

cd $LIBFFI_BUILD_DIR
./configure --disable-shared --prefix=${STAGING_DIR} CFLAGS=-fPIC
make
make install

cd $OSX_DIR


export PKG_CONFIG_PATH="$STAGING_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"


if [[ ! -e $PYTHON_DIR ]]; then
    cd $DEPS_DIR
    curl -O --location "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz"
    tar xvfz Python-$PYTHON_VERSION.tgz
    rm Python-$PYTHON_VERSION.tgz
    cd ..
fi

if [[ -e $PYTHON_BUILD_DIR ]]; then
    rm -R $PYTHON_BUILD_DIR
fi
cp -R $PYTHON_DIR $BUILD_DIR

cd $PYTHON_BUILD_DIR

./configure --prefix=$STAGING_DIR
make
make install

cd $OSX_DIR


cd $DEPS_DIR

if [[ ! -e ./get-pip.py ]]; then
    curl -O --location "https://bootstrap.pypa.io/get-pip.py"
fi

$BIN_DIR/python2.6 ./get-pip.py
if [[ $($BIN_DIR/pip2.6 list | grep pyopenssl) != "" ]]; then
    $BIN_DIR/pip2.6 uninstall -y pyopenssl
fi
if [[ $($BIN_DIR/pip2.6 list | grep cryptography) != "" ]]; then
    $BIN_DIR/pip2.6 uninstall -y cryptography
fi

rm -Rf $TMP_DIR
$BIN_DIR/pip2.6 install --build $TMP_DIR cryptography pyopenssl

CRYPTOGRAPHY_VERSION=$($BIN_DIR/pip2.6 show cryptography | grep Version | sed 's/Version: //')
PYOPENSSL_VERSION=$($BIN_DIR/pip2.6 show pyopenssl | grep Version | sed 's/Version: //')

rm -Rf $OUT_DIR
mkdir -p $OUT_DIR

cp $STAGING_DIR/lib/python2.6/site-packages/six.py $OUT_DIR/
cp -R $STAGING_DIR/lib/python2.6/site-packages/OpenSSL $OUT_DIR/
cp -R $STAGING_DIR/lib/python2.6/site-packages/cryptography $OUT_DIR/
cp -R $STAGING_DIR/lib/python2.6/site-packages/cffi $OUT_DIR/
cp -R $STAGING_DIR/lib/python2.6/site-packages/pycparser $OUT_DIR/
cp $STAGING_DIR/lib/python2.6/site-packages/_cffi_backend.so $OUT_DIR/

cd $OUT_DIR
zip -r ../cryptography-${CRYPTOGRAPHY_VERSION}_pyopenssl-${PYOPENSSL_VERSION}_openssl-${OPENSSL_VERSION}_py26_osx-x64.zip *
