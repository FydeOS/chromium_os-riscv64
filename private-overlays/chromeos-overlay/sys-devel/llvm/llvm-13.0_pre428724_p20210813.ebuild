# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=7

PYTHON_COMPAT=( python3_{6..9} )

inherit cros-constants cmake flag-o-matic git-r3 multilib-minimal  \
	python-any-r1 pax-utils toolchain-funcs

LLVM_HASH="9968896cd62a62b11ac61085534dd598c4bd3c60" # r428724
LLVM_NEXT_HASH="9968896cd62a62b11ac61085534dd598c4bd3c60" # r428724

DESCRIPTION="Low Level Virtual Machine"
HOMEPAGE="http://llvm.org/"
SRC_URI="
	!llvm-tot? (
		!llvm-next? ( llvm_pgo_use? ( gs://chromeos-localmirror/distfiles/llvm-profdata-${LLVM_HASH}.tar.xz ) )
		llvm-next? ( llvm-next_pgo_use? ( gs://chromeos-localmirror/distfiles/llvm-profdata-${LLVM_NEXT_HASH}.tar.xz ) )
	)
"
EGIT_REPO_URI="${CROS_GIT_HOST_URL}/external/github.com/llvm/llvm-project
	${CROS_GIT_HOST_URL}/external/github.com/llvm/llvm-project"
EGIT_BRANCH=main

LICENSE="UoI-NCSA"
SLOT="8"
KEYWORDS="-* amd64"
# FIXME: llvm-tot is somewhat misleading: at the moment, it's essentially
# llvm-next with a few extra checks enabled
IUSE="debug +default-compiler-rt +default-libcxx doc libedit +libffi +llvm-crt
	llvm-next llvm_pgo_generate +llvm_pgo_use llvm-next_pgo_use llvm-tot
	multitarget ncurses ocaml test +thinlto xml video_cards_radeon"

COMMON_DEPEND="
	sys-libs/zlib:0=[${MULTILIB_USEDEP}]
	libedit? ( dev-libs/libedit:0=[${MULTILIB_USEDEP}] )
	libffi? ( >=virtual/libffi-3.0.13-r1:0=[${MULTILIB_USEDEP}] )
	ncurses? ( >=sys-libs/ncurses-5.9-r3:0=[${MULTILIB_USEDEP}] )
	ocaml? (
		>=dev-lang/ocaml-4.00.0:0=
		dev-ml/findlib
		dev-ml/ocaml-ctypes )"
# configparser-3.2 breaks the build (3.3 or none at all are fine)
DEPEND="${COMMON_DEPEND}
	sys-devel/binutils
	ocaml? ( test? ( dev-ml/ounit ) )"
RDEPEND="${COMMON_DEPEND}
	abi_x86_32? ( !<=app-emulation/emul-linux-x86-baselibs-20130224-r2
		!app-emulation/emul-linux-x86-baselibs[-abi_x86_32(-)] )
	!<=sys-devel/llvm-8.0_pre
	!sys-devel/lld
	!sys-devel/clang"
BDEPEND="
	dev-lang/perl
	libffi? ( virtual/pkgconfig )
	sys-devel/gnuconfig
	$(python_gen_any_dep '
		dev-python/sphinx[${PYTHON_USEDEP}]
		doc? ( dev-python/recommonmark[${PYTHON_USEDEP}] )
	')
"

# pypy gives me around 1700 unresolved tests due to open file limit
# being exceeded. probably GC does not close them fast enough.
REQUIRED_USE="
	llvm_pgo_generate? ( !llvm_pgo_use )"

check_lld_works() {
	echo 'int main() {return 0;}' > "${T}"/lld.cxx || die
	echo "Trying to link program with lld"
	$(tc-getCXX) -fuse-ld=lld -std=c++11 -o /dev/null "${T}"/lld.cxx
}

apply_pgo_profile() {
	! use llvm-tot && ( \
		( use llvm-next && use llvm-next_pgo_use ) ||
		( ! use llvm-next && use llvm_pgo_use ) )
}

src_unpack() {
	export CMAKE_USE_DIR="${S}/llvm"

	if use llvm-next || use llvm-tot; then
		EGIT_COMMIT="${LLVM_NEXT_HASH}"
	else
		EGIT_COMMIT="${LLVM_HASH}"
	fi

	git-r3_src_unpack

	if apply_pgo_profile; then
		cd "${WORKDIR}"
		local profile_hash
		if use llvm-next; then
			profile_hash="${LLVM_NEXT_HASH}"
		else
			profile_hash="${LLVM_HASH}"
		fi
		unpack "llvm-profdata-${profile_hash}.tar.xz"
	fi
}

get_most_recent_revision() {
	local subdir="${S}/llvm"

	# Tries to get the revision ID of the most recent commit
	"${FILESDIR}"/patch_manager/git_llvm_rev.py --llvm_dir "${subdir}" --sha "$(git -C "${subdir}" rev-parse HEAD)" | cut -d 'r' -f 2
}

src_prepare() {
	# Make ocaml warnings non-fatal, bug #537308
	sed -e "/RUN/s/-warn-error A//" -i llvm/test/Bindings/OCaml/*ml  || die

	python_setup

	"${FILESDIR}"/patch_manager/patch_manager.py \
		--svn_version "$(get_most_recent_revision)" \
		--patch_metadata_file "${FILESDIR}"/PATCHES.json \
		--filesdir_path "${FILESDIR}" \
		--src_path "${S}" || die

	cmake_src_prepare

	# Native libdir is used to hold LLVMgold.so
	NATIVE_LIBDIR=$(get_libdir)
}

enable_asserts() {
	# keep asserts enabled for llvm-tot
	if use llvm-tot; then
		echo yes
	else
		usex debug
	fi
}

multilib_src_configure() {
	export CMAKE_BUILD_TYPE="RelWithDebInfo"

	append-flags -Wno-poison-system-directories

	local targets
	if use multitarget; then
		targets='host;X86;ARM;AArch64;NVPTX;RISCV'
	else
		targets='host;CppBackend'
		use video_cards_radeon && targets+=';AMDGPU'
	fi

	local ffi_cflags ffi_ldflags
	if use libffi; then
		ffi_cflags=$($(tc-getPKG_CONFIG) --cflags-only-I libffi)
		ffi_ldflags=$($(tc-getPKG_CONFIG) --libs-only-L libffi)
	fi

	local libdir=$(get_libdir)
	local mycmakeargs=(
		"${mycmakeargs[@]}"
		"-DLLVM_ENABLE_PROJECTS=llvm;clang;lld;lldb;compiler-rt;clang-tools-extra"
		"-DLLVM_LIBDIR_SUFFIX=${libdir#lib}"

		"-DLLVM_BUILD_LLVM_DYLIB=ON"
		# Link LLVM statically
		"-DLLVM_LINK_LLVM_DYLIB=OFF"
		"-DBUILD_SHARED_LIBS=OFF"

		"-DLLVM_ENABLE_TIMESTAMPS=OFF"
		"-DLLVM_TARGETS_TO_BUILD=${targets}"
		"-DLLVM_BUILD_TESTS=$(usex test)"

		"-DLLVM_ENABLE_FFI=$(usex libffi)"
		"-DLLVM_ENABLE_TERMINFO=$(usex ncurses)"
		"-DLLVM_ENABLE_ASSERTIONS=$(enable_asserts)"
		"-DLLVM_ENABLE_EH=ON"
		"-DLLVM_ENABLE_RTTI=ON"

		"-DWITH_POLLY=OFF" # TODO

		"-DLLVM_HOST_TRIPLE=${CHOST}"

		"-DFFI_INCLUDE_DIR=${ffi_cflags#-I}"
		"-DFFI_LIBRARY_DIR=${ffi_ldflags#-L}"
		"-DLLVM_BINUTILS_INCDIR=${SYSROOT}/usr/include"

		"-DHAVE_HISTEDIT_H=$(usex libedit)"
		"-DENABLE_LINKER_BUILD_ID=ON"
		"-DCLANG_VENDOR=Chromium OS ${PVR}"
		# override default stdlib and rtlib
		"-DCLANG_DEFAULT_CXX_STDLIB=$(usex default-libcxx libc++ "")"
		"-DCLANG_DEFAULT_RTLIB=$(usex default-compiler-rt compiler-rt "")"

		# Turn on new pass manager for LLVM
		"-DENABLE_EXPERIMENTAL_NEW_PASS_MANAGER=ON"

		# crbug/855759
		"-DCOMPILER_RT_BUILD_CRT=$(usex llvm-crt)"

		"-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
		"-DCLANG_DEFAULT_UNWINDLIB=libgcc"

		# workaround for crbug/1198796
		"-DCLANG_TOOLING_BUILD_AST_INTROSPECTION=OFF"

		# By default do not enable PGO for compiler-rt
		"-DCOMPILER_RT_ENABLE_PGO=OFF"

		# compiler-rt needs libc++ sources to be specified to build
		# an internal copy for libfuzzer, can be removed if libc++
		# is built inside llvm ebuild.
		"-DCOMPILER_RT_LIBCXXABI_PATH=${S}/libcxxabi"
		"-DCOMPILER_RT_LIBCXX_PATH=${S}/libcxx"
		"-DCOMPILER_RT_BUILTINS_HIDE_SYMBOLS=OFF"

		# crbug/1146898: setting this to ON causes boot failures
		"-DENABLE_X86_RELAX_RELOCATIONS=OFF"

		# b/200831212: Disable per runtime install dirs.
		"-DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=OFF"
	)

	# Update LLVM to 9.0 will cause LLVM to complain GCC
	# version is < 5.1. Add this flag to suppress the error.
	mycmakeargs+=(
		"-DLLVM_TEMPORARILY_ALLOW_OLD_TOOLCHAIN=1"
	)

	if check_lld_works; then
		mycmakeargs+=(
			# We use lld to link llvm, because:
			# 1) Gold has issue with no index for archive,
			# 2) Gold doesn't support instrumented compiler-rt well.
			"-DLLVM_USE_LINKER=lld"
		)
		# The standalone toolchain may be run at places not supporting
		# smallPIE, disabling it for lld.
		# Pass -fuse-ld=lld to make cmake happy.
		append-ldflags "-fuse-ld=lld -Wl,--pack-dyn-relocs=none"
		# Disable warning about profile not matching.
		append-flags "-Wno-backend-plugin"

		if use thinlto; then
			mycmakeargs+=(
				"-DLLVM_ENABLE_LTO=thin"
			)
		fi

		if apply_pgo_profile; then
			mycmakeargs+=(
				"-DLLVM_PROFDATA_FILE=${WORKDIR}/llvm.profdata"
			)
		fi

		if use llvm_pgo_generate; then
			mycmakeargs+=(
				"-DLLVM_BUILD_INSTRUMENTED=IR"
			)
		fi
	fi

	if ! multilib_is_native_abi || ! use ocaml; then
		mycmakeargs+=(
			"-DOCAMLFIND=NO"
		)
	fi
#	Note: go bindings have no CMake rules at the moment
#	but let's kill the check in case they are introduced
#	if ! multilib_is_native_abi || ! use go; then
		mycmakeargs+=(
			"-DGO_EXECUTABLE=GO_EXECUTABLE-NOTFOUND"
		)
#	fi

	if multilib_is_native_abi; then
		mycmakeargs+=(
			"-DLLVM_BUILD_DOCS=$(usex doc)"
			"-DLLVM_ENABLE_SPHINX=$(usex doc)"
			"-DLLVM_ENABLE_DOXYGEN=OFF"
			"-DLLVM_INSTALL_HTML=${EPREFIX}/usr/share/doc/${PF}/html"
			"-DSPHINX_WARNINGS_AS_ERRORS=OFF"
			"-DLLVM_INSTALL_UTILS=ON"
		)
	fi

	if ! use debug; then
		append-cppflags -DNDEBUG
	fi

	cmake_src_configure
}

multilib_src_compile() {
  #die "check resources"
	cmake_src_compile

	pax-mark m "${BUILD_DIR}"/bin/llvm-rtdyld
	pax-mark m "${BUILD_DIR}"/bin/lli
	pax-mark m "${BUILD_DIR}"/bin/lli-child-target

	if use test; then
		pax-mark m "${BUILD_DIR}"/unittests/ExecutionEngine/Orc/OrcJITTests
		pax-mark m "${BUILD_DIR}"/unittests/ExecutionEngine/MCJIT/MCJITTests
		pax-mark m "${BUILD_DIR}"/unittests/Support/SupportTests
	fi
}

multilib_src_test() {
	# respect TMPDIR!
	local -x LIT_PRESERVES_TMP=1
	cmake_src_test
}

src_install() {
	local MULTILIB_CHOST_TOOLS=(
		/usr/bin/llvm-config
	)

	local MULTILIB_WRAPPED_HEADERS=(
		/usr/include/llvm/Config/config.h
		/usr/include/llvm/Config/llvm-config.h
	)

	multilib-minimal_src_install
}

multilib_src_install() {
	cmake_src_install

	local use_llvm_next=false
	if use llvm-next || use llvm-tot
	then
		use_llvm_next=true
	fi
	local wrapper_script=clang_host_wrapper

	"${FILESDIR}/compiler_wrapper/build.py" --config=cros.host --use_ccache=false \
		--use_llvm_next="${use_llvm_next}" \
		--output_file="${D}/usr/bin/${wrapper_script}" || die

	newbin "${D}/usr/bin/clang-tidy" "clang-tidy"
	dobin "${FILESDIR}/bisect_driver.py"
	exeinto "/usr/bin"
	dosym "${wrapper_script}" "/usr/bin/${CHOST}-clang"
	dosym "${wrapper_script}" "/usr/bin/${CHOST}-clang++"
	newexe "${FILESDIR}/ldwrapper_lld.host" "${CHOST}-ld.lld"

	# llvm-strip is a symlink to llvm-objcopy and distinguished by a argv[0] check.
	# When creating standalone toolchain, argv[0] information is lost and causes
	# llvm-strip invocations to be treated as llvm-objcopy breaking builds
	# (crbug.com/1151787). Handle this by making llvm-strip a full binary.
	if [[ -L "${D}/usr/bin/llvm-strip" ]]; then
		rm "${D}/usr/bin/llvm-strip" || die
		newbin "${D}/usr/bin/llvm-objcopy" "llvm-strip"
	fi

	# Build and install cross-compiler wrappers for supported ABIs.
	# ccache wrapper is used in chroot and non-ccache wrapper is used
	# in standalone SDK.
	local ccache_suffixes=(noccache ccache)
	local ccache_option_values=(false true)
	for ccache_index in {0,1}; do
		local ccache_suffix="${ccache_suffixes[${ccache_index}]}"
		local ccache_option="${ccache_option_values[${ccache_index}]}"
		# Build hardened wrapper written in golang.
		"${FILESDIR}/compiler_wrapper/build.py" --config="cros.hardened" \
			--use_ccache="${ccache_option}" \
			--use_llvm_next="${use_llvm_next}" \
			--output_file="${D}/usr/bin/sysroot_wrapper.hardened.${ccache_suffix}" || die

		# Build non-hardened wrapper written in golang.
		"${FILESDIR}/compiler_wrapper/build.py" --config="cros.nonhardened" \
			--use_ccache="${ccache_option}" \
			--use_llvm_next="${use_llvm_next}" \
			--output_file="${D}/usr/bin/sysroot_wrapper.${ccache_suffix}" || die
    
    "${FILESDIR}/compiler_wrapper/build.py" --config="cros.riscv" \
      --use_ccache="${ccache_option}" \
      --use_llvm_next="${use_llvm_next}" \
      --output_file="${D}/usr/bin/sysroot_wrapper.riscv.${ccache_suffix}" || die
	done

	local cros_hardened_targets=(
		"aarch64-cros-linux-gnu"
		"armv7a-cros-linux-gnueabihf"
		"i686-pc-linux-gnu"
		"x86_64-cros-linux-gnu"
	)
	local cros_nonhardened_targets=(
		"arm-none-eabi"
		"armv7m-cros-eabi"
	)
  local cros_riscv_targets=(
    "riscv64-cros-linux-gnu"
  )

	local target
	for target in "${cros_hardened_targets[@]}"; do
		dosym "sysroot_wrapper.hardened.ccache" "/usr/bin/${target}-clang"
		dosym "sysroot_wrapper.hardened.ccache" "/usr/bin/${target}-clang++"
	done
	for target in "${cros_nonhardened_targets[@]}"; do
		dosym "sysroot_wrapper.ccache" "/usr/bin/${target}-clang"
		dosym "sysroot_wrapper.ccache" "/usr/bin/${target}-clang++"
	done
  for target in "${cros_riscv_targets[@]}"; do
    dosym "sysroot_wrapper.riscv.ccache" "/usr/bin/${target}-clang"
    dosym "sysroot_wrapper.riscv.ccache" "/usr/bin/${target}-clang++"
  done

	# Remove this file, if it exists, to avoid installation file collision,
	# as this file is also generated/installed by the dev-python/six package.
	if [[ -f "${D}/usr/lib/python3.6/site-packages/six.py" ]]; then
		rm "${D}/usr/lib/python3.6/site-packages/six.py" || die
	fi
}

multilib_src_install_all() {
	insinto /usr/share/vim/vimfiles
	doins -r llvm/utils/vim/*/.
	# some users may find it useful
	dodoc llvm/utils/vim/vimrc
	dobin "${S}/compiler-rt/lib/asan/scripts/asan_symbolize.py"
}

pkg_postinst() {
	if has_version ">=dev-util/ccache-3.1.9-r2" ; then
		#add ccache links as clang might get installed after ccache
		"${EROOT}"/usr/bin/ccache-config --install-links
	fi
}

pkg_postrm() {
	if has_version ">=dev-util/ccache-3.1.9-r2" && [[ -z ${REPLACED_BY_VERSION} ]]; then
		# --remove-links would remove all links, --install-links updates them
		"${EROOT}"/usr/bin/ccache-config --install-links
	fi
}
