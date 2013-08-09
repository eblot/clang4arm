#!/bin/sh

CLANG_VERSION="3.3"
XTOOLCHAIN="arm-eabi"
PREFIX="/usr/local/clang-${CLANG_VERSION}"
BUILD="build"
VERBOSE=0

UNAME=`uname`
if [ "${UNAME}" = "Darwin" ]; then
    # Discard any non-system library
    export DYLD_LIBRARY_PATH=""
    export DYLD_FALLBACK_LIBRARY_PATH=""
    CPUCORES=`sysctl hw.ncpu | cut -d: -f2`
	# WARNING: on OS X, it seems that using an alternative "make" executable
	# breaks compiler-rt build, as the wrong compiler is invoked with ARM
	# target. Not sure why, but llvm-gcc for ARM get called instead of the
	# wrapper. Maybe an implicit rule?
    MAKE=`which make 2> /dev/null`
    MAKE_VER=`${MAKE} --version | head -1 | sed s'/^[^0-9\.]*//'`
    MAKE_MAJ=`echo ${MAKE_VER} | cut -d. -f1`
    MAKE_MIN=`echo ${MAKE_VER} | cut -d. -f2`
    if [ ${MAKE_MAJ} -ne 3 -o ${MAKE_MIN} -ne 81 ]; then
    	echo "WARNING: Using an alternative make tool breaks compiler-rt" >&2
    	echo "" >&2
    fi
elif [ "${UNAME}" = "Linux" ]; then
    export LD_LIBRARY_PATH=""
    CPUCORES=`cat /proc/cpuinfo | grep processor | wc -l`
else
    CPUCORES=1 # to be implemented
fi

JOBS=`expr ${CPUCORES} + 1`

# Show usage information
usage()
{
    NAME=`basename $0`
    cat <<EOT
$NAME [options] [args]
  Build Clang for ARMv4/ARMv5 EABI targets
    -h              Print this help message
    -c              Clean all
    -j N            Build jobs (default: ${JOBS})
    -p path         Installation path (default: ${PREFIX})
    -t toolchain    Toolchain prefix (default: ${XTOOLCHAIN})

  Debug mode
    -l              Run clang build/installation stage
    -s              Run clang static analyser stage
    -w              Run wrapper build/installation stage
    -n              Run newlib build/installation stage
    -r              Run compiler runtime build/installation stage
EOT
}

CLEAN=0
VERBOSE=0
MAKE_OPT=""
RUN_CLANG=0
RUN_NEWLIB=0
RUN_RUNTIME=0
RUN_WRAPPER=0
RUN_CHECKER=0
RUN_ALL=1

# Parse the command line and update configuration
while [ $# -gt 0 ]; do
    case "$1" in
      -h)
        usage
        exit 0
        ;;
      -c)
        CLEAN=1
        ;;
      -j*)
        JOBS=`echo "$1" | cut -c3-`
        if [ -z "${JOBS}" ]; then
            shift
            JOBS="$1"
        fi
        ;;
      -v)
        VERBOSE=1
        MAKE_OPT="VERBOSE=1"
        ;;
      -p)
		shift
		PREFIX="$1"
		;;
      -t)
		shift
		XTOOLCHAIN="$1"
		;;
	  -l)
		RUN_CLANG=1
		RUN_ALL=0
		;;
	  -s)
		RUN_CHECKER=1
		RUN_ALL=0
		;;
	  -n)
		RUN_NEWLIB=1
		RUN_ALL=0
		;;
	  -r)
		RUN_RUNTIME=1
		RUN_ALL=0
		;;
	  -w)
		RUN_WRAPPER=1
		RUN_ALL=0
		;;
      '')
        break
        ;;
      *)
        usage
        echo ""
        echo "Unsupported option: '$1'" >&2
        exit 1
        ;;
    esac
    shift
done

if [ ${RUN_ALL} -gt 0 ]; then
	RUN_CLANG=1
	RUN_NEWLIB=1
	RUN_RUNTIME=1
	RUN_WRAPPER=1
	RUN_CHECKER=1
