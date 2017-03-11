#!/bin/sh

BUILD=${1?}

#docker build -t povray-bench .
#for t in baryluk/povray-bench:latest baryluk/povray-bench:ubuntu-16.10-gcc-6.2.0; do
for t in baryluk/povray-bench:latest baryluk/povray-bench:debian-sid_gcc-6-6.3.0_clang-4.0-4.2.1; do
  docker tag "${BUILD?}" "${t?}"
done
docker push baryluk/povray-bench
