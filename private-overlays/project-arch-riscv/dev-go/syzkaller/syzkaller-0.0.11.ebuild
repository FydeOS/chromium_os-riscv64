# Copyright 2020 The Chromium OS Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EAPI=7

CROS_GO_SOURCE="github.com/google/syzkaller 8ee2dea687224e1e5759783abf5046d298bbe167"

CROS_GO_PACKAGES=(
	"github.com/google/syzkaller"
)

inherit cros-go

DESCRIPTION="Syzkaller kernel fuzzer"
HOMEPAGE="https://github.com/google/syzkaller"
SRC_URI="$(cros-go_src_uri)"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="*"
IUSE=""
SYZKALLER_PATH="src/github.com/google/syzkaller"

src_prepare() {
	cd "${SYZKALLER_PATH}" || die "unable to cd to extracted syzkaller directory"
	eapply "${FILESDIR}"/0001-cros-syzkaller-do-not-use-go.sum-and-go.mod.patch
	eapply "${FILESDIR}"/0002-cros-syzkaller-turn-off-vhci-injection.patch
	eapply "${FILESDIR}"/0003-cros-syzkaller-use-arm-toolchain-available-within-ch.patch
	eapply "${FILESDIR}"/0004-cros-syzkaller-add-hub-flag.patch
	eapply_user
}

src_compile() {
	cd "${SYZKALLER_PATH}" || die "unable to cd to extracted syzkaller directory"
#  SYZ_CLANG="1"
	CFLAGS="" GOPATH="$(cros-go_gopath):${S}" GO111MODULE=off \
     make TARGETOS=linux TARGETARCH="riscv64" || die "syzkaller build failed"
}

src_install() {
	local bin_path="${SYZKALLER_PATH}/bin"
	dobin "${bin_path}"/syz-manager || die "failed to install syz-manager"
	dobin "${bin_path}"/linux_"riscv64"/syz-fuzzer || die "failed to install syz-fuzzer"
	dobin "${bin_path}"/linux_"riscv64"/syz-executor || die "failed to install syz-executor"
	dobin "${bin_path}"/linux_"riscv64"/syz-execprog || die "failed to install syz-execprog"
}

# Overriding postinst for package github.com/google/syzkaller
# as no Go files are present in the repository root directory
# and getting list of packages inside cros-go_pkg_postinst() fails.
pkg_postinst() {
	:;
}
