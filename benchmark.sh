#!/bin/sh

# Author: Witold Baryluk <witold.baryluk+docker@gmail.com>

# TODO(baryluk): Static linking.
# TODO(baryluk): More compilers and compiler versions.
# TODO(baryluk): i386, x32 sub-architecture support.
# TODO(baryluk): arm, aarch64, ppc architecture support.
# TODO(baryluk): Opt-in send results to public server.
# TODO(baryluk): Much more complex benchmark scene. With textures.
# TODO(baryluk): Make scene be at least 500MB, to test memory not just L3 cache.
# TODO(baryluk): Run single threaded benchmarks with smaller output image.
# TODO(baryluk): Automatically adjust number of runs, based on noise and speed.
# TODO(baryluk): Automatically select best run.
# TODO(baryluk): Run at elevate priority.
# TODO(baryluk): Dump result image to file and compare with reference.
# TODO(baryluk): Pass list of numbers of theads to run benchmarks to test scalling etc.

# TODO(baryluk): Print version of this script. Bump minor on cosmetic changes. Bump major on significant changes affecting scores.

#apt-get install libboost-dev zlib1g-dev libpng-dev libjpeg-dev libtiff5-dev libopenexr-dev libboost-thread-dev


set -e  # Exit on any subcommand error.
#set -x  # Print all executed commands first.
#set -u # Exit on a reference of undefined variables.

export LC_ALL=C

GCC_VERSION=6
#CLANG_VERSION=3.9  # in Ubuntu 16.04

#GCC_VERSION=7  # in debian experimental.
CLANG_VERSION=4.0  # in debian unstable.
#CLANG_VERSION=5.0  # in debian unstable / experimental

ENABLE_LTO=${BENCHMARK_LTO:-0}
ENABLE_PGO=${BENCHMARK_PGO:-0}
ENABLE_CLANG=${BENCHMARK_CLANG:-0}
OPTS=${BENCHMARK_COPTS}
BUILD_JOBS=${BENCHMARK_BUILD_JOBS:-0}
ENABLE_VERBOSE=${BENCHMARK_VERBOSE:-0}
ENABLE_BUILD=${BENCHMARK_BUILD:-0}
ENABLE_QUIET=${BENCHMARK_QUIET:-0}
ENABLE_QUICK=${BENCHMARK_QUICK:-0}
ENABLE_MT_ONLY=${BENCHMARK_MT_ONLY:-0}
MT_PASSES=${BENCHMARK_MT_PASSES:-5}
ST_PASSES=${BENCHMARK_ST_PASSES:-2}
ENABLE_TEMPS=${BENCHMARK_TEMPS:-0}
ENABLE_TIMESTAMPS=${BENCHMARK_TIMESTAMPS:-1}
ALLOW_ONDEMAND=${BENCHMARK_ONDEMAND:-0}

usage () {
  echo 'docker run options influencing benchmark:'
  echo '  -e BENCHMARK_LTO=1        Use LTO (Link time optimizations) when compiling and linking. Disabled by default.'
  echo '  -e BENCHMARK_PGO=1        Use PGO/FDO (Profile Guided / Feedback-Driven optimization). Can take up to hour longer. Disabled by default.'
  echo "  -e BENCHMARK_CLANG=1      Use clang-${CLANG_VERSION} compiler instead of gcc-${GCC_VERSION} compiler. Disabled by default."
  echo '  -e BENCHMARK_COPTS=...    Pass additional custom options to compiler flags. Empty by default.'
  echo '  -e BENCHMARK_BUILD_JOBS=1 Use specific numebr of processes for build. 0 - use all cores. 0 by default.'
  echo '  -e BENCHMARK_VERBOSE=1    Show detailed machine and build information. Disabled by default.'
  echo '  -e BENCHMARK_BUILD=1      Show all build outputs. Very verbose! Disabled by default.'
  echo '  -e BENCHMARK_QUIET=1      Be very quiet. Show only benchmark timings, nothing else. Disabled by default.'
  echo '  -e BENCHMARK_QUICK=1      Do not wait for system load to settle. Not recommended for benchmarking! Disabled by default.'
  echo '  -e BENCHMARK_MT_ONLY=1    Do not run single threaded benchmarks. Disabled by default.'
  echo '  -e BENCHMARK_MT_PASSES=5  Set number of multi threaded passes. Default 5.'
  echo '  -e BENCHMARK_ST_PASSES=2  Set number of single threaded passes. Default 2.'
  echo '  -e BENCHMARK_TEMPS=1      Show temperatures (if available) every 2 second during benchmark. Disabled by default.'
  echo '  -e BENCHMARK_UPLOAD=1     On success, upload full benchmark output and results to the author and https://benchmarks.functor.xyz/ site. Will set BENCHMARK_VERBOSE=1, BENCHMARK_QUIET=0 and BENCHMARK_QUICK=0 automatically unless with conflict with other flags. Disabled by default.'
  echo '  -e BENCHMARK_SHELL=1      Drop to shell in the container on any error. Disabled by default.'
  echo '  -e BENCHMARK_HELP=1       Show all available options and exit.'
  echo '  -e BENCHMARK_TIMESTAMPS=0 Disable timestamps. Enabled by default.'
  echo '  -e BENCHMARK_ONDEMAND=1   Allow "ondemand" cpu frequency governor. Disabled by default.'
  echo
  echo 'benchmark.sh options available and equivalent to above options:'
  echo '  -l    Use LTO.'
  echo '  -p    Use PGO/FDO.'
  echo '  -c    Use clang.'
  echo '  -j32  Use 32 processes for build. 0 - use all cores.'
  echo '  -v    Be verbose.'
  echo '  -b    Show build output.'
  echo '  -q    Be quiet.'
  echo '  -Q    Be quick.'
  echo '  -f    Be quick.'
  echo '  -m    Run multi threaded only.'
  echo '  -M5   Run 5 multi threaded passes.'
  echo '  -S2   Run 2 single threaded passes.'
  echo '  -t    Show temps.'
  echo '  -T    Show timestamps.'
  echo '  -h    Show this help and exit.'
}

