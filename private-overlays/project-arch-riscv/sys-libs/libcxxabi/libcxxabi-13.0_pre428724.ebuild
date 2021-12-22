# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

: ${CMAKE_MAKEFILE_GENERATOR:=ninja}
PYTHON_COMPAT=( python3_6 )

inherit cmake-multilib cros-constants cros-llvm flag-o-matic git-2 llvm python-any-r1

DESCRIPTION="Low level support for a standard C++ library"
HOMEPAGE="http://libcxxabi.llvm.org/"

SRC_URI=""
EGIT_REPO_URI="${CROS_GIT_HOST_URL}/external/github.com/llvm/llvm-project
	${CROS_GIT_HOST_URL}/external/github.com/llvm/llvm-project"
EGIT_BRANCH=main

LLVM_HASH="9968896cd62a62b11ac61085534dd598c4bd3c60" # r428724
LLVM_NEXT_HASH="9968896cd62a62b11ac61085534dd598c4bd3c60" # r428724

LICENSE="|| ( UoI-NCSA MIT )"
SLOT="0"
KEYWORDS="*"
IUSE="+compiler-rt cros_host libunwind msan llvm-next llvm-tot +static-libs"

RDEPEND="
	libunwind? (
			|| (
				>=${CATEGORY}/libunwind-1[static-libs?,${MULTILIB_USEDEP}]
				>=${CATEGORY}/llvm-libunwind-3.9.0-r1[static-libs?,${MULTILIB_USEDEP}]
			)
	)
	!cros_host? ( sys-libs/gcc-libs )"

DEPEND="${RDEPEND}
	cros_host? ( sys-devel/llvm )"

python_check_deps() {
	has_version "dev-python/lit[${PYTHON_USEDEP}]"
}

pkg_setup() {
	setup_cross_toolchain
	llvm_pkg_setup
	export CMAKE_USE_DIR="${S}/libcxxabi"
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

multilib_src_configure() {
	# Filter sanitzers flags.
	filter_sanitizers
	# Use vpfv3 fpu to be able to target non-neon targets.
	if [[ $(tc-arch) == "arm" ]] ; then
		append-flags -mfpu=vfpv3
	fi
	append-flags -I"${S}/libunwind/include"
	# Enable futex in libc++abi to match prod toolchain.
	append-cppflags -D_LIBCXXABI_USE_FUTEX
	local libdir=$(get_libdir)
	local mycmakeargs=(
		"-DLLVM_ENABLE_PROJECTS=libcxxabi"
		"-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY"
		"-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
		"-DLIBCXXABI_LIBDIR_SUFFIX=${libdir#lib}"
		"-DLIBCXXABI_ENABLE_SHARED=ON"
		"-DLIBCXXABI_ENABLE_STATIC=$(usex static-libs)"
		"-DLIBCXXABI_USE_LLVM_UNWINDER=$(usex libunwind)"
		"-DLIBCXXABI_INCLUDE_TESTS=OFF"
		"-DCMAKE_INSTALL_PREFIX=${PREFIX}"
		"-DLIBCXXABI_LIBCXX_INCLUDES=libcxx_build/include/c++/v1"
		"-DLIBCXXABI_USE_COMPILER_RT=$(usex compiler-rt)"
	)

	# Update LLVM to 9.0 will cause LLVM to complain
	# libstdc++ version is old. Add this flag as suggested in the error
	# message.
	mycmakeargs+=(
		"-DLLVM_TEMPORARILY_ALLOW_OLD_TOOLCHAIN=1"
	)

	# Building 32-bit libc++abi on host requires using host compiler
	# with LIBCXXABI_BUILD_32_BITS flag enabled.
	if use cros_host; then
		if [[ "${CATEGORY}" != "cross-"* && "$(get_abi_CTARGET)" == "i686"* ]]; then
			CC="$(tc-getBUILD_CC)"
			CXX="$(tc-getBUILD_CXX)"
			mycmakeargs+=(
				"-DLIBCXXABI_BUILD_32_BITS=ON"
			)
		fi
	fi

	if use msan; then
		mycmakeargs+=(
			"-DLLVM_USE_SANITIZER=Memory"
		)
	fi

	libcxx_configure

	# Link with libunwind.so.
	use libunwind && append-ldflags "-shared-libgcc"
	cmake-utils_src_configure
}

# Works around libcxx/libcxxabi cyclic dependency where libcxx needs libcxxabi,
# but libcxxabi needs libcxx headers by generating the libcxx headers for
# libcxxabi.
libcxx_configure() {
	mkdir -p libcxx_build
	cd libcxx_build || die
	local libdir=$(get_libdir)
	local mycmakeargs=(
		"-DLLVM_ENABLE_PROJECTS=libcxx"
		"-DLIBCXX_LIBDIR_SUFFIX=${libdir#lib}"
		"-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY"
		"-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
		"-DLIBCXX_ENABLE_SHARED=ON"
		"-DLIBCXX_ENABLE_STATIC=yes"
		"-DLIBCXX_CXX_ABI=libcxxabi"
		# we're using our own mechanism for generating linker scripts
		"-DLIBCXX_ENABLE_ABI_LINKER_SCRIPT=OFF"
		"-DLIBCXX_HAS_MUSL_LIBC=off"
		"-DLIBCXX_HAS_GCC_S_LIB=no"
		"-DLIBCXX_USE_COMPILER_RT=yes"
		"-DLIBCXX_INCLUDE_TESTS=OFF"
		"-DLIBCXX_HAS_ATOMIC_LIB=OFF"
		"-DLIBCXXABI_USE_LLVM_UNWINDER=$(usex libunwind)"
		"-DCMAKE_INSTALL_PREFIX=${PREFIX}"
	)
	cmake -GNinja "${S}/libcxx" "${mycmakeargs[@]}"
	ninja generate-cxx-headers || die
	cd .. || die
}

multilib_src_install_all() {
	if [[ ${CATEGORY} == cross-* ]]; then
		rm -r "${ED}/usr/share/doc"
	fi
	insinto "${PREFIX}"/include/libcxxabi
	doins -r "${S}"/libcxxabi/include/.
}

