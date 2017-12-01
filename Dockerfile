#FROM debian:8.7
#FROM debian:latest
#FROM debian:testing
#FROM ubuntu:16.10 # some issues with gold linker when using clang and fto and linker plugin.

FROM debian:sid

MAINTAINER "Witold Baryluk <witold.baryluk+docker@gmail.com>"

# Start with: docker run --rm -it baryluk/povray-bench:latest

ADD povray-3.7-stable.zip /root/

RUN apt-get -y update && \
  apt-get dist-upgrade -V -yy && \
  apt-get install --no-install-recommends -V \
  unzip \
  cpuid \
  hwloc \
  procps \
  cpufrequtils \
  dmidecode \
  pciutils \
  file \
  libc-bin \
  lm-sensors \
  util-linux \
  schedtool \
  numactl \
  cpuset \
  build-essential \
  automake \
  autoconf \
  libboost-dev \
  zlib1g-dev \
  libpng-dev \
  libjpeg-dev \
  libtiff5-dev \
  libopenexr-dev \
  libboost-thread-dev \
  time \
  gcc-6 g++-6 \
  clang-4.0 \
  llvm-4.0-dev \
  curl \
  --quiet --assume-yes && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

#  clang-3.9 \
#  llvm-3.9-dev \

#  gcc-7 g++-7 \
#  clang-4.0 \
\
# The llvm-3.9-dev is ~required, because of the bug with ld.so.conf and linker paths in Ubuntu.
# https://bugs.launchpad.net/ubuntu/+source/llvm-toolchain-snapshot/+bug/1254970

ENV CLANG_VERSION=4.0
ENV GCC_VERSION=6

ADD benchmark_start.sh benchmark.sh /root/

ENTRYPOINT ["/root/benchmark_start.sh"]
CMD ["run"]