while getopts lpcj:vbqQfmM:S:tTh f
do
  case $f in
    l) ENABLE_LTO=1;;
    p) ENABLE_PGO=1;;
    c) ENABLE_CLANG=1;;
    j) BUILD_JOBS=${OPTARG};;
    v) ENABLE_VERBOSE=1;;
    b) ENABLE_BUILD=1;;
    q) ENABLE_QUIET=1;;
    Q) ENABLE_QUICK=1;;
    f) ENABLE_QUICK=1;;
    m) ENABLE_MT_ONLY=1;;
    M) MT_PASSES=${OPTARG};;
    S) ST_PASSES=${OPTARG};;
    t) ENABLE_TEMPS=1;;
    T) ENABLE_TIMESTAMPS=1;;
    h) usage; exit 0;;
    \?) echo 'Unknown option passed to benchmark.sh' >&2; echo >&2; usage >&2; exit 1;;
  esac
done
shift $(/usr/bin/expr $OPTIND - 1)


if [ "${BENCHMARK_HELP}" != "" ]; then
  usage
  exit 0
fi

verbose () {
  if [ "${ENABLE_QUIET}" != "0" ]; then
    false
  fi
  if [ "${ENABLE_VERBOSE}" != "0" ]; then
    true
  else
    false
  fi
}

silent () {
  if [ "${ENABLE_QUIET}" != "0" ]; then
    true
  fi
  if [ "${ENABLE_VERBOSE}" != "0" ]; then
    false
  else
    true
  fi
}

supersilent () {
  if [ "${ENABLE_QUIET}" != "0" ]; then
    true
  else
    false
  fi
}

hole () {
  if [ "${ENABLE_QUIET}" != "0" ]; then
    cat >/dev/null
  else
    cat
  fi
}

d () {
  if [ "${ENABLE_TIMESTAMPS}" != "0" ]; then
    /bin/date --utc --iso-8601=seconds
  else
    true
  fi
}

mkdir /tmp/out

supersilent || d | tee /tmp/out/timestamp-start.txt

supersilent || echo $(d) "Passed options: VERBOSE=${BENCHMARK_VERBOSE} QUIET=${BENCHMARK_QUIET} CLANG=${BENCHMARK_CLANG} LTO=${BENCHMARK_LTO} PGO=${BENCHMARK_PGO} QUICK=${BENCHMARK_QUICK} TEMPS=${BENCHMARK_TEMPS} MT_PASSES=${BENCHMARK_MT_PASSES} ST_PASSES=${BENCHMARK_ST_PASSES} BUILD_JOBS=${BENCHMARK_BUILD_JOBS} COPTS=${BENCHMARK_OPTS}" | tee /tmp/out/passed-options.txt

if [ "${BENCHMARK_UPLOAD:-0}" != "0" ]; then
  # TODO(baryluk): This might not detect options passed via -v -q -f
  if [ "${BENCHMARK_VERBOSE:-1}" != "1" ]; then
    echo $(d) 'Benchmark results upload requested, but BENCHMARK_VERBOSE should be not set, or set to 1.' >&2
    exit 1
  fi
  if [ "${BENCHMARK_QUIET:-0}" != "0" ]; then
    echo $(d) 'Benchmark results upload requested, but BENCHMARK_QUIET should be not set, or set to 0.' >&2
    exit 1
  fi
  if [ "${BENCHMARK_QUICK:-0}" != "0" ]; then
    echo $(d) 'Benchmark results upload requested, but BENCHMARK_QUICK should be not set, or set to 0.' >&2
    exit 1
  fi
  echo $(d) 'Benchmark results upload requested, switching to ENABLE_VERBOSE=1 ENABLE_QUICK=0 ENABLE_QUIET=0'
  ENABLE_VERBOSE=1
  ENABLE_QUICK=0
  ENABLE_QUIET=0
  # TODO(baryluk): Enforce minimum of 5 ST passes and 3 ST passes. (or 5, once we fix it to be using separate scene or image size).
fi
echo $(d) "Using benchmark options: VERBOSE=${ENABLE_VERBOSE} QUIET=${ENABLE_QUIET} CLANG=${ENABLE_CLANG} LTO=${ENABLE_LTO} PGO=${ENABLE_PGO} QUICK=${ENABLE_QUICK} TEMPS=${ENABLE_TEMPS} MT_PASSES=${MT_PASSES} ST_PASSES=${ST_PASSES} BUILD_JOBS=${BUILD_JOBS} COPTS=${OPTS}" | tee /tmp/out/using-options.txt
echo "${OPTS}" > /tmp/out/custom_additional_benchmark_copts.txt

# Hardware / software info

supersilent || echo
supersilent || echo $(d) 'Machine details:'
supersilent || echo

if verbose; then
  echo $(d) 'GCC version:' $(gcc -v 2>&1 | grep '^gcc version' | tee /tmp/out/gcc-version.txt)
  echo $(d) 'G++ version:' $(g++ -v 2>&1 | grep '^gcc version' | tee /tmp/out/g++-version.txt)
  echo $(d) 'GNU ld version:' $(ld -v 2>&1 | tee /tmp/out/ld-version.txt)
  echo $(d) 'GNU gold version:' $(gold -v 2>&1 | tee /tmp/out/gold-version.txt)
  echo $(d) 'GNU ld.bfd version:' $(ld.bfd -v 2>&1 | tee /tmp/out/ld.bfd-version.txt)
  echo $(d) 'GNU ld.gold version:' $(ld.gold -v 2>&1 | tee /tmp/out/ld.gold-version.txt)
#  echo $(d) 'GNU ld.lld-4.0 version:' $(ld.lld-4.0 -v 2>&1 | tee /tmp/out/ld.lld-version.txt)
#  lld-link-4.0
#  clang-3.9
  echo

  echo $(d) 'Uname:' $(uname -a | tee /tmp/out/uname.txt)
  echo $(d) 'Kernel version:' $(cat /proc/version | tee /tmp/out/proc-version.txt || echo 'N/A')
  echo $(d) 'Debian version:' $(cat /etc/debian_version)
  echo
fi # verbose

cat /proc/cpuinfo > /tmp/out/proc-cpuinfo.txt || echo $(d) 'No /proc/cpuinfo available!' || true

/usr/bin/nproc > /tmp/out/nproc.txt || true

echo $(d) 'CPU model name:' $(egrep '^model name' /tmp/out/proc-cpuinfo.txt | head -n 1 || echo 'N/A')

