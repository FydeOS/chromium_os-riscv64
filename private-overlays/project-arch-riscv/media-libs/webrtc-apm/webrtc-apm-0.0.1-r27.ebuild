# Copyright 2018 The Chromium OS Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EAPI=5

CROS_WORKON_COMMIT="1083475701e93d11997aa3e1bb68ac1a0e88bc1d"
CROS_WORKON_TREE="1a0b1a1877d86d749c00100ebbef86fc9c873b6b"
CROS_WORKON_PROJECT="chromiumos/third_party/webrtc-apm"
CROS_WORKON_LOCALNAME="webrtc-apm"

inherit cros-workon multilib cros-sanitizers

DESCRIPTION="Standalone WebRTC APM library"
HOMEPAGE="https://chromium.googlesource.com/chromiumos/third_party/webrtc-apm"
SRC_URI=""

LICENSE="BSD-Google"
SLOT="0"
KEYWORDS="*"
IUSE="cpu_flags_x86_sse2 neon"

DEPEND="dev-libs/iniparser:=
	dev-libs/libevent:=
	dev-libs/protobuf:=
	chromeos-base/metrics"
RDEPEND="${DEPEND}"

src_configure() {
  append-flags "-Wno-error=#warnings"
	sanitizers-setup-env
	export USE_NEON=$(usex neon 1 0)
	export USE_SSE2=$(usex cpu_flags_x86_sse2 1 0)
}

src_install() {
	local INCLUDE_DIR="/usr/include/webrtc-apm"
	local LIB_DIR="/usr/$(get_libdir)"

	dolib libwebrtc_apm.so

	insinto "${INCLUDE_DIR}"
	doins webrtc_apm.h

	sed -e "s|@INCLUDE_DIR@|${INCLUDE_DIR}|" -e "s|@LIB_DIR@|${LIB_DIR}|" \
		libwebrtc_apm.pc.template > libwebrtc_apm.pc
	insinto "${LIB_DIR}/pkgconfig"
	doins libwebrtc_apm.pc
}

src_prepare() {
  default
  epatch ${FILESDIR}/fix-compile-riscv.patch
}
