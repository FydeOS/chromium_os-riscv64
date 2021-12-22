# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit cros-fuzzer cros-sanitizers cros-constants cmake-multilib cmake-utils git-2 cros-llvm

DESCRIPTION="C++ runtime stack unwinder from LLVM"
HOMEPAGE="https://github.com/llvm-mirror/libunwind"
SRC_URI=""
EGIT_REPO_URI="${CROS_GIT_HOST_URL}/external/github.com/llvm/llvm-project
	${CROS_GIT_HOST_URL}/external/github.com/llvm/llvm-project"
EGIT_BRANCH=main

LLVM_HASH="9968896cd62a62b11ac61085534dd598c4bd3c60" # r428724
LLVM_NEXT_HASH="9968896cd62a62b11ac61085534dd598c4bd3c60" # r428724

LICENSE="|| ( UoI-NCSA MIT )"
SLOT="0"
KEYWORDS="*"
IUSE="cros_host debug llvm-next llvm-tot +static-libs +shared-libs synth_libgcc +compiler-rt"
RDEPEND="!${CATEGORY}/libunwind"

DEPEND="${RDEPEND}
	cros_host? ( sys-devel/llvm )"

pkg_setup() {
	# Setup llvm toolchain for cross-compilation
	setup_cross_toolchain
	export CMAKE_USE_DIR="${S}/libunwind"
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

should_enable_asserts() {
	if use debug || use llvm-tot; then
		echo yes
	else
		echo no
	fi
}

multilib_src_configure() {
	# Disable sanitization of llvm-libunwind (b/193934733).
	use_sanitizers && filter_sanitizers

	# Filter default portage flags to allow unwinding.
	cros_enable_cxx_exceptions
	append-cppflags "-D_LIBUNWIND_USE_DLADDR=0"
	# Allow targeting non-neon targets for armv7a.
	if [[ ${CATEGORY} == cross-armv7a* ]] ; then
		append-flags -mfpu=vfpv3
	fi

	local libdir=lib64
	local mycmakeargs=(
		"${mycmakeargs[@]}"
		"-DLLVM_ENABLE_PROJECTS=libunwind"
		"-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY"
		"-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
		"-DLLVM_LIBDIR_SUFFIX=${libdir#lib}"
		"-DLIBUNWIND_ENABLE_ASSERTIONS=$(should_enable_asserts)"
		"-DLIBUNWIND_ENABLE_STATIC=$(usex static-libs)"
		"-DLIBUNWIND_ENABLE_SHARED=OFF"
		"-DLIBUNWIND_ENABLE_THREADS=OFF"
		"-DLIBUNWIND_ENABLE_CROSS_UNWINDING=OFF"
		"-DLIBUNWIND_USE_COMPILER_RT=$(usex compiler-rt)"
		"-DLIBUNWIND_TARGET_TRIPLE=$(get_abi_CTARGET)"
		"-DCMAKE_INSTALL_PREFIX=${PREFIX}"
		# Avoid old libstdc++ errors when bootstrapping.
		"-DLLVM_ENABLE_LIBCXX=ON"
		"-DLIBUNWIND_HAS_COMMENT_LIB_PRAGMA=OFF"
		"-DLIBUNWIND_HAS_DL_LIB=OFF"
		"-DLIBUNWIND_HAS_PTHREAD_LIB=OFF"
	)

	cmake-utils_src_configure
}

multilib_src_install_all() {
	# Remove files that are installed by sys-libs/llvm-libunwind
	# to avoid collision when installing cross-${TARGET}/llvm-libunwind.
	if [[ ${CATEGORY} == cross-* ]]; then
		rm -rf "${ED}"usr/share || die
	fi

	# Install headers.
	insinto "${PREFIX}"/include
	doins -r "${S}"/libunwind/include/.
}

multilib_src_install() {
	cmake-utils_src_install

	# Generate libunwind.so
	local myabi=$(get_abi_CTARGET)
	if [[ ${myabi} == *armv7a* ]]; then
		LIBGCC_ARCH="armhf"
	elif [[ ${myabi} == *aarch64* ]]; then
		LIBGCC_ARCH="aarch64"
	elif [[ ${myabi} =~ ^i[0-9]86 ]]; then
		LIBGCC_ARCH="i386"
	elif [[ ${myabi} == *x86_64* ]] ; then
		LIBGCC_ARCH="x86_64"
  elif [[ ${myabi} == *riscv64* ]]; then
    LIBGCC_ARCH="riscv64"
	else
		echo "unsupported arch:${myabi}" && die
	fi

	local COMPILER_RT_BUILTINS=$($(tc-getCC) -print-libgcc-file-name -rtlib=compiler-rt)
	local my_installdir="${D%/}${PREFIX}/lib64"
  einfo "installdir:$my_installdir libdir:$(get_libdir)"
	$(tc-getCC) -o "${my_installdir}"/libunwind.so.1.0                              \
		${CFLAGS}                                                                   \
		${LDFLAGS}                                                                  \
		-shared                                                                     \
		-nostdlib                                                                   \
		-Wl,--whole-archive                                                         \
		-Wl,--version-script,"${FILESDIR}/version-scripts/gcc_s-${LIBGCC_ARCH}.ver" \
		-Wl,-soname,libunwind.so.1                                                  \
		"${COMPILER_RT_BUILTINS}"                                                   \
		"${my_installdir}"/libunwind.a                                              \
		-Wl,--no-whole-archive                                                      \
		-lm                                                                         \
		-lc                                                                         \
	|| die

	ln -s libunwind.so.1.0                  "${my_installdir}"/libunwind.so.1 || die
	ln -s libunwind.so.1                    "${my_installdir}"/libunwind.so || die
	# Generate libgcc{,_eh,_s}
	if ! use synth_libgcc; then
		return
	fi
	ln -s libunwind.so                      "${my_installdir}"/libgcc_s.so || die
	ln -s libunwind.so.1                    "${my_installdir}"/libgcc_s.so.1 || die
	ln -s    libunwind.a                       "${my_installdir}"/libgcc_eh.a || die
	cp    ${COMPILER_RT_BUILTINS}           "${my_installdir}"/libgcc.a || die
}