if verbose; then
  echo $(d) 'CPU cores/threads:' $(egrep '^processor' /tmp/out/proc-cpuinfo.txt | wc -l || echo 'N/A')
  echo $(d) 'CPU flags:' $(egrep '^flags' /tmp/out/proc-cpuinfo.txt | head -n 1 || echo 'N/A')
  echo

  /usr/bin/cpuid --one-cpu > /tmp/out/cpuid-one-cpu.txt

  echo $(d) 'cpuid name: ' $(egrep 'simple synth' /tmp/out/cpuid-one-cpu.txt | head -n 1)
  echo $(d) 'cpuid features start (mostly performance related only):'

  #   feature information (1/edx):
  egrep '  CMPXCHG8B inst. .*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  conditional move/compare instruction .*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  CLFLUSH instruction .*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  MMX Technology.*= true' /tmp/out/cpuid-one-cpu.txt || true
  # Helps with context switching.
  egrep '  FXSAVE/FXRSTOR .*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  SSE extensions.*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  SSE2 extensions.*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  hyper-threading / multi-core supported .*= true' /tmp/out/cpuid-one-cpu.txt || true

  #   feature information (1/ecx):
  egrep '  PNI/SSE3: Prescott New Instructions.*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  PCLMULDQ instruction.*= true' /tmp/out/cpuid-one-cpu.txt || true
  # Faster locking / synchronization.
  egrep '  MONITOR/MWAIT .*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  VMX: virtual machine extensions .*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  SSSE3 extensions.*= true' /tmp/out/cpuid-one-cpu.txt || true
  # ?
  egrep '  context ID: adaptive or shared L1 data .*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  FMA instruction.*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  CMPXCHG16B instruction .*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  direct cache access .*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  SSE4.1 extensions.*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  SSE4.2 extensions.*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  MOVBE instruction .*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  POPCNT instruction.*= true' /tmp/out/cpuid-one-cpu.txt || true
  #egrep '  AES instruction .*= true' /tmp/out/cpuid-one-cpu.txt || true
  # Helps with context switching.
  egrep '  XSAVE/XSTOR states .*= true' /tmp/out/cpuid-one-cpu.txt || true
  # Helps with context switching.
  egrep '  OS-enabled XSAVE/XSTOR .*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  AVX: advanced vector extensions.*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  F16C half-precision convert instruction.*= true' /tmp/out/cpuid-one-cpu.txt || true

  #   extended feature flags (7)
  egrep '  BMI instruction.*= true' /tmp/out/cpuid-one-cpu.txt || true
  # Faster locking / synchronization.
  egrep '  HLE hardware lock elision.*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  AVX2: advanced vector extensions 2.*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  FDP_EXCPTN_ONLY .*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  BMI2 instructions.*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  enhanced REP MOVSB/STOSB.*= true' /tmp/out/cpuid-one-cpu.txt || true
  # Invalidate Process-Context Identifier. Helps with context switching.
  egrep '  INVPCID instruction .*= true' /tmp/out/cpuid-one-cpu.txt || true
  # Faster locking / synchronization.
  egrep '  RTM: restricted transactional memory.*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  deprecated FPU CS/DS .*= true' /tmp/out/cpuid-one-cpu.txt || true
  # LLC isolation
  egrep '  PQE: platform quality of service enforce .*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  AVX512F: AVX-512 foundation instructions.*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  AVX512DQ: double & quadword instructions.*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  ADX instructions.*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  AVX512IFMA: fused multiply add.*= true' /tmp/out/cpuid-one-cpu.txt || true
  # These two are mostly for NVDIMM, but can be used for other purposes too.
  egrep '  CLFLUSHOPT instruction .*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  CLWB instruction .*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  AVX512PF: prefetch instructions.*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  AVX512ER: exponent & reciprocal instrs.*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  AVX512CD: conflict detection instrs.*= true' /tmp/out/cpuid-one-cpu.txt || true
  #egrep '  SHA instructions.*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  AVX512BW: byte & word instructions.*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  AVX512VL: vector length.*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  PREFETCHWT1.*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  AVX512VBMI: vector byte manipulation.*= true' /tmp/out/cpuid-one-cpu.txt || true
  # Only on Xeon Phi
  egrep '  AVX512_4VNNIW: neural network instrs.*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  AVX512_4FMAPS: multiply acc single prec.*= true' /tmp/out/cpuid-one-cpu.txt || true

  #   extended feature flags (0x80000001/edx):
  # not performance critical.
  egrep '  no-execute page protection .*= true' /tmp/out/cpuid-one-cpu.txt || true
  # Ancient stuff.
  egrep '  AMD multimedia instruction extensions .*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  3DNow! instruction extensions .*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  3DNow! instructions .*= true' /tmp/out/cpuid-one-cpu.txt || true

  #   AMD feature flags (0x80000001/ecx):
  # ?
  egrep '  LAHF/SAHF supported in 64-bit mode .*= true' /tmp/out/cpuid-one-cpu.txt || true
  # ?
  egrep '  CMP Legacy .*= true' /tmp/out/cpuid-one-cpu.txt || true
  # ?
  egrep '  AltMovCr8 .*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  LZCNT advanced bit manipulation .*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  SSE4A support .*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  misaligned SSE mode .*= true' /tmp/out/cpuid-one-cpu.txt || true
  # Ancient stuff. But still.
  egrep '  3DNow! PREFETCH/PREFETCHW instructions .*= true' /tmp/out/cpuid-one-cpu.txt || true
  # ?
  egrep '  OS visible workaround .*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  XOP support .*= true' /tmp/out/cpuid-one-cpu.txt || true
  # ?
  egrep '  SKINIT/STGI support .*= true' /tmp/out/cpuid-one-cpu.txt || true
  egrep '  4-operand FMA instruction .*= true' /tmp/out/cpuid-one-cpu.txt || true
  # ?
  egrep '  NodeId MSR C001100C .*= true' /tmp/out/cpuid-one-cpu.txt || true
  # ?
  egrep '  TBM support .*= true' /tmp/out/cpuid-one-cpu.txt || true
  # ?
  egrep '  topology extensions .*= true' /tmp/out/cpuid-one-cpu.txt || true

  echo $(d) 'cpuid features end'
  echo

  echo $(d) 'CPU frequencies from /proc/cpuinfo:'
  egrep '^cpu MHz' /tmp/out/proc-cpuinfo.txt || echo $(d) 'No CPU frequency info available in /proc/cpuinfo' || true

  echo $(d) 'Summary of CPU frequencies from /proc/cpuinfo:'
  egrep '^cpu MHz' /tmp/out/proc-cpuinfo.txt | awk '{print $4 " MHz";}' | sed -r -e 's/^/cpus with frequency: /' | sort | uniq -c || true

  /usr/bin/cpufreq-info --freq > /tmp/out/cpufreq-info-freq.txt || true
  /usr/bin/cpufreq-info --hwlimits > /tmp/out/cpufreq-info-hwlimits.txt || true
  /usr/bin/cpufreq-info --driver > /tmp/out/cpufreq-info-driver.txt || true
  /usr/bin/cpufreq-info --governors > /tmp/out/cpufreq-info-governors.txt || true
  /usr/bin/cpufreq-info --policy > /tmp/out/cpufreq-info-policy.txt || true
  echo $(d) 'CPU#0 frequency (kHz) from cpufreq-info:' $(/usr/bin/cpufreq-info --freq || echo 'No CPU frequency sensing using cpufreq-info available.')
  echo $(d) 'CPU#0 frequency (kHz) min and max from cpufreq-info:' $(/usr/bin/cpufreq-info --hwlimits || echo 'No CPU frequency ranges using cpufreq-info available.')
  echo $(d) 'CPU#0 driver in use from cpufreq-info:' $(cat /tmp/out/cpufreq-info-driver.txt)
  echo $(d) 'CPU#0 frequency policy in use from cpufreq-info:' $(cat /tmp/out/cpufreq-info-policy.txt)
  # TODO(baryluk): This doesn't work correctly.
  # grep -H . /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /tmp/cpufreq_scalling_governor.txt 2>/dev/null
  echo $(d) 'CPU frequency governors in use from sysfs:' $(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null | sort | uniq || echo 'No CPU frequency governor system available in sysfs.' || true)

  if [ "${ALLOW_ONDEMAND}" = "0" ]; then
    if egrep 'ondemand|conservative|powersave' /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null >/dev/null; then
       echo
       echo $(d) 'Detected "ondemand", "conservative" or "powersave" CPU frequncy governor on some or all CPUs!'
       echo $(d) 'You should change to "performance" CPU frequency governor instead for the best results.'
       echo $(d) 'To enable "performance" CPU frequency governor on all CPUs, try following command:'
       echo
       echo $(d) 'echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null'
       echo
       echo $(d) 'Alternatively, rerun benchmark with -e BENCHMARK_ONDEMAND=1 after "docker run".'
       echo
       exit 1
    fi
  else
      echo 1 > /tmp/out/allow_ondemand.txt
      echo $(d) 'Ignoring CPU frequency governor checks (ondemand, conservative or powersave is fine as requested).'
      echo
  fi

  /usr/bin/cpufreq-info > /tmp/out/cpufreq-info.txt
  echo $(d) 'Summary of CPU frequencies from cpufreq-info:'
  egrep 'current CPU frequency is' /tmp/out/cpufreq-info.txt | sed 's/^/cpus with: /' | sort  | uniq -c || echo $(d) 'Missing CPU frequency from cpufreq-info.' || true
  echo $(d) 'Summary of CPU governors from cpufreq-info:'
  egrep 'The governor ' /tmp/out/cpufreq-info.txt | sed 's/^/cpus with: /' | sort  | uniq -c || echo $(d) 'Missing CPU frequency governor from cpufreq-info.' || true
  echo

  echo $(d) 'Machine NUMA architecture topology:'
  /usr/bin/hwloc-ls --output-format console > /tmp/out/hwloc-ls-console-full.txt || true
  /usr/bin/hwloc-ls --output-format console --whole-io > /tmp/out/hwloc-ls-console-whole-io.txt || true
  /usr/bin/hwloc-ls --output-format xml --whole-io > /tmp/out/hwloc-ls-xml-whole-io.xml || true
  /usr/bin/hwloc-ls --output-format synthetic --no-io > /tmp/out/hwloc-ls-synthetic-no-io.txt || true
  /usr/bin/hwloc-ls --output-format svg > /tmp/out/hwloc-ls-svg-full.svg || true
  /usr/bin/hwloc-ls -p --no-io --no-bridges --no-useless-caches | tee /tmp/out/hwloc-ls-custom.txt || true
  #/usr/bin/lstopo-no-graphics
  echo
  echo $(d) 'Machine hardware summary:'
  /usr/bin/hwloc-info -p | tee /tmp/out/hwloc-info-p.txt || true # --whole-system
  /usr/bin/hwloc-info --whole-system > /tmp/out/hwloc-info-whole-system.txt
  /usr/bin/hwloc-info --whole-system --support > /tmp/out/hwloc-info-whole-system-support.txt
  echo
  echo $(d) 'Number of online processors:'
  /usr/bin/getconf _NPROCESSORS_ONLN | tee /tmp/out/getconf-processors.txt || true
  echo
  echo $(d) 'CPU cache runtime information:'
  /usr/bin/getconf -a | egrep 'LEVEL.+CACHE' | tee /tmp/out/getconf-caches.txt || echo $(d) 'CPU caches information not available in getconf.' || true
  echo
  echo $(d) 'CPU affinity set in kernel scheduler by docker or user:'
  /usr/bin/taskset --cpu-list -p 1 | tee /tmp/out/taskset-cpu-list.txt || true
  echo
  echo $(d) 'Current NUMA policy settings:'
  /usr/bin/numactl --show | tee /tmp/out/numactl-show.txt || true
  /usr/bin/numactl --hardware | tee /tmp/out/numactl-hardware.txt || true
  echo
  echo $(d) 'CPU summary:'
  /usr/bin/lscpu | tee /tmp/out/lscpu.txt || true
  echo
  echo $(d) 'Extended CPU summary for all online and offline individual cores, CPUs and sockets:'
  #/usr/bin/lscpu --all --extended | tee /tmp/out/lscpu-all-extended.txt || true
  /usr/bin/lscpu --all --extended=BOOK,NODE,SOCKET,CPU,CORE,CACHE,MINMHZ,MAXMHZ,ONLINE,POLARIZATION,CONFIGURED | tee /tmp/out/lscpu-all-extended-custom.txt || true
  # Version of lscpu 2.28.2 in Ubuntu doesn support DRAWER (highest level above the BOOK).
  # util-linux 2.29.1 is required.
  echo
  echo $(d) 'Number of processes running (useless under own PID namespace in docker):'
  cat /proc/stat | egrep '^procs_running ' || true
  echo

  echo $(d) 'Memory use in Megibytes:'
  /usr/bin/free -m | tee /tmp/out/free-m.txt
  echo

  # TODO(baryluk): Docker version
  echo $(d) 'Main library and compiler versions:'
  (dpkg -l libc6 'libboost-thread*' 'libstdc*' 'llvm*' 'libllvm*' 'clang*' 'gcc*') | egrep '^ii ' | tee /tmp/out/dpkg-mainlibs.txt
  echo

  # Requires root or access to /dev/mem. Or not that useful.
  #echo 'DMI table content:'
  #/usr/sbin/dmidecode --quiet | tee /tmp/out/dmidecode.txt || true
  #
  #echo 'BIOS information:'
  #/usr/sbin/biosdecode | /tmp/out/biosdecode.txt || true
  #
  #/usr/bin/lspci -t -v -nn | tee /tmp/out/lspci-tvnn.txt || true

  # TODO(baryluk): EDAC / RAS / ECC memory stuff.
  # TODO(baryluk): Memory frequency, dimms, ranks, channels info.

  # TODO(baryluk): Performance counters info maybe?

  cat /proc/stat > /tmp/out/proc-stat.txt
  cat /proc/meminfo > /tmp/out/proc-meminfo.txt
  cat /proc/interrupts > /tmp/out/proc-interrupts.txt
  cat /proc/vmstat > /tmp/out/proc-vmstat.txt
  cat /proc/execdomains > /tmp/out/proc-execdomains.txt || true
  cat /proc/zoneinfo > /tmp/out/proc-zoneinfo.txt
  cat /proc/uptime > /tmp/out/proc-uptime.txt
  cat /proc/loadavg > /tmp/out/proc-loadavg.txt
  cat /proc/swaps > /tmp/out/proc-swaps.txt
  cat /proc/cmdline > /tmp/out/proc-cmdline.txt
  cat /proc/buddyinfo > /tmp/out/proc-buddyinfo.txt

  # /proc/iomem
  # /proc/ioports
  # /proc/filesystems
  # /proc/schedstat

