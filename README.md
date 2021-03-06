# povray-docker

https://hub.docker.com/r/baryluk/povray-bench/

# Description

PovRay (Persistence of Vision) is a open source program for rendering
photo realistic images using ray-tracing, photon mapping and radiosity
techniques.

PovRay allows defining objects using built in C-like language, that
provides various mathematical objects, transforms both in 2D and 3D
spaces. This allows very complex objects and texture to be created in
procedural fashion or using additional language facilities and external
scripts. Shapes and textures can also be imported from common mesh, shape
and image formats.

PovRay is very CPU intensive, and is able to utilize multiple cores very
well, by computing different group of final pixels on different cores in
independent fashion.

This docker image, automatically builds povray binary and measures time
to execute standard benchmark scene, as well report various details of
the machine it is running on.

Benchmark utilizes modern compilers and targets machine specific
optimizations, to give the best results possible.

It's main purpose is benchmarking CPU pipelines, FPU and ALU units,
control flow units, branch prediction, prefetching, speculative
execution, instruction and data caches, memory subsystem, kernel task
scheduling, user and kernel space synchronization primitives, and
compiler optimizations for different micro architecture, vectorization
and other compiler techniques.

# Running

    docker run --rm -it baryluk/povray-bench

and just wait and observe as benchmark is doing its things.

Main metrics for comparisson is Trace Time row, that lists in seconds
time it took to finish main stage of raytracing in POV-Ray.


# Verbose mode

For a lot of additional CPU, machine and compiler related diagnostic use:

    docker run --rm -it -e BENCHMARK_VERBOSE=1 baryluk/povray-bench

It will still hide configuration and compilation stage, and is a good way to
learn about your system and share it with others.

Instead of usine docker run option to pass environment variable using
`-e BENCHMARK_VERBOSE=1`, you can use option `-v` to the same effect.

# Compiler settings

By default GCC compiler will be used. You can use `-c` option benchmark option,
or `-e BENCHMARK_CLANG=1` docker run option, to switch clang compiler.

In current image GCC 6.3.0 and clang 4.0 are available.

Default options used by benchmark for both GCC and clang are as follow (beyond
that provided by povray configure and make scripts explicitly):

    -std=c++03 -march=native -g0 -Ofast -fomit-frame-pointer -pthread
    -fno-stack-protector -U_FORTIFY_SOURCE

During PGO first stage build `-O2` and compiler specific options will be
appended.

Additional options can be passed using `-e BENCHMARK_COPTS=...` option to docker
run. They will be passed along to configure and build scripts at the end of
existing options, but before any PGO-specific options.

For full information about used options run benchmark in verbose mode.

# Options

You can pass various options to the benchmark via docker environment.
Similar to `-e BENCHMARK_VERBOSE=1` as shown above.

It is also possible to pass options directly to the benchmark script, but some
options are not available this way right now.

Fully list of options can be seen by passing `-e BENCHMARK_HELP=1` to docker run
or using -h option, which show currently these options

```text
$ docker run --rm -it baryluk/povray-bench -h
  -e BENCHMARK_LTO=1        Use LTO (Link time optimizations) when compiling and linking. Disabled by default.
  -e BENCHMARK_PGO=1        Use PGO/FDO (Profile Guided / Feedback-Driven optimization). Can take up to hour longer. Disabled by default.
  -e BENCHMARK_CLANG=1      Use clang-4.0 compiler instead of gcc-6 compiler. Disabled by default.
  -e BENCHMARK_COPTS=...    Pass additional custom options to compiler flags. Empty by default.
  -e BENCHMARK_BUILD_JOBS=1 Use specific numebr of processes for build. 0 - use all cores. 0 by default.
  -e BENCHMARK_VERBOSE=1    Show detailed machine and build information. Disabled by default.
  -e BENCHMARK_BUILD=1      Show all build outputs. Very verbose! Disabled by default.
  -e BENCHMARK_QUIET=1      Be very quiet. Show only benchmark timings, nothing else. Disabled by default.
  -e BENCHMARK_QUICK=1      Do not wait for system load to settle. Not recommended for benchmarking! Disabled by default.
  -e BENCHMARK_MT_ONLY=1    Do not run single threaded benchmarks. Disabled by default.
  -e BENCHMARK_MT_PASSES=5  Set number of multi threaded passes. Default 5.
  -e BENCHMARK_ST_PASSES=2  Set number of single threaded passes. Default 2.
  -e BENCHMARK_TEMPS=1      Show temperatures (if available) every 2 second during benchmark. Disabled by default.
  -e BENCHMARK_UPLOAD=1     On success, upload full benchmark output and results to the author and https://benchmarks.functor.xyz/ site. Will set BENCHMARK_VERBOSE=1, BENCHMARK_QUIET=0 and BENCHMARK_QUICK=0 automatically unless with conflict with other flags. Disabled by default.
  -e BENCHMARK_SHELL=1      Drop to shell in the container on any error. Disabled by default.
  -e BENCHMARK_HELP=1       Show all available options and exit.
  -e BENCHMARK_TIMESTAMPS=0 Disable timestamps. Enabled by default.
  -e BENCHMARK_ONDEMAND=1   Allow "ondemand" cpu frequency governor. Disabled by default.

benchmark.sh options available and equivalent to above options:
  -l    Use LTO.
  -p    Use PGO/FDO.
  -c    Use clang.
  -j32  Use 32 processes for build. 0 - use all cores.
  -v    Be verbose.
  -b    Show build output.
  -q    Be quiet.
  -Q    Be quick.
  -f    Be quick.
  -m    Run multi threaded only.
  -M5   Run 5 multi threaded passes.
  -S2   Run 2 single threaded passes.
  -t    Show temps.
  -T    Show timestamps.
  -h    Show this help and exit.
```

# Features

 * Debian unstable based docker image.
 * GCC 6.3 / clang 4.0
 * Link Time Optimizations (LTO)
 * Profile Guided Optimizations (PGO)
 * Multi threaded and single threaded runs.
 * Verbose machine and system diagnostics.
 * CPU frequency information.
 * CPU governor information.
 * Temperature reporting.
 * Waiting for system to settle down after build or other activities.
 * Quiet mode.
 * Quick mode.
 * MT-only mode.
 * Specification of number of passes.
 * Preparation for upload mode via HTTPS.
 * Passing options via environment and flags (with exception of upload).
 * Help option.

# Known bugs

  * Upload doesnt work (need to write server side).
  * Upload detection doesn't detect flags.
  * When doing a profiling pass the output is printed even in quiet mode.
  * ST passes takes very long time.
  * Standard benchmark scene is not stressing memory subsystem too much.
  * Filtering cpuid features could be done better.
  * Should be rewritten into something more sane, and output of each program
    should be captured into separate file for upload and for easier parsing.