fi

RT_ROOT="${PREFIX}/lib/clang/${CLANG_VERSION}"

# Verify GNU make
MAKE=`which make 2> /dev/null`
if [ -z "${MAKE}" ]; then
    echo "Missing or invalid GNU make tool"
    exit 1
fi
MAKEVER_STR=`${MAKE} --version 2>&1 | head -1 | sed s'/^[^0-9\.]*//'`

ARMAS=`which ${XTOOLCHAIN}-as 2> /dev/null`
if [ -z "${ARMAS}" ]; then
    echo "Missing or invalid GNU assembler for ARM" >&2
    exit 1
fi
ARMASVER_STR=`${ARMAS} --version | head -1 |  sed s'/^[^0-9\.]*//'`
ARMAS_PATH=`dirname ${ARMAS}`
ARMLD=`which ${XTOOLCHAIN}-ld 2> /dev/null`
if [ -z "${ARMLD}" ]; then
    echo "Missing GNU linker for ARM"
fi
ARMLDVER_STR=`${ARMLD} --version | head -1 |  sed s'/^[^0-9\.]*//'`
ARMLD_PATH=`dirname ${ARMLD}`
if [ "${ARMAS_PATH}" != "${ARMLD_PATH}" ]; then
    echo "Invalid binutils installation" >&2
    exit 1
fi
if [ ${VERBOSE} -gt 0 ]; then
    echo "make:           ${MAKE} (v${MAKEVER_STR})"
    echo "xas:            ${ARMAS} (v${ARMASVER_STR})"
    echo "xld:            ${ARMLD} (v${ARMLDVER_STR})"
fi

TOPDIR="$PWD"

if [ ${RUN_CLANG} -gt 0 -a -d "${PREFIX}" ]; then
	echo "Destination directory ${PREFIX} already exists" >&2
	exit 1
else
	echo "Creating destination directory"
	(mkdir -p "${PREFIX}" 2> /dev/null) || \
	(sudo mkdir -p "${PREFIX}" && sudo chown $USER "${PREFIX}") || exit 1
fi

if [ ! -d "${PREFIX}" ]; then
	echo "Destination directory ${PREFIX} does not exist" >&2
	exit 1
fi

if [ ! -w "${PREFIX}" ]; then
	echo "Destination directory ${PREFIX} is write-protected" >&2
	exit 1
fi

if [ ${RUN_CLANG} -gt 0 ]; then
	echo "Building clang..."
	# out-of-source build
	if [ ${CLEAN} -gt 0 ]; then
		rm -rf "${BUILD}/llvm"
	fi
	mkdir -p "${BUILD}/llvm"
	(cd "${BUILD}/llvm" && \
		"${TOPDIR}/llvm/configure" \
		    --enable-optimized \
			--prefix="${PREFIX}" && \
		make -j${JOBS} &&
		make install) || exit 1
	export CC="${PREFIX}/bin/clang"
	echo ""
fi