fi # verbose

echo


# Actually compile

cd /root
silent || echo $(d) "Unziping povray-3.7-stable.zip..."
/usr/bin/unzip -q povray-3.7-stable.zip
silent || echo $(d) "done"
silent || echo

silent || echo $(d) "Preparing and cleaning up code base..."
cd povray-3.7-stable
mv libraries libraries.unused
cd unix/
(cd config/ && rm config.guess config.sub depcomp install-sh missing)
/bin/sed -i -e 's,automake --warnings=all ###--ignore-deps,automake --warnings=all --add-missing ###--ignore-deps,' ./prebuild.sh
silent || echo $(d) "done"
silent || echo

silent || echo $(d) "Prebuilding..."
if ! ./prebuild.sh >prebuild_log1.txt 2>&1; then
  echo $(d) "prebuild failed" >&2
  echo $(d) "prebuild output" >&2
  cat prebuild_log1.txt
  exit 1
fi
silent || echo $(d) "done"
silent || echo

cd ..

CC="gcc-${GCC_VERSION}"
CXX="g++-${GCC_VERSION}"
CPP="cpp-${GCC_VERSION}"
CFLAGS="-march=native -g0 -Ofast -pthread -fno-stack-protector -U_FORTIFY_SOURCE ${OPTS}"
CXXFLAGS="-std=c++03 -march=native -g0 -Ofast -fomit-frame-pointer -pthread -fno-stack-protector -U_FORTIFY_SOURCE ${OPTS}"
LDFLAGS=
# use binutils provided linker and other tools
LD=ld
AS=as
#GAS=as
AR=ar
RANLIB=ranlib
NM=nm
OBJDUMP=objdump

