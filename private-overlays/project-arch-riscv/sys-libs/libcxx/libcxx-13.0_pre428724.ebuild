# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

# Ninja provides better scalability and cleaner verbose output, and is used
# throughout all LLVM projects.
: ${CMAKE_MAKEFILE_GENERATOR:=ninja}
PYTHON_COMPAT=( python3_6 )

inherit cmake-multilib cros-constants cros-llvm git-2 llvm python-any-r1 toolchain-funcs

DESCRIPTION="New implementation of the C++ standard library, targeting C++11"
HOMEPAGE="http://libcxx.llvm.org/"
SRC_URI=""

EGIT_REPO_URI="${CROS_GIT_HOST_URL}/external/github.com/llvm/llvm-project
	${CROS_GIT_HOST_URL}/external/github.com/llvm/llvm-project"
EGIT_BRANCH=main

LLVM_HASH="9968896cd62a62b11ac61085534dd598c4bd3c60" # r428724
LLVM_NEXT_HASH="9968896cd62a62b11ac61085534dd598c4bd3c60" # r428724

LICENSE="|| ( UoI-NCSA MIT )"
SLOT="0"
KEYWORDS="*"
IUSE="+compiler-rt cros_host elibc_glibc elibc_musl +libcxxabi libcxxrt libunwind llvm-next llvm-tot msan +static-libs"
REQUIRED_USE="libunwind? ( || ( libcxxabi libcxxrt ) )
	?? ( libcxxabi libcxxrt )"

RDEPEND="
	libcxxabi? ( ${CATEGORY}/libcxxabi[libunwind=,static-libs?,${MULTILIB_USEDEP}] )
	libcxxrt? ( ${CATEGORY}/libcxxrt[libunwind=,static-libs?,${MULTILIB_USEDEP}] )
	!libcxxabi? ( !libcxxrt? ( >=sys-devel/gcc-4.7:=[cxx] ) )
	!cros_host? ( sys-libs/gcc-libs )"
DEPEND="${RDEPEND}
	cros_host? ( sys-devel/llvm )
	app-arch/xz-utils"

python_check_deps() {
	has_version "dev-python/lit[${PYTHON_USEDEP}]"
}

src_unpack() {
	if use llvm-next || use llvm-tot; then
		export EGIT_COMMIT="${LLVM_NEXT_HASH}"
	else
		export EGIT_COMMIT="${LLVM_HASH}"
	fi
	git-2_src_unpack
}

src_prepare() {
	"${FILESDIR}"/patch_manager/patch_manager.py \
		--svn_version "$(get_most_recent_revision)" \
		--patch_metadata_file "${FILESDIR}"/PATCHES.json \
		--filesdir_path "${FILESDIR}" \
		--src_path "${S}" || die

	eapply_user
}

pkg_setup() {
	setup_cross_toolchain
	llvm_pkg_setup
	export CMAKE_USE_DIR="${S}/libcxx"
}

