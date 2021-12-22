# Copyright 2018 The Chromium OS Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI=7

CROS_WORKON_COMMIT="54c7fac37782fd4a975d5ac8982da4ef9423fda7"
CROS_WORKON_TREE=("bfc498b82e9a26766af7a533220e0e9057ac3af4" "d897a7a44e07236268904e1df7f983871c1e1258")
CROS_RUST_SUBDIR="metrics/memd"

CROS_WORKON_PROJECT="chromiumos/platform2"
CROS_WORKON_LOCALNAME="platform2"
CROS_WORKON_SUBTREE="${CROS_RUST_SUBDIR} common-mk"
CROS_WORKON_INCREMENTAL_BUILD=1
CROS_WORKON_OUTOFTREE_BUILD=1

inherit cros-workon cros-rust

DESCRIPTION="Fine-grain memory metrics collector"
HOMEPAGE="https://chromium.googlesource.com/chromiumos/platform2/+/HEAD/metrics/memd/"

LICENSE="BSD-Google"
KEYWORDS="*"
IUSE="+seccomp"

DEPEND="chromeos-base/system_api:=
	sys-apps/dbus:=
	>=dev-rust/chrono-0.4.2:= <dev-rust/chrono-0.5.0
	>=dev-rust/dbus-0.6.1:= <dev-rust/dbus-0.7.0
	=dev-rust/env_logger-0.6*:=
	>=dev-rust/libc-0.2.44:= <dev-rust/libc-0.3.0
	>=dev-rust/log-0.4.5:= <dev-rust/log-0.5.0
	>=dev-rust/protobuf-2.3:= <dev-rust/protobuf-3.0
	>=dev-rust/protoc-rust-2.3:= <dev-rust/protoc-rust-3
	=dev-rust/syslog-4*:=
	=dev-rust/tempfile-3*:=
	>=dev-rust/time-0.1.40:= <dev-rust/time-0.2.0
	"
RDEPEND="sys-apps/dbus"

src_install() {
	# cargo doesn't know how to install cross-compiled binaries.  It will
	# always install native binaries for the host system.  Install manually
	# instead.
	local build_dir="$(cros-rust_get_build_dir)"
	dobin "${build_dir}/memd"
	insinto /etc/init
	doins init/memd.conf
	insinto /usr/share/policy
  if [[ "$ARCH" == riscv ]]; then
    _ARCH=arm64
  else
    _ARCH=$ARCH
  fi
	use seccomp && \
		newins "init/memd-seccomp-${_ARCH}.policy" memd-seccomp.policy
}