#"-floop-nest-optimize -floop-parallelize-all -ftree-vectorize -fvariable-expansion-in-unroller"

if [ "${ENABLE_CLANG}" != "0" ]; then
  echo 1 > /tmp/out/clang.txt
  CC=clang-${CLANG_VERSION}
  CXX=clang++-${CLANG_VERSION}
  CPP=clang-cpp-${CLANG_VERSION} # Only in >=4.0
  if verbose; then
    echo $(d) 'clang version:' $(${CC} --version | grep '^clang version' | tee /tmp/out/clang-version.txt)
    echo $(d) 'clang++ version:' $(${CXX} --version | grep '^clang version' | tee /tmp/out/clang++-version.txt)
    echo
  fi # verbose

  #ln -sf /usr/lib/llvm-${CLANG_VERSION}/lib/LLVMgold.so /usr/lib/LLVMgold.so
  #echo /usr/lib/llvm-${CLANG_VERSION}/lib >> /etc/ld.so.conf
  #ldconfig

  #CFLAGS="${CFLAGS} -B/usr/lib/gold-ld"
  #CXXFLAGS="${CFLAGS} -B/usr/lib/gold-ld"

  if [ "${ENABLE_LTO}" = "1" ]; then
    echo 1 > /tmp/out/lto.txt
    if ! supersilent; then
      echo $(d) 'LTO (Link Time Optimization) options enabled.'
      echo
      echo $(d) 'LTO (Link Time Optimization) enabled for clang. Using gold linker.'
      echo
    fi
    CFLAGS="${CFLAGS} -flto"
    CXXFLAGS="${CXXFLAGS} -flto"
    LD=ld.gold
    LDFLAGS="-fuse-linker-plugin -Wl,-O2 -Wl,--as-needed"
    # TODO(baryluk): Use lld-link-${CLANG_VERSION} / ld.lld-${CLANG_VERSION} from clang 4.0
    AS="llvm-as-${CLANG_VERSION}"
    AR="llvm-ar-${CLANG_VERSION}"
    NM="llvm-nm-${CLANG_VERSION}"
    RANLIB="llvm-ranlib-${CLANG_VERSION}"
    OBJDUMP="llvm-objdump-${CLANG_VERSION}"
  fi
