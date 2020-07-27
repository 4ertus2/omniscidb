#!/usr/bin/env bash

set -e
set -x

HTTP_DEPS="https://dependencies.mapd.com/thirdparty"

SUFFIX=${SUFFIX:=$(date +%Y%m%d)}
PREFIX=/usr/local/mapd-deps

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPTS_DIR/common-functions.sh

# Establish distro
source /etc/os-release
if [ "$ID" == "ubuntu" ] ; then
  PACKAGER="apt -y"
  if [ "$VERSION_ID" != "20.04" ]; then
    echo "Ubuntu 20.4 is the only debian-based release supported by this script"
    exit 1
  fi
else
  echo "Only Ubuntu is supported by this script"
  exit 1
fi

sudo mkdir -p $PREFIX
sudo chown -R $(id -u) $PREFIX

sudo apt update
sudo apt install -y \
    software-properties-common \
    build-essential \
    ccache \
    git \
    wget \
    curl \
    libboost-all-dev \
    libgoogle-glog-dev \
    libssl-dev \
    libevent-dev \
    default-jre \
    default-jre-headless \
    default-jdk \
    default-jdk-headless \
    maven \
    libncurses5-dev \
    libldap2-dev \
    binutils-dev \
    google-perftools \
    libdouble-conversion-dev \
    libevent-dev \
    libgflags-dev \
    libgoogle-perftools-dev \
    libiberty-dev \
    libjemalloc-dev \
    libglu1-mesa-dev \
    liblz4-dev \
    liblzma-dev \
    libbz2-dev \
    libarchive-dev \
    libcurl4-openssl-dev \
    libedit-dev \
    uuid-dev \
    libsnappy-dev \
    zlib1g-dev \
    autoconf \
    autoconf-archive \
    automake \
    libpng-dev \
    rsync \
    unzip \
    jq \
    python-dev \
    python-yaml \
    swig \
    pkg-config \
    libxerces-c-dev \
    libxmlsec1-dev \
    gcc \
    g++ \
    ninja-build \
    cmake \
    llvm-10 \
    libclang-10-dev \
    bison++ \
    golang

# Needed to find sqlite3, xmltooling, and xml_security_c
export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig:$PKG_CONFIG_PATH
export PATH=$PREFIX/bin:$PATH

VERS=0.13.0
wget --continue http://apache.claz.org/thrift/$VERS/thrift-$VERS.tar.gz
tar xvf thrift-$VERS.tar.gz
pushd thrift-$VERS
CFLAGS="-fPIC" CXXFLAGS="-fPIC" JAVA_PREFIX=$PREFIX/lib ./configure \
    --with-lua=no \
    --with-python=no \
    --with-php=no \
    --with-ruby=no \
    --with-qt4=no \
    --with-qt5=no \
    --with-java=no \
    --prefix=$PREFIX
make -j $(nproc)
make install
popd

#c-blosc
VERS=1.14.4
wget --continue https://github.com/Blosc/c-blosc/archive/v$VERS.tar.gz
tar xvf v$VERS.tar.gz
BDIR="c-blosc-$VERS/build"
rm -rf "$BDIR"
mkdir -p "$BDIR"
pushd "$BDIR"
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=$PREFIX \
    -DBUILD_BENCHMARKS=off \
    -DBUILD_TESTS=off \
    -DPREFER_EXTERNAL_SNAPPY=off \
    -DPREFER_EXTERNAL_ZLIB=off \
    -DPREFER_EXTERNAL_ZSTD=off \
    ..
make -j $(nproc)
make install
popd

VERS=2019.04.29.00
download https://github.com/facebook/folly/archive/v$VERS.tar.gz
extract v$VERS.tar.gz
pushd folly-$VERS/build/
CXXFLAGS="-fPIC -pthread" cmake -DCMAKE_INSTALL_PREFIX=$PREFIX -DBUILD_SHARED_LIBS=on ..
makej
make install
popd

# TBB
install_tbb

# Apache Arrow (see common-functions.sh)
ARROW_BOOST_USE_SHARED="ON"
install_arrow

# librdkafka
install_rdkafka

cat > $PREFIX/mapd-deps.sh <<EOF
PREFIX=$PREFIX

LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH
LD_LIBRARY_PATH=\$PREFIX/lib:\$LD_LIBRARY_PATH
LD_LIBRARY_PATH=\$PREFIX/lib64:\$LD_LIBRARY_PATH

PATH=/usr/local/cuda/bin:\$PATH
PATH=\$PREFIX/go/bin:\$PATH
PATH=\$PREFIX/bin:\$PATH

VULKAN_SDK=\$PREFIX
VK_LAYER_PATH=\$PREFIX/etc/vulkan/explicit_layer.d

CMAKE_PREFIX_PATH=\$PREFIX:\$CMAKE_PREFIX_PATH

GOROOT=\$PREFIX/go

export LD_LIBRARY_PATH PATH VULKAN_SDK VK_LAYER_PATH CMAKE_PREFIX_PATH GOROOT
EOF

sudo chmod +x $PREFIX/mapd-deps.sh

echo
echo "Done. Be sure to source the 'mapd-deps.sh' file to pick up the required environment variables:"
echo "    source $PREFIX/mapd-deps.sh"
echo "Run 'cmake -DCMAKE_PREFIX_PATH=/usr/local/mapd-deps/ -DPREFER_STATIC_LIBS=1 -DENABLE_GEOS=0 -DENABLE_AWS_S3=0 -DENABLE_RENDERING=0 -DENABLE_TESTS=0 ..'"
