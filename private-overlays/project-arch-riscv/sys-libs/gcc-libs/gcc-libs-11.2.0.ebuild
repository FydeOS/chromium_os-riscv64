# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-devel/gcc/gcc-4.4.3-r3.ebuild,v 1.1 2010/06/19 01:53:09 zorry Exp $

# TODO(toolchain): This should not be building the compiler just to build
# the target libs.  It should re-use the existing system cross compiler.

EAPI=7

inherit eutils binutils-funcs

DESCRIPTION="The GNU Compiler Collection. This builds and installs the libgcc, libstdc++, and libgo libraries.  It is board-specific."

LICENSE="GPL-3 LGPL-3 FDL-1.2"
KEYWORDS="*"
IUSE="go hardened hardfp libatomic +thumb vtable_verify libunwind"
REQUIRED_USE="go? ( libatomic )"

: ${CTARGET:=${CHOST}}

SLOT="0"

PREFIX="/usr"

SRC_URI="mirror://gnu/gcc/gcc-${PV}/gcc-${PV}.tar.xz"

S="${WORKDIR}/gcc-${PV}"
MY_BUILDDIR="${WORKDIR}/build"

src_configure() {
	if [[ -f ${MY_BUILDDIR}/Makefile ]]; then
		ewarn "Skipping configure due to existing build output"
		return
	fi
	cros_use_gcc

	# Unset CC and CXX to let gcc-libs select the right compiler.
	unset CC CXX

	local confgcc=(
		--prefix=/usr
		--bindir=/delete-me
		--datadir=/delete-me
		--includedir=/delete-me
		--with-gxx-include-dir=/delete-me
		--libdir="/usr/$(get_libdir)"
		--with-slibdir="/usr/$(get_libdir)"
		# Disable install of python helpers in the target.
		--without-python-dir

		--build=${CBUILD}
		--host=${CBUILD}
		--target=${CHOST}
		--with-sysroot=/usr/${CTARGET}
		--enable-__cxa_atexit
		--disable-bootstrap
		--enable-checking=release
		--enable-linker-build-id
		--disable-libstdcxx-pch
		--enable-libgomp
		$(use_enable libatomic)

		# Disable libs we do not care about.
		--disable-libitm
		--disable-libmudflap
		--disable-libquadmath
		--disable-libssp
		--disable-lto
		--disable-multilib
		--disable-openmp
		--disable-libcilkrts
		--with-system-zlib
		--disable-libsanitizer
	)

	GCC_LANG="c,c++"
	use go && GCC_LANG+=",go"
	confgcc+=( --enable-languages=${GCC_LANG} )

	if use vtable_verify; then
		confgcc+=(
			--enable-cxx-flags=-Wl,-L../libsupc++/.libs
			--enable-vtable-verify
		)
	fi

	# Handle target-specific options.
	case ${CTARGET} in
	arm*)	#264534
		local arm_arch="${CTARGET%%-*}"
		# Only do this if arm_arch is armv*
		if [[ ${arm_arch} == armv* ]]; then
			# Convert armv7{a,r,m} to armv7-{a,r,m}
			[[ ${arm_arch} == armv7? ]] && arm_arch=${arm_arch/7/7-}
			# Remove endian ('l' / 'eb')
			[[ ${arm_arch} == *l ]] && arm_arch=${arm_arch%l}
			[[ ${arm_arch} == *eb ]] && arm_arch=${arm_arch%eb}
			confgcc+=(
				--with-arch=${arm_arch}
				--disable-esp
			)
			if use hardfp; then
				confgcc+=( --with-float=hard )
				case ${CTARGET} in
					armv6*) confgcc+=( --with-fpu=vfp ) ;;
					armv7a*) confgcc+=( --with-fpu=vfpv3 ) ;;
					armv7m*) confgcc+=( --with-fpu=vfpv2 ) ;;
				esac
			fi
			use thumb && confgcc+=( --with-mode=thumb )
		fi
		;;
	i?86*)
		# Hardened is enabled for x86, but disabled for ARM.
		confgcc+=(
			--enable-esp
			--with-arch=atom
			--with-tune=atom
			# Remove this once crash2 supports larger symbols.
			# http://code.google.com/p/chromium-os/issues/detail?id=23321
			--enable-frame-pointer
		)
		;;
	x86_64*-gnux32)
		confgcc+=( --with-abi=x32 --with-multilib-list=mx32 )
		;;
	esac

	# Finally add the user options (if any).
	confgcc+=( ${EXTRA_ECONF} )

	# Build in a separate build tree.
	mkdir -p "${MY_BUILDDIR}" || die
	cd "${MY_BUILDDIR}" || die

	# This is necessary because the emerge-${BOARD} machinery sometimes
	# adds machine-specific options to thsee flags that are not
	# appropriate for configuring and building the compiler libraries.
	export CFLAGS='-g -O2 -pipe'
	export CXXFLAGS='-g -O2 -pipe'
	export LDFLAGS="-Wl,-O2 -Wl,--as-needed"

	# and now to do the actual configuration
	addwrite /dev/zero
	echo "Running this:"
	echo "${S}"/configure "${confgcc[@]}"
	"${S}"/configure "${confgcc[@]}" || die
}

