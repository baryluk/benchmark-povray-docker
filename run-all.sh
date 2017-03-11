#!/bin/sh

IMAGE=${1:-baryluk/povray-bench}

COMMON="-e BENCHMARK_VERBOSE=1 -e BENCHMARK_MTONLY=1"

docker run --rm -it ${COMMON} -e BENCHMARK_LTO=1 ${IMAGE?}
docker run --rm -it ${COMMON} -e BENCHMARK_LTO=1 -e BENCHMARK_CLANG=1 ${IMAGE?}
docker run --rm -it ${COMMON} ${IMAGE?}
docker run --rm -it ${COMMON} -e BENCHMARK_CLANG=1 ${IMAGE?}
docker run --rm -it ${COMMON} -e BENCHMARK_LTO=1 -e BENCHMARK_PGO=1 ${IMAGE?}
docker run --rm -it ${COMMON} -e BENCHMARK_LTO=1 -e BENCHMARK_PGO=1 -e BENCHMARK_CLANG=1 ${IMAGE?}
