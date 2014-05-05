#!/bin/bash

OPENSSL_VERSION=1.0.1g
PYTHON_VERSION=2.6.9

set -e

# Figure out what directory this script is in
SCRIPT="$0"
if [[ $(readlink $SCRIPT) != "" ]]; then
    SCRIPT=$(dirname $SCRIPT)/$(readlink $SCRIPT)
fi
if [[ $0 = ${0%/*} ]]; then
    SCRIPT=$(pwd)/$0
fi
LINUX_DIR=$(cd ${SCRIPT%/*} && pwd -P)

DEPS_DIR="${LINUX_DIR}/deps"
BUILD_DIR="${LINUX_DIR}/py26-x86_64"
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
    wget "http://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz"
    tar xvfz openssl-$OPENSSL_VERSION.tar.gz
    rm openssl-$OPENSSL_VERSION.tar.gz
    cd $LINUX_DIR
fi

if [[ -e $OPENSSL_BUILD_DIR ]]; then
    rm -R $OPENSSL_BUILD_DIR
fi
cp -R $OPENSSL_DIR $BUILD_DIR

cd $OPENSSL_BUILD_DIR

patch -p0 < $LINUX_DIR/patch/patch-cms
patch -p0 < $LINUX_DIR/patch/patch-smime
patch -p0 < $LINUX_DIR/patch/patch-SSL_accept
patch -p0 < $LINUX_DIR/patch/patch-SSL_clear
patch -p0 < $LINUX_DIR/patch/patch-SSL_COMP_add_compression_method
patch -p0 < $LINUX_DIR/patch/patch-SSL_connect
patch -p0 < $LINUX_DIR/patch/patch-SSL_CTX_add_session
patch -p0 < $LINUX_DIR/patch/patch-SSL_CTX_load_verify_locations
patch -p0 < $LINUX_DIR/patch/patch-SSL_CTX_set_client_CA_list
patch -p0 < $LINUX_DIR/patch/patch-SSL_CTX_set_session_id_context
patch -p0 < $LINUX_DIR/patch/patch-SSL_CTX_set_ssl_version
patch -p0 < $LINUX_DIR/patch/patch-SSL_CTX_use_psk_identity_hint
patch -p0 < $LINUX_DIR/patch/patch-SSL_do_handshake
patch -p0 < $LINUX_DIR/patch/patch-SSL_read
patch -p0 < $LINUX_DIR/patch/patch-SSL_session_reused
patch -p0 < $LINUX_DIR/patch/patch-SSL_set_fd
patch -p0 < $LINUX_DIR/patch/patch-SSL_set_session
patch -p0 < $LINUX_DIR/patch/patch-SSL_shutdown
patch -p0 < $LINUX_DIR/patch/patch-SSL_write
./config shared no-md2 no-rc5 no-ssl2 --prefix=$OUT_DIR
make depend
make
make install

cd $LINUX_DIR


if [[ ! -e $PYTHON_DIR ]]; then
    cd $DEPS_DIR
    wget "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz"
    tar xvfz Python-$PYTHON_VERSION.tgz
    rm Python-$PYTHON_VERSION.tgz
    cd ..
fi

if [[ -e $PYTHON_BUILD_DIR ]]; then
    rm -R $PYTHON_BUILD_DIR
fi
cp -R $PYTHON_DIR $BUILD_DIR

cd $PYTHON_BUILD_DIR

./configure --prefix=$OUT_DIR --without-gcc
make
make install

cd $LINUX_DIR


cd $DEPS_DIR

if [[ ! -e ./get-pip.py ]]; then
    curl -O --location "https://bootstrap.pypa.io/get-pip.py"
fi

export CPPFLAGS="-I${OUT_DIR}/include $CPPFLAGS"
export LDFLAGS="-L${OUT_DIR}/lib $LDFLAGS"

$BIN_DIR/python2.6 ./get-pip.py
$BIN_DIR/pip2.6 install cryptography
