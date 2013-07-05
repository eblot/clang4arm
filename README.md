# Clang for ARM embedded targets

clang4arm aims at providing a toolchain for legacy ARM targets (ARMv4T, ARMv5),
without relying on the GCC compiler suite.

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
  * GNU binutils for the target:
    * GNU as assembler
    * GNU ld linker
    * GNU ar archiver
  * make
  * Host toolchain (based on clang or GCC)
  * Python 2.7

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

  1. For now, only [AAPCS](http://infocenter.arm.com/help/topic/com.arm.doc.ihi0042e/IHI0042E_aapcs.pdf) has been tested: `arm-eabi` targets. The Linux variant 
  `arm-linux-gnueabi` has not been tested.
  2. Thumb support is NOT available, as the LLVM compiler emits invalid 
    thumb1 opcodes for legacy ARM targets (ARMv4T, ARMv5).
  3. Limited C++ support: `libsupc++` is not build.

## Components

The clang4arm toolchain comprises:

  * [LLVM](http://llvm.org) toolchain
  * [clang](http://clang.llvm.org) front-end
  * [newlib](http://sourceware.org/newlib) built for ARMv4t/ARMv5 targets, as
    the standard C libraries (libc, libm)
  * [compiler_rt](http://compiler-rt.llvm.org) built for ARMv4t/ARMv5 targets,
    as a replacement for libgcc
  * dedicated wrapper that acts as a replacement for the GCC front-end, see 
    below for details

The current package is based on the official LLVM/clang v3.3 final release.
