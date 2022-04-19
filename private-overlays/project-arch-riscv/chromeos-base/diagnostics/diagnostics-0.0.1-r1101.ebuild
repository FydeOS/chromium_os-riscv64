# Copyright 2018 The Chromium OS Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI=7

CROS_WORKON_COMMIT="54c7fac37782fd4a975d5ac8982da4ef9423fda7"
CROS_WORKON_TREE=("d897a7a44e07236268904e1df7f983871c1e1258" "3a8b816b9fdaca04ec76e8a8d97b206e139a9dfc" "b2ec39feeecaac88b6d0710498eaf82cc34315f8" "e7dba8c91c1f3257c34d4a7ffff0ea2537aeb6bb")
CROS_WORKON_INCREMENTAL_BUILD=1
CROS_WORKON_LOCALNAME="platform2"
CROS_WORKON_OUTOFTREE_BUILD=1
CROS_WORKON_PROJECT="chromiumos/platform2"
# TODO(crbug.com/1044813): Remove chromeos-config once its public headers are fixed.
CROS_WORKON_SUBTREE="common-mk chromeos-config diagnostics .gn"

PLATFORM_SUBDIR="diagnostics"

inherit cros-workon cros-unibuild platform udev user

DESCRIPTION="Device telemetry and diagnostics for Chrome OS"
HOMEPAGE="https://chromium.googlesource.com/chromiumos/platform2/+/master/diagnostics"

LICENSE="BSD-Google"
KEYWORDS="*"
IUSE="fuzzer wilco mesa_reven"

COMMON_DEPEND="
	chromeos-base/chromeos-config-tools:=
	chromeos-base/minijail:=
	dev-libs/protobuf:=
	dev-libs/re2:=
	net-libs/grpc:=
	virtual/libudev:=
	sys-apps/pciutils:=
	virtual/opengles:=
"

DEPEND="
	${COMMON_DEPEND}
	chromeos-base/attestation-client:=
	chromeos-base/debugd-client:=
	chromeos-base/tpm_manager-client:=
	chromeos-base/system_api:=[fuzzer?]
	media-sound/adhd:=
	x11-drivers/opengles-headers:=
"

# TODO(crbug/1085169): Replace sys-block/fio dependency with an alternative as
# it is very large. It is currently only a dependency of wilco as it is
# currently the only client.
RDEPEND="
	${COMMON_DEPEND}
	dev-util/stressapptest
	wilco? (
		sys-block/fio
		chromeos-base/chromeos-dtc-vm
		chromeos-base/vpd
	)
"

pkg_preinst() {
	enewgroup cros_ec-access
	enewuser cros_healthd
	enewgroup cros_healthd
	enewuser healthd_ec
	enewgroup healthd_ec

	if use wilco; then
		enewuser wilco_dtc
		enewgroup wilco_dtc
	fi
}

src_install() {
	dobin "${OUT}/cros_healthd"
	dobin "${OUT}/cros-health-tool"

	if use wilco; then
		dobin "${OUT}/wilco_dtc_supportd"

		# Install seccomp policy files.
		insinto /usr/share/policy
		newins "init/wilco_dtc_supportd-seccomp-${ARCH}.policy" \
			wilco_dtc_supportd-seccomp.policy
		newins "init/wilco-dtc-e2fsck-seccomp-${ARCH}.policy" \
			wilco-dtc-e2fsck-seccomp.policy
		newins "init/wilco-dtc-resize2fs-seccomp-${ARCH}.policy" \
			wilco-dtc-resize2fs-seccomp.policy

		# Install D-Bus configuration file.
		insinto /etc/dbus-1/system.d
		doins dbus/org.chromium.WilcoDtcSupportd.conf
		doins dbus/WilcoDtcUpstart.conf

		# Install the init scripts.
		insinto /etc/init
		doins init/wilco_dtc_dispatcher.conf
		doins init/wilco_dtc_supportd.conf
		doins init/wilco_dtc.conf

		# Install udev rules.
		udev_dorules udev/99-ec_driver_files.rules
	fi

	# Install seccomp policy files.
	insinto /usr/share/policy
	newins "init/cros_healthd-seccomp-${ARCH}.policy" \
		cros_healthd-seccomp.policy
	newins "cros_healthd/seccomp/ectool_i2cread-seccomp-${ARCH}.policy" \
		ectool_i2cread-seccomp.policy
	newins "cros_healthd/seccomp/ectool_pwmgetfanrpm-seccomp-${ARCH}.policy" \
		ectool_pwmgetfanrpm-seccomp.policy
	newins "seccomp/memtester-seccomp-${ARCH}.policy" memtester-seccomp.policy

	# Install D-Bus configuration file.
	insinto /etc/dbus-1/system.d
	doins dbus/org.chromium.CrosHealthd.conf

	# Install the init scripts.
	insinto /etc/init
	doins init/cros_healthd.conf

	# Install the diagnostic routine executables.
	exeinto /usr/libexec/diagnostics
	doexe "${OUT}/floating-point-accuracy"
	doexe "${OUT}/prime-search"
	doexe "${OUT}/smartctl-check"
	doexe "${OUT}/urandom"

	# Install udev rules.
	udev_dorules udev/99-chown_dmi_dir.rules

	# Install fuzzers.
	local fuzzer_component_id="982097"
	platform_fuzzer_install "${S}"/OWNERS "${OUT}"/fetch_system_info_fuzzer \
		--comp "${fuzzer_component_id}"
}

platform_pkg_test() {
	local tests=(
		cros_healthd_test
	)
	if use wilco; then
		tests+=(
			wilco_dtc_supportd_test
		)
	fi

	local test_bin
	for test_bin in "${tests[@]}"; do
		platform_test "run" "${OUT}/${test_bin}"
	done
}

src_compile() {
  platform_src_compile
  local policies=$(find -name *arm64.policy)
  for policy in $policies; do
    clone_policy_from_arm64 $policy
  done
}
