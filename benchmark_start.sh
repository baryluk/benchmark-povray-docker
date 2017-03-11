#!/bin/bash

DROP_TO_SHELL=${BENCHMARK_SHELL:-0}
ENABLE_UPLOAD=${BENCHMARK_UPLOAD:-0}

# When asking for a exit status of a pipe, if any pipe component fails, set it
# to the last failed command, not the last one (which could succeed without
# error).
set -o pipefail  # Bashism

# --output=0 disables output stream buffering.
# --output=L will make stream line buffered.
if ! /usr/bin/stdbuf --output=0 --error=0 /root/benchmark.sh "$@" 2>&1 | tee /tmp/benchmark_full_output.txt; then
  echo 'benchmark.sh encountered an error during execution.' >&2

  if [ "${ENABLE_UPLOAD}" != "0" ]; then
    echo 'benchmark.sh finished with an error and user requested results upload. Upload skipped.' >&2
  fi

  if [ "${DROP_TO_SHELL}" != "0" ]; then
    echo 'Dropping to bash shell as requested.' >&2
    exec /bin/bash
    exit 2
  fi

  exit 1
fi

HELP=${BENCHMARK_HELP:-0}
if [ "${HELP}" != "0" ]; then
  exit 0
fi

if [ "${ENABLE_UPLOAD}" != "0" ]; then
  echo 'Benchmark finished without an error and user requested resutls upload.'
  echo 'Benchmark output size (lines):' $(/usr/bin/wc -l /tmp/benchmark_full_output.txt)
  cd /tmp
  /bin/tar czf /tmp/files.tar.gz out/* benchmark_full_output.txt
  echo 'Uploading...'
  # TODO(baryluk): Upload other files. /tmp/cpuid.txt /proc/cpuinfo and separate outputs of all other programs.
  /usr/bin/curl --form 'benchmark=povray' --form 'version=1' --form "data=@/tmp/files.tar.gz;type=application/x-compressed-tar" https://benchmarks.functor.xyz/uploader.php
  # --silent
  echo 'done'
fi
