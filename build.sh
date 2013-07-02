#!/bin/sh

CLANG_VERSION="3.3"
XTOOLCHAIN="arm-eabi"
PREFIX="/usr/local/clang-${CLANG_VERSION}"
BUILD="build"
VERBOSE=0

# Verify GNU make
MAKE=`which make 2> /dev/null`
if [ -z "${MAKE}" ]; then
    echo "Missing or invalid GNU make tool"
    exit 1
fi

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

if [ ! -d "${PREFIX}" ]; then
	echo "Destination directory ${PREFIX} does not exist" >&2
	exit 1
fi

if [ ! -d "${PREFIX}" ]; then
	echo "Destination directory ${PREFIX} does not exist" >&2
	exit 1
fi

if [ ! -w "${PREFIX}" ]; then
	echo "Destination directory ${PREFIX} is write-protected" >&2
	exit 1
fi

echo "Building clang..."
# out-of-source build
mkdir -p "${BUILD}/llvm"
(cd "${BUILD}/llvm" && \
	"${TOPDIR}/llvm/configure" \
		--prefix="${PREFIX}" && \
	make &&
	make install) || exit 1
export CC="${PREFIX}/bin/clang"
echo "---"
echo ""

# new clang should take the precedence over any installed clang, such as 
# Apple's
export PATH="${PREFIX}/bin":$PATH

echo "Building gcc wrapper for ${XTOOLCHAIN}..."
(cd wrapper &&
	clang -std=c99 -O3 -o wrapper wrapper.c &&
	cp wrapper "${PREFIX}/bin/${XTOOLCHAIN}-gcc"} &&
	cat wrapper.py | \
		sed 's^XTOOLCHAIN=""^XTOOLCHAIN="'${XTOOLCHAIN}'"^' | \
		sed 's^NEWLIB=""^NEWLIB="'${PREFIX}'"^' | \
		sed 's^COMPILER_RT=""^COMPILER_RT="'${PREFIX}/lib/${XTOOLCHAIN}'"^' > \
			"${PREFIX}/bin/wrapper.py")
echo "---"
echo ""

echo "Building newlib for ${XTOOLCHAIN}..."
# out-of-source build
mkdir -p "${BUILD}/newlib"
(cd "${BUILD}/newlib" && \
	"${TOPDIR}/newlib/configure" \
		--prefix="${PREFIX}" \
		--target="${XTOOLCHAIN}" && \
	make &&
	make install) || exit 1
echo "---"
echo ""

echo "Building compiler-rt for ${XTOOLCHAIN}..."
# in-source build
(cd "${TOPDIR}/llvm/projects/compiler-rt" && \
	make XTOOLCHAIN="${XTOOLCHAIN}" NEWLIB="${PREFIX}/newlib" \
		clang_generic_arm) || exit 1
echo "---"
echo ""
