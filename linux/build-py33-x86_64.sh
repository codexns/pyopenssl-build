#!/bin/bash

OPENSSL_VERSION=1.0.1g
PYTHON_VERSION=3.3.5
LIBFFI_VERSION=3.0.13

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
LINUX_DIR=$(cd ${SCRIPT%/*} && pwd -P)

DEPS_DIR="${LINUX_DIR}/deps"
BUILD_DIR="${LINUX_DIR}/py33-x86_64"
OUT_DIR="$BUILD_DIR/out"
BIN_DIR="$OUT_DIR/bin"

export LDFLAGS="-Wl,-rpath='\$\$ORIGIN/' -Wl,-rpath=${OUT_DIR}/lib -L${OUT_DIR}/lib -L/usr/lib/x86_64-linux-gnu"
export CPPFLAGS="-I${OUT_DIR}/include -I${OUT_DIR}/include/openssl -I${OUT_DIR}/lib/libffi-${LIBFFI_VERSION}/include/"

mkdir -p $DEPS_DIR
mkdir -p $BUILD_DIR
mkdir -p $OUT_DIR

LIBFFI_DIR="${DEPS_DIR}/libffi-$LIBFFI_VERSION"
LIBFFI_BUILD_DIR="${BUILD_DIR}/libffi-$LIBFFI_VERSION"

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

if [[ ! -e $OPENSSL_BUILD_DIR ]] || [[ $CLEAN_SSL != "" ]]; then
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
    ./config shared no-md2 no-rc5 no-ssl2 --prefix=$OUT_DIR -Wl,--version-script=openssl.ld -Wl,-Bsymbolic-functions -Wl,-rpath=XORIGIN/ -Wl,-rpath=${OUT_DIR}/lib -fPIC
    echo 'OPENSSL_1.0.1G_PYTHON {
    global:
        *;
};
' > openssl.ld
    make depend
    make
    chrpath -r "\$ORIGIN/:${OUT_DIR}/lib" libssl.so.1.0.0
    chrpath -r "\$ORIGIN/:${OUT_DIR}/lib" libcrypto.so.1.0.0
    make install

    cd $LINUX_DIR
fi

if [[ ! -e $LIBFFI_DIR ]]; then
    cd $DEPS_DIR
    wget "ftp://sourceware.org/pub/libffi/libffi-$LIBFFI_VERSION.tar.gz"
    tar xvfz libffi-$LIBFFI_VERSION.tar.gz
    rm libffi-$LIBFFI_VERSION.tar.gz
    cd $LINUX_DIR
fi

if [[ -e $LIBFFI_BUILD_DIR ]]; then
    rm -R $LIBFFI_BUILD_DIR
fi
cp -R $LIBFFI_DIR $BUILD_DIR

cd $LIBFFI_BUILD_DIR
./configure --disable-shared --prefix=${OUT_DIR} CFLAGS=-fPIC
make
make install

cd $LINUX_DIR

if [[ ! -e $PYTHON_DIR ]]; then
    cd $DEPS_DIR
    wget "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz"
    tar xvfz Python-$PYTHON_VERSION.tgz
    rm Python-$PYTHON_VERSION.tgz
    cd $LINUX_DIR
fi

if [[ -e $PYTHON_BUILD_DIR ]]; then
    rm -R $PYTHON_BUILD_DIR
fi
cp -R $PYTHON_DIR $BUILD_DIR

cd $PYTHON_BUILD_DIR

./configure --prefix=$OUT_DIR
make
make install

cd $LINUX_DIR


cd $DEPS_DIR

if [[ ! -e ./get-pip.py ]]; then
    wget "https://bootstrap.pypa.io/get-pip.py"
fi

$BIN_DIR/python3.3 ./get-pip.py

# Since this doesn't use make, we change the rpath to use a single $
export LDFLAGS="-Wl,-rpath='\$ORIGIN/' -Wl,-rpath=${OUT_DIR}/lib -L${OUT_DIR}/lib -L/usr/lib/x86_64-linux-gnu"

$BIN_DIR/pip3.3 install cryptography
