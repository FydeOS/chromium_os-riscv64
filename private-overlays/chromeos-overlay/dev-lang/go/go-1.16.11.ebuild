# Copyright 2016 The Chromium OS Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2.

EAPI=5

inherit eutils toolchain-funcs

# Version used to bootstrap the build.
BOOTSTRAP="go1.4-bootstrap-20170531"

DESCRIPTION="An expressive, concurrent, garbage-collected programming language"
HOMEPAGE="http://golang.org/"
SRC_URI="
	https://storage.googleapis.com/golang/go${PV}.src.tar.gz
	https://storage.googleapis.com/golang/${BOOTSTRAP}.tar.gz
"

LICENSE="BSD-Google"
SLOT="0"
KEYWORDS="*"
IUSE=""
RESTRICT="binchecks strip mirror"

is_cross() {
	[[ "${CATEGORY}" == cross-* ]]
}

DEPEND=""
if is_cross ; then
	DEPEND="${CATEGORY}/gcc"
fi
RDEPEND="${DEPEND}"

export CTARGET="${CTARGET:-${CHOST}}"
if [[ "${CTARGET}" == "${CHOST}" ]] ; then
	if is_cross ; then
		CTARGET="${CATEGORY#cross-}"
	fi
fi

get_goroot() {
	if is_cross ; then
		echo "/usr/lib/go/${CTARGET}"
	else
		echo "/usr/lib/go"
	fi
}

get_goarch() {
	case "$(tc-arch $1)" in
		amd64) echo "amd64" ;;
		x86) echo "386" ;;
		arm) echo "arm" ;;
		arm64) echo "arm64" ;;
    riscv*) echo "riscv64" ;;
	esac
}

src_unpack() {
	unpack "go${PV}.src.tar.gz"
	mv go "go-${PV}"
	unpack "${BOOTSTRAP}.tar.gz"
	mv go "${BOOTSTRAP}"
}

src_configure() {
	export GOROOT_BOOTSTRAP="${WORKDIR}/${BOOTSTRAP}"
	export GOROOT_FINAL="${EPREFIX}$(get_goroot)"
	einfo "go final :$GOROOT_FINAL"
}

src_compile() {
	einfo "Building the bootstrap compiler."
	cd "${GOROOT_BOOTSTRAP}/src"
	./make.bash || die

	cd "${S}/src"
	einfo "Building the cross compiler for ${CTARGET}."
	local go_target_cc="$(tc-getTARGET_CC)"
	local go_target_cxx="$(tc-getTARGET_CXX)"
	local cgoflags=""
	if [[ "$(tc-arch "${CTARGET}")" == riscv* ]]; then
		cgoflags="-mno-relax"
	fi
	if [[ "$(tc-arch "${CBUILD}")" == "$(tc-arch "${CTARGET}")" ]]; then
		go_target_cc="$(tc-getBUILD_CC)"
		go_target_cxx="$(tc-getBUILD_CXX)"
	fi
	einfo "c:$go_target_cc cxx:$go_target_cxx"
	GOOS="linux" GOARCH="$(get_goarch "${CTARGET}")" CGO_ENABLED="1" \
		CC_FOR_TARGET="${go_target_cc}" \
		CXX_FOR_TARGET="${go_target_cxx}" \
		GO_CFLAGS="$cgoflags" \
		CGO_CFLAGS="$cgoflags" \
		CGO_CXXFLAGS="$cgoflags" \
		CGO_FFLAGS="$cgoflags" \
		./make.bash || die

	if is_cross ; then
		einfo "Building the standard library with -buildmode=pie. ROOT=${S}"
    einfo "go build: $(env| grep GO) arch:$(get_goarch ${CTARGET})"
		GOOS="linux" GOARCH="$(get_goarch ${CTARGET})" CGO_ENABLED="1" \
			CC="${go_target_cc}" \
			CXX="${go_target_cxx}" \
      GO_CFLAGS="$cgoflags" \
      CGO_CFLAGS="$cgoflags" \
      CGO_CXXFLAGS="$cgoflags" \
      CGO_FFLAGS="$cgoflags" \
			GOROOT="${S}" \
			"${S}/bin/go" install -v -buildmode=pie std || die
	fi
#      CC_FOR_TARGET="${go_target_cc}" \
#      CXX_FOR_TARGET="${go_target_cxx}" \
}

src_install() {
	local goroot="$(get_goroot)"
	local tooldir="pkg/tool/linux_$(get_goarch ${CBUILD})"

	insinto "${goroot}"
	doins -r src lib

	exeinto "${goroot}/bin"
	doexe bin/{go,gofmt}

	insinto "${goroot}/pkg"
	doins -r "pkg/include"
	doins -r "pkg/linux_$(get_goarch ${CTARGET})"
	if is_cross ; then
		doins -r "pkg/linux_$(get_goarch ${CTARGET})_shared"
	fi

	exeinto "${goroot}/${tooldir}"
	doexe "${tooldir}/"{asm,cgo,compile,link,pack}
	doexe "${tooldir}/"{doc,fix,vet}
	doexe "${tooldir}/"{cover,pprof,trace}
	doexe "${tooldir}/"{addr2line,buildid,nm,objdump,test2json}

	if is_cross ; then
		# Setup the wrapper for invoking the cross compiler.
		# See "files/pie_wrapper.py" for details.
		newbin "${FILESDIR}/pie_wrapper.py" "${CTARGET}-go"
	else
		dosym "${goroot}/bin/go" /usr/bin/go
		dosym "${goroot}/bin/gofmt" /usr/bin/gofmt
		# Setup the wrapper for invoking the host compiler.
		# See "files/host_wrapper.py" for details.
		newbin "${FILESDIR}/host_wrapper.py" "${CTARGET}-go"
	fi

	# Fill in variable values in the compiler wrapper.
	sed -e "s:@GOARCH@:$(get_goarch ${CTARGET}):" \
		-e "s:@CC@:$(tc-getTARGET_CC):" \
		-e "s:@CXX@:$(tc-getTARGET_CXX):" \
		-e "s:@GOTOOL@:${GOROOT_FINAL}/bin/go:" \
		-i "${D}/usr/bin/${CTARGET}-go" || die
}

pkg_postinst() {
  if [[ "$(tc-arch "${CTARGET}")" == riscv* ]]; then 
    local GOENV="$(get_goroot)/bin/go env"
    $GOENV -w GO111MODULE="off"
  fi
}