src_compile() {
	cd "${MY_BUILDDIR}"
	GCC_CFLAGS="${CFLAGS}"
	local target_flags=()
	local target_go_flags=()

	if use hardened; then
		target_flags+=( -fstack-protector-strong -D_FORTIFY_SOURCE=2 )
	fi

	EXTRA_CFLAGS_FOR_TARGET="${target_flags[*]} ${CFLAGS_FOR_TARGET}"
	EXTRA_CXXFLAGS_FOR_TARGET="${target_flags[*]} ${CXXFLAGS_FOR_TARGET}"

	if use vtable_verify; then
		EXTRA_CXXFLAGS_FOR_TARGET+=" -fvtable-verify=std"
	fi

	# libgo on arm must be compiled with -marm. Go's panic/recover functionality
	# is broken in thumb mode.
	if [[ ${CTARGET} == arm* ]]; then
		target_go_flags+=( -marm )
	fi
	EXTRA_GOCFLAGS_FOR_TARGET="${target_go_flags[*]} ${GOCFLAGS_FOR_TARGET}"

	# Do not link libgcc with gold. That is known to fail on internal linker
	# errors. See crosbug.com/16719
	local LD_NON_GOLD="$(get_binutils_path_ld ${CTARGET})/ld"

	# TODO(toolchain): This should not be needed.
	export CHOST="${CBUILD}"

	emake CFLAGS="${GCC_CFLAGS}" \
		LDFLAGS="-Wl,-O1" \
		CFLAGS_FOR_TARGET="$(get_make_var CFLAGS_FOR_TARGET) ${EXTRA_CFLAGS_FOR_TARGET}" \
		CXXFLAGS_FOR_TARGET="$(get_make_var CXXFLAGS_FOR_TARGET) ${EXTRA_CXXFLAGS_FOR_TARGET}" \
		GOCFLAGS_FOR_TARGET="$(get_make_var GOCFLAGS_FOR_TARGET) ${EXTRA_GOCFLAGS_FOR_TARGET}" \
		LD_FOR_TARGET="${LD_NON_GOLD}" \
		all-target
}

src_install() {
	cd "${MY_BUILDDIR}"
	emake -C "${CTARGET}"/libstdc++-v3/src DESTDIR="${D}" install
	emake -C "${CTARGET}"/libgcc DESTDIR="${D}" install-shared
	if use libatomic; then
		emake -C "${CTARGET}"/libatomic DESTDIR="${D}" install
	fi
	if use go; then
		emake -C "${CTARGET}"/libgo DESTDIR="${D}" install
	fi

	# Delete everything we don't care about (headers/etc...).
	rm -rf "${D}"/delete-me "${D}"/usr/$(get_libdir)/gcc/${CTARGET}/
	find "${D}" -name '*.py' -delete

	# Move the libraries to the proper location.  Many target libs do not
	# make this a configure option but hardcode the toolexeclibdir when
	# they're being cross-compiled.
  einfo "${D}"/usr/${CTARGET}/$(get_libdir)/lib*.so*
  einfo "$(get_libdir)"
  dolib.so "${D}"/usr/${CTARGET}/lib/lib*.so*
	#dolib.so "${D}"/usr/${CTARGET}/$(get_libdir)/lib*.so*
	use libunwind && rm -f "${D}"/usr/$(get_libdir)/libgcc_s*
	rm -rf "${D}"/usr/${CTARGET}
}

# Grab a variable from the build system (taken from linux-info.eclass)
get_make_var() {
	local var=$1 makefile=${2:-${MY_BUILDDIR}/Makefile}
	echo -e "e:\\n\\t@echo \$(${var})\\ninclude ${makefile}" | \
		r=${makefile%/*} emake --no-print-directory -s -f - 2>/dev/null
}

PATCHES=(
  "${FILESDIR}/gcc-11.2.0-add-riscv64-lib-path.patch"
)
