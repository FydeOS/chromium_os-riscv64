# Copyright 2014 The Chromium OS Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI=7

CROS_WORKON_COMMIT="5753398151237aca5668e45740b746e749a534cb"
CROS_WORKON_TREE=("d897a7a44e07236268904e1df7f983871c1e1258" "c2be5d4968aee22b81a31123a9837e15e996eea8" "113dbae63eb106c56996900e98cd65103bf297dc" "2bd42cf4f2f41e68c177dfdba095d8d3412fd76c" "1e9ca239fab09ba22b58e4a22d63e2ede865b159" "e08a2eb734e33827dffeecf57eca046cd1091373" "659b97d9c804b358f4bd27925620d4dd1cee8fc7" "f07eafa8dbb53d50c194352868520a8407a26bcc" "e7dba8c91c1f3257c34d4a7ffff0ea2537aeb6bb")
CROS_WORKON_INCREMENTAL_BUILD=1
CROS_WORKON_LOCALNAME="platform2"
CROS_WORKON_PROJECT="chromiumos/platform2"
CROS_WORKON_OUTOFTREE_BUILD=1
# TODO(crbug.com/809389): Avoid directly including headers from other packages.
CROS_WORKON_SUBTREE="common-mk attestation chaps libhwsec libhwsec-foundation metrics tpm_manager trunks .gn"

PLATFORM_SUBDIR="attestation"

inherit cros-workon libchrome platform user

DESCRIPTION="Attestation service for Chromium OS"
HOMEPAGE="https://chromium.googlesource.com/chromiumos/platform2/+/master/attestation/"

LICENSE="Apache-2.0"
KEYWORDS="*"
IUSE="generic_tpm2 test tpm tpm_dynamic tpm2"

REQUIRED_USE="
	tpm_dynamic? ( tpm tpm2 )
	!tpm_dynamic? ( ?? ( tpm tpm2 ) )
"

RDEPEND="
	tpm? (
		app-crypt/trousers:=
	)
	tpm2? (
		chromeos-base/trunks:=
	)
	chromeos-base/chaps:=
	chromeos-base/libhwsec-foundation:=
	chromeos-base/system_api:=[fuzzer?]
	>=chromeos-base/metrics-0.0.1-r3152:=
	chromeos-base/minijail:=
	chromeos-base/tpm_manager:=
	chromeos-base/attestation-client
	"

DEPEND="
	${RDEPEND}
	test? ( chromeos-base/libhwsec:= )
	chromeos-base/vboot_reference:=
	tpm2? (
		chromeos-base/trunks:=[test?]
		chromeos-base/chromeos-ec-headers:=
	)
	"

pkg_preinst() {
	# Create user and group for attestation.
	enewuser "attestation"
	enewgroup "attestation"
	# Create group for /mnt/stateful_partition/unencrypted/preserve.
	enewgroup "preserve"
}

src_install() {
	insinto /etc/dbus-1/system.d
	doins server/org.chromium.Attestation.conf

	insinto /etc/init
	doins server/attestationd.conf

	dosbin "${OUT}"/attestationd
	dobin "${OUT}"/attestation_client

	insinto /usr/share/policy
	newins server/attestationd-seccomp-${ARCH}.policy attestationd-seccomp.policy

	insinto /etc/dbus-1/system.d
	doins pca_agent/server/org.chromium.PcaAgent.conf
	insinto /etc/init
	doins pca_agent/server/pca_agentd.conf
	dosbin "${OUT}"/pca_agentd
	dobin "${OUT}"/pca_agent_client

	dolib.so "${OUT}"/lib/libattestation.so

	insinto /usr/include/attestation/common
	doins common/attestation_interface.h
	doins common/print_attestation_ca_proto.h
	doins common/print_interface_proto.h
	doins common/print_keystore_proto.h

	# Install the generated dbus-binding for fake pca agent.
	# It does no harm to install the header even for non-test image build.
	insinto /usr/include/attestation/pca-agent/dbus_adaptors
	doins "${OUT}"/gen/include/attestation/pca-agent/dbus_adaptors/org.chromium.PcaAgent.h

	insinto /usr/share/policy
	newins "pca_agent/server/pca_agentd-seccomp-${ARCH}.policy" pca_agentd-seccomp.policy
}

platform_pkg_test() {
	local tests=(
		attestation_testrunner
	)

	local test_bin
	for test_bin in "${tests[@]}"; do
		platform_test "run" "${OUT}/${test_bin}"
	done
}

src_compile() {
  platform_src_compile
  clone_policy_from_arm64_with_filter server/attestationd-seccomp-arm64.policy "s/renameat:/renameat2:/g"
  clone_policy_from_arm64_with_filter pca_agent/server/pca_agentd-seccomp-arm64.policy "s/renameat:/renameat2:/g"
}