multilib_src_configure() {
	# Filter sanitzers flags.
	filter_sanitizers

	cros_optimize_package_for_speed

	local cxxabi cxxabi_incs
	if use libcxxabi; then
		cxxabi=libcxxabi
		cxxabi_incs="${SYSROOT}/${PREFIX}/include/libcxxabi"
	elif use libcxxrt; then
		cxxabi=libcxxrt
		cxxabi_incs="${EPREFIX}/usr/include/libcxxrt"
	else
		local gcc_inc="${EPREFIX}/usr/lib/gcc/${CHOST}/$(gcc-fullversion)/include/g++-v$(gcc-major-version)"
		cxxabi=libsupc++
		cxxabi_incs="${gcc_inc};${gcc_inc}/${CHOST}"
	fi
	# Use vfpv3 to be able to target non-neon targets.
	if [[ $(tc-arch) == "arm" ]] ; then
		append-flags -mfpu=vfpv3
	fi
    if [[ $(tc-arch) == riscv* ]] ; then
      append-flags -fuse-ld=bfd
    fi

	# we want -lgcc_s for unwinder, and for compiler runtime when using
	# gcc, clang with gcc runtime (or any unknown compiler)
	local extra_libs=() want_gcc_s=ON
	if use libunwind || use compiler-rt; then
		# work-around missing -lunwind upstream
		use libunwind && extra_libs+=( -lunwind )
		# if we're using libunwind and clang with compiler-rt, we want
		# to link to compiler-rt instead of -lgcc_s
		if tc-is-clang; then
			# get the full library list out of 'pretend mode'
			# and grep it for libclang_rt references
			local args=( $($(tc-getCC) -### -x c - 2>&1 | tail -n 1) )
			local i
			for i in "${args[@]}"; do
				if [[ ${i} == *libclang_rt* ]]; then
					want_gcc_s=OFF
					extra_libs+=( "${i}" )
				fi
			done
		fi
	fi

	# Link with libunwind.so.
	use libunwind && append-ldflags "-shared-libgcc"

	local libdir=$(get_libdir)
	local mycmakeargs=(
		"-DLLVM_ENABLE_PROJECTS=libcxx"
		"-DLIBCXX_LIBDIR_SUFFIX=${libdir#lib}"
		"-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY"
		"-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
		"-DLIBCXX_ENABLE_SHARED=ON"
		"-DLIBCXX_ENABLE_STATIC=$(usex static-libs)"
		"-DLIBCXX_CXX_ABI=${cxxabi}"
		"-DLIBCXX_CXX_ABI_INCLUDE_PATHS=${cxxabi_incs}"
		# we're using our own mechanism for generating linker scripts
		"-DLIBCXX_ENABLE_ABI_LINKER_SCRIPT=OFF"
		"-DLIBCXX_HAS_MUSL_LIBC=$(usex elibc_musl)"
		"-DLIBCXX_HAS_GCC_S_LIB=${want_gcc_s}"
		"-DLIBCXX_USE_COMPILER_RT=$(usex compiler-rt)"
		"-DLIBCXX_INCLUDE_TESTS=OFF"
		"-DLIBCXXABI_USE_LLVM_UNWINDER=$(usex libunwind)"
		"-DCMAKE_INSTALL_PREFIX=${PREFIX}"
		"-DCMAKE_SHARED_LINKER_FLAGS=${extra_libs[*]} ${LDFLAGS}"
		"-DLIBCXX_HAS_ATOMIC_LIB=OFF"
	)

	# Building 32-bit libc++ on host requires using host compiler
	# with LIBCXX_BUILD_32_BITS flag enabled.
	if use cros_host; then
		if [[ "${CATEGORY}" != "cross-"* && "$(get_abi_CTARGET)" == "i686"* ]]; then
			CC="$(tc-getBUILD_CC)"
			CXX="$(tc-getBUILD_CXX)"
			mycmakeargs+=(
				"-DLIBCXX_BUILD_32_BITS=ON"
			)
		fi
	fi
	if use msan; then
		mycmakeargs+=(
			"-DLLVM_USE_SANITIZER=Memory"
		)
	fi

	cmake-utils_src_configure
}

# Usage: deps
gen_ldscript() {
	local output_format
	output_format=$($(tc-getCC) ${CFLAGS} ${LDFLAGS} -Wl,--verbose 2>&1 | sed -n 's/^OUTPUT_FORMAT("\([^"]*\)",.*/\1/p')
	[[ -n ${output_format} ]] && output_format="OUTPUT_FORMAT ( ${output_format} )"

	cat <<-END_LDSCRIPT
/* GNU ld script
	Include missing dependencies
*/
${output_format}
GROUP ( $@ )
END_LDSCRIPT
}

gen_static_ldscript() {
	local libdir=$(get_libdir)
	local cxxabi_lib=$(usex libcxxabi "libc++abi.a" "$(usex libcxxrt "libcxxrt.a" "libsupc++.a")")

	# Move it first.
	mv "${ED}/${PREFIX}/${libdir}/libc++.a" "${ED}/${PREFIX}/${libdir}/libc++_static.a" || die
	# Generate libc++.a ldscript for inclusion of its dependencies so that
	# clang++ -stdlib=libc++ -static works out of the box.
	local deps="libc++_static.a ${cxxabi_lib} $(usex libunwind libunwind.a libgcc_eh.a)"
	# On Linux/glibc it does not link without libpthread or libdl. It is
	# fine on FreeBSD.
	use elibc_glibc && deps+=" libpthread.a libdl.a"

	gen_ldscript "${deps}" > "${ED}/${PREFIX}/${libdir}/libc++.a" || die
}

gen_shared_ldscript() {
	local libdir=$(get_libdir)
	# libsupc++ doesn't have a shared version
	local cxxabi_lib=$(usex libcxxabi "libc++abi.so" "$(usex libcxxrt "libcxxrt.so" "libsupc++.a")")
	mv "${ED}/${PREFIX}/${libdir}/libc++.so" "${ED}/${PREFIX}/${libdir}/libc++_shared.so" || die
	local deps="libc++_shared.so ${cxxabi_lib} $(usex compiler-rt '' $(usex libunwind libunwind.so libgcc_s.so))"

	gen_ldscript "${deps}" > "${ED}/${PREFIX}/${libdir}/libc++.so" || die
}

multilib_src_install() {
	cmake-utils_src_install
	gen_shared_ldscript
	use static-libs && gen_static_ldscript
}

multilib_src_install_all() {
	if [[ ${CATEGORY} == cross-* ]]; then
		rm -r "${ED}/usr/share/doc"
	fi
}
