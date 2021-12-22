# Copyright 1999-2020 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6
PYTHON_COMPAT=( python{2_7,3_4,3_5,3_6} )

inherit flag-o-matic eutils python-single-r1 versionator

GIT_SHAI="234e271db36e2a8be022f7a4bbabfa1623a6ae9a"   # GDB 9.2
SRC_URI="https://android.googlesource.com/toolchain/gdb/+archive/${GIT_SHAI}.tar.gz -> ${P}.tar.gz"

export CTARGET=${CTARGET:-${CHOST}}
if [[ ${CTARGET} == ${CHOST} ]] ; then
	if [[ ${CATEGORY} == cross-* ]] ; then
		export CTARGET=${CATEGORY#cross-}
	fi
fi
is_cross() { [[ ${CHOST} != ${CTARGET} ]] ; }

RPM=
MY_PV=${PV}

DESCRIPTION="GNU debugger"
HOMEPAGE="https://sourceware.org/gdb/"

LICENSE="GPL-2 LGPL-2"
SLOT="0"
KEYWORDS="*"
IUSE="+client lzma mounted_sources multitarget nls +python +server test vanilla xml"
REQUIRED_USE="
	python? ( ${PYTHON_REQUIRED_USE} )
	|| ( client server )
"

RDEPEND="server? ( !dev-util/gdbserver )
	client? (
		sys-libs/readline:0=
		lzma? ( app-arch/xz-utils )
		python? ( ${PYTHON_DEPS} )
		xml? ( dev-libs/expat )
		sys-libs/zlib
	)"
DEPEND="${RDEPEND}
	app-arch/xz-utils
	sys-apps/texinfo
	client? (
		>=sys-libs/ncurses-5.2-r2:0=
		virtual/yacc
		test? ( dev-util/dejagnu )
		nls? ( sys-devel/gettext )
	)"

GDB_BUILD_DIR="${WORKDIR}/${P}-build"

PATCHES=(
	"${FILESDIR}"/gdb-9.2-sht_relr.patch
	"${FILESDIR}"/gdb-9.2-python.patch
	"${FILESDIR}"/gdb-9.2-aarch64-tdesc.patch
	"${FILESDIR}"/gdb-9.2-sht_relr-part2.patch
	"${FILESDIR}"/gdb-9.2-sigsys.patch
	"${FILESDIR}"/gdb-9.2-update-loclists.patch
	"${FILESDIR}"/gdb-9.2-inlined-unwind.patch
)

pkg_setup() {
	use python && python-single-r1_pkg_setup
}

src_unpack() {
	S="${WORKDIR}"
	if use mounted_sources; then
		GDBDIR=/usr/local/toolchain_root/gdb
		if [[ ! -d ${GDBDIR} ]] ; then
			die "gdb dir not mounted/present at: ${GDBDIR}"
		fi
		cp -r "${GDBDIR}"/* "${S}"
	else
		default
	fi
	S="${WORKDIR}/${PN}-$(get_version_component_range 1-2)"
}

src_prepare() {
	[[ -n ${RPM} ]] && rpm_spec_epatch "${WORKDIR}"/gdb.spec
	! use vanilla && [[ -n ${PATCH_VER} ]] && EPATCH_SUFFIX="patch" eapply "${WORKDIR}"/patch

	default

	strip-linguas -u gdb-9.2/bfd/po gdb-9.2/opcodes/po
}

gdb_branding() {
	printf "Chromium OS ${PV} "
	if ! use vanilla && [[ -n ${PATCH_VER} ]] ; then
		printf "p${PATCH_VER}"
	else
		printf "vanilla"
	fi
	[[ -n ${EGIT_COMMIT} ]] && printf " ${EGIT_COMMIT}"
}

src_configure() {
	strip-unsupported-flags

	local myconf=(
		--with-pkgversion="$(gdb_branding)"
		--with-bugurl='http://crbug.com/new'
		--disable-werror
		# Disable modules that are in a combined binutils/gdb tree. #490566
		--disable-{binutils,etc,gas,gold,gprof,ld}
	)
	local sysroot="${EPREFIX}/usr/${CTARGET}"
	is_cross && myconf+=(
		--with-sysroot="${sysroot}"
		--includedir="${sysroot}/usr/include"
		--with-gdb-datadir="\${datadir}/gdb/${CTARGET}"
	)

	if use server && ! use client ; then
		# just configure+build in the gdbserver subdir to speed things up
		cd gdb/gdbserver
		myconf+=( --program-transform-name='' )
	else
		# gdbserver only works for native targets (CHOST==CTARGET).
		# it also doesn't support all targets, so rather than duplicate
		# the target list (which changes between versions), use the
		# "auto" value when things are turned on.
		is_cross \
			&& myconf+=( --disable-gdbserver ) \
			|| myconf+=( $(use_enable server gdbserver auto) )
	fi

	if ! ( use server && ! use client ) ; then
		# if we are configuring in the top level, then use all
		# the additional global options
		myconf+=(
			--enable-64-bit-bfd
			--disable-install-libbfd
			--disable-install-libiberty
			# Disable guile for now as it requires guile-2.x #562902
			--without-guile
			# This only disables building in the readline subdir.
			# For gdb itself, it'll use the system version.
			--disable-readline
			--with-system-readline
			# This only disables building in the zlib subdir.
			# For gdb itself, it'll use the system version.
			--without-zlib
			--with-system-zlib
			--with-separate-debug-dir="${EPREFIX}"/usr/lib/debug
			$(use_with xml expat)
			$(use_with lzma)
			$(use_enable nls)
			$(use multitarget && echo --enable-targets=all)
			$(use_with python python "${EPYTHON}")
		)
	fi
	if use sparc-solaris || use x86-solaris ; then
		# disable largefile support
		# https://sourceware.org/ml/gdb-patches/2014-12/msg00058.html
		myconf+=( --disable-largefile )
	fi

	mkdir "${GDB_BUILD_DIR}" || die
	pushd "${GDB_BUILD_DIR}" || die
	ECONF_SOURCE=${S}
	econf "${myconf[@]}"
	popd || die
}

src_compile() {
	emake -C "${GDB_BUILD_DIR}"
}

src_test() {
	nonfatal emake -C "${GDB_BUILD_DIR}" check || ewarn "tests failed"
}

src_install() {
	if use server && ! use client; then
		emake -C "${GDB_BUILD_DIR}"/gdb/gdbserver DESTDIR="${D}" install
	else
		emake -C "${GDB_BUILD_DIR}" DESTDIR="${D}" install
	fi

	if use client; then
		find "${ED}"/usr -name libiberty.a -delete || die
	fi

	# Delete translations that conflict with binutils-libs. #528088
	# Note: Should figure out how to store these in an internal gdb dir.
	if use nls ; then
		find "${ED}" \
			-regextype posix-extended -regex '.*/(bfd|opcodes)[.]g?mo$' \
			-delete || die
	fi

	# Don't install docs when building a cross-gdb
	if [[ ${CTARGET} != ${CHOST} ]] ; then
		rm -rf "${ED}"/usr/share/{doc,info,locale} || die
		local f
		for f in "${ED}"/usr/share/man/*/* ; do
			if [[ ${f##*/} != ${CTARGET}-* ]] ; then
				mv "${f}" "${f%/*}/${CTARGET}-${f##*/}" || die
			fi
		done
		return 0
	fi
	# Install it by hand for now:
	# https://sourceware.org/ml/gdb-patches/2011-12/msg00915.html
	# Only install if it exists due to the twisted behavior (see
	# notes in src_configure above).
	[[ -e "${GDB_BUILD_DIR}"/gdb/gdbserver/gdbreplay ]] && dobin "${GDB_BUILD_DIR}"/gdb/gdbserver/gdbreplay

	if use client ; then
		docinto gdb
		dodoc gdb/CONTRIBUTE gdb/README gdb/MAINTAINERS \
			gdb/NEWS gdb/ChangeLog gdb/PROBLEMS
	fi
	docinto sim
	dodoc sim/{ChangeLog,MAINTAINERS,README-HACKING}
	if use server ; then
		docinto gdbserver
		dodoc gdb/gdbserver/{ChangeLog,README}
	fi

	if [[ -n ${PATCH_VER} ]] ; then
		dodoc "${WORKDIR}"/extra/gdbinit.sample
	fi

	# Remove shared info pages
	rm -f "${ED}"/usr/share/info/{annotate,bfd,configure,standards}.info*
}

pkg_postinst() {
	# portage sucks and doesnt unmerge files in /etc
	rm -vf "${EROOT}"/etc/skel/.gdbinit

	if use prefix && [[ ${CHOST} == *-darwin* ]] ; then
		ewarn "gdb is unable to get a mach task port when installed by Prefix"
		ewarn "Portage, unprivileged.  To make gdb fully functional you'll"
		ewarn "have to perform the following steps:"
		ewarn "  % sudo chgrp procmod ${EPREFIX}/usr/bin/gdb"
		ewarn "  % sudo chmod g+s ${EPREFIX}/usr/bin/gdb"
	fi
}