else
  echo 1 > /tmp/out/gcc.txt
  if verbose; then
    echo $(d) 'GCC version:' $(${CC} -v 2>&1 | grep '^gcc version')
    echo $(d) 'G++ version:' $(${CXX} -v 2>&1 | grep '^gcc version')
    echo
  fi # verbose

  if [ "${ENABLE_LTO}" != "0" ]; then
    echo 1 > /tmp/out/lto.txt
    supersilent || echo $(d) 'LTO (Link Time Optimization) options enabled.'
    # -flto=6 means to use 6 threads / processes to do work.
    # but lto-partition=none basically disables that and do optimization having full view of entire program.
    CFLAGS="${CFLAGS} -fno-fat-lto-objects -flto=6 -flto-partition=none"
    CXXFLAGS="${CXXFLAGS} -fno-fat-lto-objects -flto=6 -flto-partition=none"
    LDFLAGS="-fuse-linker-plugin"
    AR="gcc-ar-${GCC_VERSION}"
    RANLIB="gcc-ranlib-${GCC_VERSION}"
    NM="gcc-nm-${GCC_VERSION}"
  fi
fi  # not CLANG

if verbose; then
  echo $(d) "${CC} detected architecture and microarchitecture:"
  ${CC} -march=native -Q --help=target | grep march || true
  echo

  if [ "${ENABLE_CLANG}" != "0" ]; then
    echo $(d) "${CC} autodetection CPU features, instructions sets and tuning parameters:"
    ${CC} '-###' -E - -march=native 2>&1 || true
    echo
  else
    echo $(d) "${CC} autodetection CPU features, instructions sets and tuning parameters:"
    echo
    #${CC} -march=native -E -v - </dev/null 2>&1 | grep cc1
    #echo | ${CC} '-###' -E - -march=native 2>&1 | grep cc1
    echo $(d) 'Enables:'
    #${CC} '-###' -E - -march=native 2>&1 | sed -r -e '/cc1/!d;s/(")|(^.* - )//g'  # a bit cleaner.
    #${CC} '-###' -E - -march=native 2>&1 | sed -r -e '/cc1/!d;s/(")|(^.* - )|( -mno-[^\ ]+)//g'  # Without -mno-* flags.
    ${CC} '-###' -E - -march=native 2>&1 | sed -r -e '/cc1/!d;s/(")|(^.* - )|//g' | sed -r -e 's/ -/\n-/g' | egrep -v '^-mno-[^\ ]+' || true # line by line.

    echo
    echo $(d) 'Disabled:'
    ${CC} '-###' -E - -march=native 2>&1 | sed -r -e '/cc1/!d;s/(")|(^.* - )|//g' | sed -r -e 's/ -/\n-/g' | egrep '^-mno-[^\ ]+' || true # line by line.
    echo
    echo

    #echo | ${CC} -dM -E - -march=native  # arch specific defines.
    #${CC} -march=native -Q --help=target  # a lot of flags and params. including disabled ones for each platform.
  fi # not CLANG
fi  # verbose

LIBS="-ltiff -ljpeg -lpng -lz -lrt -lm -lboost_thread -lboost_system"
COMPILED_BY="Witold Baryluk <witold.baryluk+povray-docker@gmail.com>"
TOOLS="CC=${CC} CXX=${CXX} CPP=${CPP} LD=${LD} AS=${AS} AR=${AR} RANLIB=${RANLIB} NM=${NM} OBJDUMP=${OBJDUMP}"

ALL_CPUS=$(/usr/bin/getconf _NPROCESSORS_ONLN)
AVAILABLE_CPUS=$(/usr/bin/numactl --show | grep physcpubind | wc -w)
AVAILABLE_CPUS=$((AVAILABLE_CPUS - 1))
if [ "${BUILD_JOBS}" = "0" ]; then
  BUILD_JOBS="${ALL_CPUS}"
fi

configure () {
  supersilent || echo $(d) "Configuring..."
  supersilent || echo $(d) "nice ./configure \\
  	--with-boost-thread=boost_thread \\
  	${TOOLS} \\
  	CFLAGS=\"${CFLAGS}\" \\
  	CXXFLAGS=\"${CXXFLAGS}\" \\
  	LDFLAGS=\"${LDFLAGS}\" \\
  	LIBS=\"${LIBS}\" \\
  	COMPILED_BY=\"${COMPILED_BY}\""

  if ! nice ./configure \
  	--with-boost-thread=boost_thread \
  	${TOOLS} \
  	CFLAGS="${CFLAGS}" \
  	CXXFLAGS="${CXXFLAGS}" \
  	LDFLAGS="${LDFLAGS}" \
  	LIBS="${LIBS}" \
  	COMPILED_BY="${COMPILED_BY}" >configure_log1.txt 2>&1; then
    echo $(d) "configure failed" >&2
    echo $(d) "configure output" >&2
    cat configure_log1.txt
    echo
    echo
    echo $(d) 'Showing config.log'
    echo
    cat config.log
    exit 1
  fi
  supersilent || echo $(d) "done"
  supersilent || echo
}

build () {
  supersilent || echo $(d) "Building (can take few minutes) using ${BUILD_JOBS} jobs (${AVAILABLE_CPUS} cores available)..."
  supersilent || echo $(d) "nice make -j${BUILD_JOBS} ${TOOLS}"
  if ! nice make "-j${BUILD_JOBS}" ${TOOLS} >make_log1.txt 2>&1; then
    echo $(d) "make failed" >&2
    echo $(d) "make output:" >&2
    cat make_log1.txt
    exit 1
  fi
  supersilent || echo $(d) 'done'
  supersilent || echo $(d) 'Do not under any cirumstances use build time for comparing different or even same system!'
  supersilent || echo
}