if [ ${RUN_CHECKER} -gt 0 ]; then
	echo "Installing clang checker..."
	mkdir -p "${PREFIX}/checker/"
	mkdir -p "${PREFIX}/checker/Resources"
	(cd "${TOPDIR}/llvm/tools/clang/tools/scan-build" && \
		cp c++-analyzer ccc-analyzer scan-build set-xcode-analyzer \
		    scanview.css sorttable.js "${PREFIX}/checker/" &&
		cp scan-build.1 "${PREFIX}/share/man/man1/") &&
	(cd "${TOPDIR}/llvm/tools/clang/tools/scan-view" && \
		cp scan-view Reporter.py ScanView.py startfile.py \
		    "${PREFIX}/checker/" &&
		cp Resources/* "${PREFIX}/checker/Resources/") || exit 1
	echo ""
fi

# new clang should take the precedence over any installed clang, such as 
# Apple's
export PATH="${PREFIX}/bin":$PATH

if [ ${RUN_WRAPPER} -gt 0 ]; then
	echo "Building gcc wrapper for ${XTOOLCHAIN}..."
	if [ ${CLEAN} -gt 0 ]; then
		rm -rf "${BUILD}/wrapper"
	fi
	mkdir -p ${BUILD}/wrapper
	(cd ${BUILD}/wrapper &&
		clang -std=c99 -O3 -o wrapper ../../wrapper/wrapper.c &&
		cp wrapper "${PREFIX}/bin/${XTOOLCHAIN}-gcc" &&
		cat ../../wrapper/wrapper.py | \
			sed 's^XTOOLCHAIN=""^XTOOLCHAIN="'${XTOOLCHAIN}'"^' | \
			sed 's^NEWLIB=""^NEWLIB="'${PREFIX}'"^' | \
			sed 's^COMPILER_RT=""^COMPILER_RT="'${RT_ROOT}'"^' > \
				"${PREFIX}/bin/wrapper.py") || exit 1
	echo ""
fi

if [ ! -x "${PREFIX}/bin/${XTOOLCHAIN}-gcc" ]; then
	echo "Missing GCC wrapper" >&2
	exit 1
fi

if [ ${RUN_NEWLIB} -gt 0 ]; then
	echo "Building newlib for ${XTOOLCHAIN}..."
	# out-of-source build
	if [ ${CLEAN} -gt 0 ]; then
		rm -rf "${BUILD}/newlib"
	fi
	mkdir -p "${BUILD}/newlib"
	CLANG="${PREFIX}/bin/clang"
	export CC="${CLANG}"
	export CC_FOR_TARGET="${CLANG}"
	export CXX_FOR_TARGET="${CLANG}"
	export GCC_FOR_TARGET="${CLANG}"
	CLFLAGS="-Qunused-arguments -O3 -v -target ${XTOOLCHAIN}"
	CLFLAGS="${CLFLAGS} -isystem${PREFIX}/lib/clang/${CLANG_VERSION}/include"
	CLFLAGS="${CLFLAGS} -isystem${PWD}/compiler-rt/SDKs/linux/usr/include"
	export CFLAGS_FOR_TARGET="${CLFLAGS}"
	export CXXFLAGS_FOR_TARGET="${CLFLAGS}"
	(cd "${BUILD}/newlib" && \
		"${TOPDIR}/newlib/configure" \
		    --enable-serial-configure \
			--prefix="${PREFIX}" \
			--target="${XTOOLCHAIN}" && \
		make -j${JOBS} ${MAKE_OPT} &&
		make install) || exit 1
	echo ""
fi

if [ ${RUN_RUNTIME} -gt 0 ]; then
	echo "Building compiler-rt for ${XTOOLCHAIN}..."
	if [ ${CLEAN} -gt 0 ]; then
		(cd "${TOPDIR}/llvm/projects/compiler-rt" && \
			make clean)
	fi
	# in-source build
    # build the runtime and install it
    # create an empty archive for GCC runtime, as the GNU linker sometimes try
    # to automatically load it (when it loads standard libraries)
    # create an empty archive for C++ support, as the GNU linker always try to
    # load it when it detects C++ code, even when libsupc++ is not required.
	(cd "${TOPDIR}/llvm/projects/compiler-rt" && \
		make -j${JOBS} ${MAKE_OPT} \
			XTOOLCHAIN="${XTOOLCHAIN}" NEWLIB="${PREFIX}/newlib" \
			clang_generic_arm && \
		(cd clang_generic_arm && \
		 	for d in arm*; do \
		 		mkdir -p "${PREFIX}/lib/clang/${CLANG_VERSION}/lib/$d"; \
		 		cp "$d/libcompiler_rt.a" \
		 			"${RT_ROOT}/lib/$d/"; \
		 	    ${XTOOLCHAIN}-ar q "${RT_ROOT}/lib/$d/libgcc.a"
		 	    ${XTOOLCHAIN}-ar q "${RT_ROOT}/lib/$d/libsupc++.a"
		 	done \
		)) || exit 1
	echo ""
fi
