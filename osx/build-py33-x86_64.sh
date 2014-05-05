#!/bin/bash

OPENSSL_VERSION=1.0.1g
PYTHON_VERSION=3.3.5

set -e

export CC=/usr/bin/clang

export CFLAGS="-arch x86_64 -mmacosx-version-min=10.7"
export LDFLAGS="-arch x86_64 -mmacosx-version-min=10.7"

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
BUILD_DIR="${OSX_DIR}/py33-x86_64"
OUT_DIR="$BUILD_DIR/out"
BIN_DIR="$OUT_DIR/bin"

mkdir -p $DEPS_DIR
mkdir -p $BUILD_DIR
mkdir -p $OUT_DIR

OPENSSL_DIR="${DEPS_DIR}/openssl-$OPENSSL_VERSION"
OPENSSL_BUILD_DIR="${BUILD_DIR}/openssl-$OPENSSL_VERSION"

PYTHON_DIR="${DEPS_DIR}/Python-$PYTHON_VERSION"
PYTHON_BUILD_DIR="${BUILD_DIR}/Python-$PYTHON_VERSION"

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

OLD_LANG=$LANG
unset LANG

sed -i "" 's|\"iphoneos-cross\"\,\"llvm-gcc\:-O3|\"iphoneos-cross\"\,\"clang\:-O3|g' Configure
sed -i "" 's/CC= cc/CC= clang/g' Makefile.org
sed -i "" 's/MAKEDEPPROG=makedepend/MAKEDEPPROG=$(CC) -M/g' Makefile.org

export LANG=$OLD_LANG

./Configure darwin64-x86_64-cc shared no-md2 no-rc5 no-ssl2 --prefix=$OUT_DIR
make depend
make
make install

cd $OSX_DIR


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

./configure --prefix=$OUT_DIR
make
make install

cd $OSX_DIR


cd $DEPS_DIR

if [[ ! -e ./get-pip.py ]]; then
    curl -O --location "https://bootstrap.pypa.io/get-pip.py"
fi

export CPPFLAGS="-I${OUT_DIR}/include $CPPFLAGS"
export LDFLAGS="-L${OUT_DIR}/lib $LDFLAGS"

$BIN_DIR/python3.3 ./get-pip.py
$BIN_DIR/pip3.3 install cryptography