if [ "${ENABLE_PGO}" != "0" ]; then
  echo 1 > /tmp/out/pgo.txt
  supersilent || echo $(d) 'FDO/PGO (Feadback driven / Profile guided optimization) enabled.'
  supersilent || echo

  cd ..
  cp -r povray-3.7-stable povray-3.7-stable.copy
  cd povray-3.7-stable

  supersilent || echo $(d) 'Configuring intrumented binary...'

  mkdir -p /tmp/pgo

  if [ "${ENABLE_CLANG}" != "0" ]; then 
    FDO_PASS1_COPTS="-O2 -fprofile-instr-generate"
    export LLVM_PROFILE_FILE="/tmp/pgo/code-povray-%m.profraw"  # %p pid, %m ids, %h hostname.
  else
    FDO_PASS1_COPTS="-O2 -fno-omit-frame-pointer -fprofile-generate=/tmp/pgo/povray-profile1"  # -g
  fi

  if ! supersilent; then
    set -x
  fi
  if ! nice ./configure \
  	--with-boost-thread=boost_thread \
  	--disable-optimiz --disable-strip \
  	${TOOLS} \
  	CFLAGS="${CFLAGS} ${FDO_PASS1_COPTS}" \
  	CXXFLAGS="${CXXFLAGS} ${FDO_PASS1_COPTS}" \
  	LDFLAGS="${LDFLAGS}" \
  	LIBS="${LIBS}" \
  	COMPILED_BY="${COMPILED_BY}" >configure_log0.txt 2>&1; then
    echo $(d) "configure failed" >&2
    echo $(d) "configure output" >&2
    cat configure_log0.txt
    exit 1
  fi
  set +x
  supersilent || echo $(d) 'done'
  supersilent || echo
  #configure

  build
  # TODO(baryluk): Measure time of build.

  file ./unix/povray > /tmp/out/file-unix-povray.pgo.txt
  ldd ./unix/povray > /tmp/out/ldd-unix-povray.pgo.txt
  ls -l ./unix/povray > /tmp/out/ls-l-unix-povray.pgo.txt

  supersilent || echo $(d) 'Executing multi-threaded benchmark once to gather feedback (should take less than 20 minutes, but can take more than hour on older systems)...'
  #rm -vf /tmp/pgo/povray-profile1
  echo | nice /usr/bin/time ./unix/povray -benchmark | hole  # FIXME(baryluk): Disable buffering
  # TODO(baryluk): Execute with smaller image, and smaller number of threads to reduce cache bouncing?
  # 2>&1 | egrep 'Photon Time|Trace Time|elapsed'
  # TODO(baryluk): Measure time of profiling run.
  supersilent || echo $(d) 'done'
  supersilent || echo

  if [ "${ENABLE_CLANG}" != "0" ]; then 
    if ! supersilent; then
      echo $(d) 'Profile files size:'
      ls -l /tmp/pgo/code-povray-*.profraw
      echo
    fi

    supersilent || echo $(d) 'Merging raw profile files for LLVM...'
    llvm-profdata-${CLANG_VERSION} merge -output=/tmp/pgo/code-merged.profdata /tmp/pgo/code-povray-*.profraw
    supersilent || echo

    if ! supersilent; then
      echo $(d) 'Merged profile for LLVM file size:'
      ls -l /tmp/pgo/code-merged.profdata
      echo
    fi

    # Other option is to use -fprofile-generate=/tmp/pgo/some-dir/, then -fprofile-use=/tmp/pgo/some-dir,
    # which should use %m and merging automatically and read profile file in second stage.
  else
    if ! supersilent; then
      echo $(d) 'Profile files size:'
      ls -l /tmp/pgo/povray-profile1
      echo
    fi
  fi

  supersilent || echo $(d) 'Cleaning source tree from previous build...'
  make clean >/dev/null
  supersilent || echo $(d) 'done'
  supersilent || echo

  cd ..
  rm -rf povray-3.7-stable
  mv povray-3.7-stable.copy povray-3.7-stable
  cd povray-3.7-stable

  supersilent || echo $(d) 'Modifying main compilation flags to use a profile...'
  if [ "${ENABLE_CLANG}" != "0" ]; then 
    FDO_PASS2_COPTS="-fprofile-instr-use=/tmp/pgo/code-merged.profdata"
  else
    FDO_PASS2_COPTS="-fprofile-use=/tmp/pgo/povray-profile1 -fomit-frame-pointer -Wno-coverage-mismatch -fprofile-correction"
  fi
  CFLAGS="${CFLAGS} ${FDO_PASS2_COPTS}"
  CXXFLAGS="${CXXFLAGS} ${FDO_PASS2_COPTS}"
  supersilent || echo $(d) 'done'
  supersilent || echo
fi  # fdo

echo "${CFLAGS}" > /tmp/out/main-full-cflags.txt
echo "${CXXFLAGS}" > /tmp/out/main-full-cxxflags.txt

configure

build

if verbose; then
  echo $(d) 'Binary details:'
  /usr/bin/file ./unix/povray | tee /tmp/out/file-unix-povray.txt
  echo
  echo $(d) 'Dynamic linking details:'
  /usr/bin/ldd ./unix/povray | tee /tmp/out/ldd-unix-povray.txt
  echo
  echo $(d) 'Size:'
  ls -l ./unix/povray | tee /tmp/out/ls-l-unix-povray.txt
  echo
fi # verbose

#echo $(d) 'Dropping file system caches...'
#sync
#echo 3 > /proc/sys/vm/drop_caches
#echo $(d) 'done'

if [ "${ENABLE_QUICK}" != "0" ]; then
  supersilent || echo $(d) 'Not waiting for system to settle down (1 minute loadavg < 1.0)...'
  supersilent || /usr/bin/uptime | tee /tmp/out/uptime.txt
  supersilent || echo
  supersilent || echo $(d) 'Checking vmstat quickly...'
  supersilent || /usr/bin/vmstat 1 2| tee /tmp/out/vmstat.txt
  supersilent || echo
