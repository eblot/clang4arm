# Clang for embedded ARM v4/v5 targets

**clang4arm** aims at providing a toolchain for legacy ARM targets (ARMv4T,
ARMv5), without relying on the GCC compiler suite.

## Motivations

Clang current release (v3.3) offers limited support for these targets: although
it is possible to generate assembly code for these targets, GCC toolchain is 
still required for several reasons:

  * GCC front-end is required to dispatch assembly and link stages to the GNU as
    and GNU ld (from binutils),
  * libgcc is required to provide the required glue and missing features for the
    ARM target.

Moreover, the LLVM/clang community mostly targets nowadays, moderm ARM
architectures (ARMv7+), and focus on common OSes such as iOS and Android. 

Legacy ARM architectures and custom environments (OS-less, other RTOSes, ...)
are not the primary targets, and building toolchain for those can sometimes be
all but trivial.

This package is no magic: it only gathers the various LLVM and Clang 
components so that a fully-functional clang-based toolchain can be built in
one step.

It has been quite frustrating to desperatly look for the tiny missing pieces of 
information to build such a toolchain. I hope it may help other developers to 
get the clang toolchain for ARM without having to dig into mailing list
archives and clang build system files.

If you are looking for a clang toolchain for iOS or Android, you reached the
wrong place! See the official [clang](http://clang.llvm.org/get_started.html)
website that provides official toolchain packages.

## Requirements

  * Un*x host
  * GNU [binutils](http://www.gnu.org/software/binutils) for the target:
    * GNU as assembler
    * GNU ld linker
    * GNU ar archiver
  * GNU [make](http://www.gnu.org/software/make)
  * Host toolchain (based on clang or GCC)
  * [Python](http://www.python.org/) 2.7

## Supported hosts

This project has been successfully built on OS X 10.7.4 and Debian 7.
You mileage may vary.

Cygwin is fully untested.

## Supported targets

This project has been used to successfully build some OS-less projects 
including a Bootloader, and several applications based on the 
[eCos](ecos.sourceware.org) real-time kernel. Target CPUs were an ARM7TDMI SoC
and ARM926EJ-S. The [eCos](ecos.sourceware.org) kernel has also been built with
this toolchain.

## Limitations

  1. For now, only [AAPCS](http://infocenter.arm.com/help/topic/com.arm.doc.ihi0042e/IHI0042E_aapcs.pdf)
    has been tested: `arm-eabi` targets. The `arm-linux-gnueabi` Linux variant
    has not been tested.
  2. Thumb support is NOT available, as the LLVM compiler emits invalid 
    thumb1 opcodes for legacy ARM targets (ARMv4T, ARMv5).
  3. Limited C++ support: `libsupc++` is not build.

## Components

The **clang4arm** toolchain includes:

  * [LLVM](http://llvm.org) toolchain
  * [clang](http://clang.llvm.org) front-end
  * [newlib](http://sourceware.org/newlib) built for ARMv4t/ARMv5 targets, as
    the standard C libraries (libc, libm)
  * [compiler_rt](http://compiler-rt.llvm.org) built for ARMv4t/ARMv5 targets,
    as a replacement for libgcc
  * dedicated wrapper that acts as a replacement for the GCC front-end, see 
    [below][Gcc Wrapper] below for details

The current package is based on the official LLVM/clang v3.3 final release.

# Installation

## Grabbing the source

    git clone https://github.com/eblot/clang4arm
    cd clang4arm
    git submodule init
    git submodule update

## Building the binutils tool suite

Building the binutils tool suite is out-of-scope of this document, but can be
easily achieved with the following command sequence:

    tar xvf binutils binutils-2.23.2.tar.bz2
    mkdir build
    cd build
    ../binutils*/configure --target=arm-eabi --disable-werror --disable-debug
    make
    (sudo) make install

### Notes

  1. Do not forget to have a look at `configure --help` output to get more
    build and installation options to fit your need and your current
    environment.
  2. If you install the binutils within a custom destination directory, do not
    forget to add its sub-dir `bin` directory to your current `PATH`
  3. `--target` option value should match the `toolchain` string from
    `./build.sh -t toolchain` in the following installation sequence.
    Please note that **clang4arm** has not been tested with any other target
    *triplet* setting.

## Building the toolchain

If you have already installed a GCC toolchain for the same target, remove it
from your `PATH` or undefined behaviour may occur.  
In other words, `which arm-eabi-gcc` should return nothing.

Start up the build sequence:

    ./build.sh

Use `-h` to get option switches, including changing the default installation
path: `/usr/local/clang-3.3`.

Do not forget to upgrade your `PATH` environment variable once the build has
been successfully completed:

    export PATH=$PATH:/usr/local/clang-3.3/bin

# Package details

This following sections describe the changes made to the pristine source code.

## LLVM

The original code is used unmodified. Release 3.3 has been selected from the
GitHub repository mirror.

Symbolic links have been added so that submodules (clang, compiler_rt) are
located into the top-directory to simplify Git management.

## Clang

The original code is used unmodified. Release 3.3 has been selected from the
GitHub repository mirror.

## Newlib

The original code has been tweaked so that clang may be used to build the
library code. Release 2.0.0 has been selected from the official sources.

Official newlib distribution contains GCC-specific directives that are yet to
be emulated from clang front-end. These directives have been adapted so that
clang accepts to build the code.

### Changes

  1. `__attribute__((warning))__` used to flag deprecated APIs has been
    replaced with `__attribute__((deprecated))__` in `stdlib.h`
  2. global register name faking is not supported in clang:
    `register char * stack_ptr asm ("sp");`
    These statements have been moved to the related function implementations.
  3. `__USER_LABEL_PREFIX__` default definition to `_` has been replaced with
    an empty string.

## compiler_rt

Release 3.3 has been selected from the GitHub repository mirror.

This is where most of the changes have been made to the official distribution,
to support legacy ARM architectures and OS-less configurations.

### Changes

  1. Assembly files that contains ARMv5+ only instructions have been renamed,
     so they got built for the ARMv5 runtime, but their sub-optimal C-based
     counterpart can be built for the ARMv4T runtime:
       * `lib/arm/udivmodsi4.S` -> `lib/arm/udivmodsi4_armv5.S`
       * `lib/arm/udivsi3.S` -> `lib/arm/udivsi3_armv5.S`
       * `lib/arm/umodsi3.S` -> `lib/arm/umodsi3_armv5.S`
  2. Apple-specific assembly directive `.subsections_via_symbols` has been
     replaced with its generic, conditional macro definitions
     `FILE_LEVEL_DIRECTIVE`
       * `lib/arm/switch16.S`
       * `lib/arm/switch32.S`
       * `lib/arm/switch8.S`
       * `lib/arm/switchu8.S`
       * `lib/arm/sync_synchronize.S`
  3. `__USER_LABEL_PREFIX__` default definition to `_` has been replaced with
    an empty string.
  4. `armv4t` target has been added to the supported target list.
  5. a new platform, `clang_generic_arm.mk` file has been defined.
    * if your application does not link because of a missing glue symbol, this
      is where you should look for a missing symbol definition has not all
      symbols have been added to the compiler runtime library for now.
  6. Use the same endianess detection scheme as with Linux builds
  7. Remove use of Apple-specific LIPO tool to create the runtime library
    archive and select the proper Binutils tools.

## Gcc Wrapper

Clang front-end, which uses LLVM to build assembly source for the selected
target, always rely on the native GCC front-end to execute the assembly and
link stage (except for officially supported targets).

Unfortunately, it seems there is no way to specify an alternate front-end to
perform this dispatching. Building the whole GCC toolchain for the sake of the
front-end - and only it - would defeat the whole purpose of this package.

Therefore, a very basic dispatcher tool has been written, so that it parses and
recognizes the GCC front-end syntax and performs the dispatch on its own,
either invoking the GNU assembler or GNU linker that come with the Binutils
suite, not the GCC tool suite. Note that this simplified dispatcher is only
able to deal with LLVM-originated syntax and should not be used for any other
purposes.

In order to speed up development and modification of this dispatcher, it has
been written in Python. Using a native, C-based dispatcher would certainly
improve the performance, as the current solution required to spawn a Python
interpreter for each assembly or link stage. For now, simplicity has been
prefered over efficiency, as it is far easier to add support for new syntax and
magages the various option switches. Switching to a native wrapper is
definitely an option that should be considered once this package is stable
enough - or simply discarded if clang learns how to call the GNU AS and GNU LD
on its own.

The GCC front-end wrapper is made of a native executable `arm-eabi-gcc` that
is required to invoke the Python VM with the proper option switches. It resides
within the installed clang binary directory.

The Python dispatcher is simple enough and is installed within the same binary
directory, that is `/usr/local/clang-3.3/bin` or the alternative installation
directory selected at `build.sh` invokation.

The Python dispatcher also add the required PATH so that the linker may find
the proper runtime libraries, and add the `libcompiler_rt` library to the final
link as `libgcc` is no more.

The exact installation paths are replaced at `build.sh` installation stage in
the wrapper script.

## build.sh

This simple script is in charge of building the various stage of **clang4arm**:

  1. llvm + clang
  2. newlib for ARM
  3. compiler_rt for ARM
  4. GCC front-end wrapper
  5. dummy `libgcc.a` and `libsupc++.a` libraries

You may get usage documentation with the `-h` option switch:

    $ ./build.sh -h
    build.sh [options] [args]
      Build and execute Neotion VM
        -h              Print this help message
        -c              Clean all
        -j N            Build jobs (default: 5)
        -p path         Installation path (default: /usr/local/clang-3.3)
        -t toolchain    Toolchain prefix (default: arm-eabi)
    
      Debug mode
        -l              Run clang build/installation stage
        -w              Run wrapper build/installation stage
        -n              Run newlib build/installation stage
        -r              Run compiler runtime build/installation stage

### Notes

  1. Automatic job selection is not implemented on Linux. I guess it's the 
    matter of a couple of lines using the `/proc` FS. Patch welcomed!
  2. `build.sh` runs all build & installation stages one after another. If one
    or more *debug mode* option switches are set, the other stages are
    deselected and therefore ignored. This is mainly useful for debug purposes.

### Final note

Happy hacking!
