# Fetch base image
FROM debian:stretch as qemu

ENV QEMU_VERSION 6.0.0
# Install build dependencies
RUN apt-get update -qq && apt-get install -yqq \
    build-essential \
    ca-certificates \
    curl \
    xz-utils \
    git \
    libglib2.0-dev \
    libpixman-1-dev \
    pkg-config \
    --no-install-recommends
    
# dependencies for wget over HTTPS
RUN apt-get -y install libreadline-gplv2-dev libncursesw5-dev libssl-dev libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev

# install python 3.6 and ninja
ARG BUILDDIR="/tmp/build"
ARG PYTHON_VER="3.6.8"
WORKDIR ${BUILDDIR}
RUN apt-get update -qq && \
apt-get upgrade -y  > /dev/null 2>&1 && \
apt-get install wget gcc make zlib1g-dev -y -qq > /dev/null 2>&1 && \
wget --quiet https://www.python.org/ftp/python/${PYTHON_VER}/Python-${PYTHON_VER}.tgz > /dev/null 2>&1 && \
tar zxf Python-${PYTHON_VER}.tgz && \
cd Python-${PYTHON_VER} && \
./configure  > /dev/null 2>&1 && \
make > /dev/null 2>&1 && \
make install > /dev/null 2>&1 && \
rm -rf ${BUILDDIR}
RUN pip3 install ninja

# download and build qemu
RUN curl "https://download.qemu.org/qemu-${QEMU_VERSION}.tar.xz" -o "qemu-${QEMU_VERSION}.tar.xz"
RUN mkdir qemu && tar xf "qemu-${QEMU_VERSION}.tar.xz" --strip-components=1 -C qemu
WORKDIR qemu

# Apply patch to fix issues with Go
# - patches the file "linux-user/signal.c"
RUN curl -sSL https://github.com/resin-io/qemu/commit/db186a3f83454268c43fc793a48bc28c41368a6c.patch | patch linux-user/signal.c

# Build qemu-*-static binaries for arm, aarch64, ppc64le
# - resulting binaries are located in "/usr/local/bin/qemu-*"
ARG TARGET_ARCH=arm-linux-user,aarch64-linux-user,ppc64le-linux-user,riscv64-linux-user
RUN mkdir build \
 && cd build \
 && ../configure --static --target-list=$TARGET_ARCH  \
 && make -j $(nproc) install

FROM busybox
COPY --from=qemu /usr/local/bin/qemu-arm /qemu-arm
COPY --from=qemu /usr/local/bin/qemu-aarch64 /qemu-aarch64
COPY --from=qemu /usr/local/bin/qemu-ppc64le /qemu-ppc64le
COPY --from=qemu /usr/local/bin/qemu-riscv64 /qemu-riscv64
ADD register.sh /register.sh
CMD ["/register.sh", "--reset"]