else
  #echo $(d) 'Waiting for system to settle down (1 minute loadavg < 1.0)...'
  #while /usr/bin/uptime | egrep 'load average: +[1-9][0-9]*\.[0-9][0-9], +[0-9]+\.[0-9]+, +[0-9]+\.[0-9]+$'; do
  #  sleep 10
  #  echo $(d) 'Still waiting for system to settle down (1 minute loadavg < 1.0)...'
  #done
  #/usr/bin/uptime | tee /tmp/out/uptime.txt
  #echo

  supersilent || echo $(d) 'Waiting for system to settle down (1 minute system load average to fall below 0.15)...'
  supersilent || echo $(d) 'This can take about 3 minutes. Waiting can be canceled with single Ctrl-C,'
  supersilent || echo $(d) 'or by passing -e BENCHMARK_QUICK=1 option to docker run or -Q to benchmark.'
  while [ $(/usr/bin/uptime | sed -r -e 's/.*load average: //' | awk -F ',' '{ print $1 * 100; }') -gt 15 ]; do
    sleep 5
    supersilent || echo $(d) 'Still waiting for system to settle down (1 minute system load average to fall below 0.15)...'
    supersilent || /usr/bin/uptime
    sleep 15
  done
  supersilent || /usr/bin/uptime | tee /tmp/out/uptime.txt
  supersilent || echo

  supersilent || echo $(d) 'Waiting for only one user to be be logged in (useless when running under docker)...'
  while [ $(/usr/bin/uptime | sed -r -e 's/.+, *([0-9]+) users?,.+/\1/') -gt 2 ]; do  # ' # to make my editor happy
    supersilent || /usr/bin/uptime
    sleep 5
    supersilent || echo $(d) 'Still waiting for only one user to be be logged in...'
  done
  supersilent || /usr/bin/uptime | tee /tmp/out/uptime.txt
  supersilent || echo

#  while true; do
#    FORKS1=`vmstat -f | awk '{print $1;}'`
#    sleep 2
#    FORKS2=`vmstat -f | awk '{print $1;}'`
#    NEW_FORKS=$((FORKS2-FORKS2))
#    if [ "${NEW_FORKS}" != "4" ]; then
#      echo $(d) 'System still creating forks (new threads), waiting...'
#    fi
#  done

  if verbose; then
    echo $(d) 'Checking vmstat...'
    /usr/bin/vmstat 1 6 | tee /tmp/out/vmstat.txt
    echo
  fi # verbose
fi # not quick


temps () {
  if verbose; then
    echo $(d) 'CPU core temperatures: '
    /usr/bin/sensors | egrep '^(Package|Core) .+°C .*' || grep . /sys/class/thermal/thermal_zone*/temp 2>/dev/null || echo 'No CPU temperature sensing available.' || true
    # cat /sys/class/thermal/thermal_zone*/{temp,type}
    echo
  fi
}

tempsloop () {
  while true; do
    if [ -f /tmp/tempsloop.stop ]; then
      rm -f /tmp/tempsloop.stop
      exit 0
    fi
    if [ "${ENABLE_TEMPS}" != "0" ]; then
      temps
    fi
    sleep 2
  done | tee /tmp/out/temps.txt
}

supersilent || echo $(d) 'Prefetching binary to file system cache...'
/usr/bin/time cat ./unix/povray >/dev/null >&1 | hole | tee /tmp/out/prefetching.txt
supersilent || echo $(d) 'done'

b1 () {
  # /usr/bin/ionice --class 1 --classdata 0  # real time class with priority 0
  # /usr/bin/schedtool -n -20 -R -p 90 -e  # nice -20, SCHED_RR with priority 95
  echo $(d) 'Benchmark: povray-3.7/standard-benchmark-scene-512x512/all-threads' pass=$1/$2
  echo | /usr/bin/time ./unix/povray -benchmark 2>&1 | egrep 'Photon Time|Trace Time|elapsed'
# TODO(baryluk): Detect failure / crashes of povray.
# TODO(baryluk): Convert times to pixels per second instead. And pixels per second per core.
  echo $(d) 'done'
}

b2 () {
  echo $(d) 'Benchmark: povray-3.7/standard-benchmark-scene-512x512/one-thread' pass=$1/$2
  echo | /usr/bin/time ./unix/povray +WT1 -benchmark 2>&1 | egrep 'Photon Time|Trace Time|elapsed'
  echo $(d) 'done'
}

HALF_CPUS=$((ALL_CPUS / 2))
b3 () {
  echo $(d) 'Benchmark: povray-3.7/standard-benchmark-scene-512x512/half-threads' pass=$1/$2
  echo | /usr/bin/time ./unix/povray "+WT${HALF_CPUS}" -benchmark 2>&1 | egrep 'Photon Time|Trace Time|elapsed'
  echo $(d) 'done'
}


if ! supersilent; then
  echo
  echo $(d) "Going to run ${MT_PASSES} multithreaded passes and ${ST_PASSES} single threaded passes."
  echo $(d) 'It is recommended to take fastest results for comparing different systems.'
  echo $(d) 'Do not use averages!'
  echo
fi

echo
echo $(d) "Starting benchmarks with all cores (${MT_PASSES} times; less than 2 minutes each on modern system)..."
tempsloop &
TEMPSLOOP_PID=$!

PASSES=${MT_PASSES}
for PASS in `seq 1 ${PASSES}`; do
  b1 ${PASS} ${PASSES}
  temps
done

supersilent || echo $(d) 'All MT passes done'
supersilent || echo

HT_PASSES=${MT_PASSES}

echo
echo $(d) "Starting benchmarks with half of the cores (${HT_PASSES} times; less than 2 minutes each on modern system)..."
tempsloop &
TEMPSLOOP_PID=$!

PASSES=${HT_PASSES}
for PASS in `seq 1 ${PASSES}`; do
  b3 ${PASS} ${PASSES}
  temps
done

supersilent || echo $(d) 'All HT passes done'
supersilent || echo


if [ "${ENABLE_MT_ONLY}" = "0" ]; then
  echo $(d) "Starting benchmarks with 1 thread (${ST_PASSES} times; can take 20 minutes each on older systems)..."

  PASSES=${ST_PASSES}
  for PASS in `seq 1 ${PASSES}`; do
    b2 ${PASS} ${PASSES}
    temps
  done

  supersilent || echo $(d) 'All ST passes done'
  supersilent || echo
fi

touch /tmp/tempsloop.stop
sleep 3
kill -9 "${TEMPSLOOP_PID}" 2>/dev/null || true

# TODO(baryluk): How to run linux-perf under docker?
# TODO(baryluk): How to detect version of docker from inside docker?
# TODO(baryluk): How to detect virtualization (Xen, KVM, etc)? dmesg?

echo $(d) 'Benchmarks finished.' | tee /tmp/out/timestamp-end.txt
echo
