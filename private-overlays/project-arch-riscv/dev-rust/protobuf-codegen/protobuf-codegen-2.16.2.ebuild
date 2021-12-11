# Copyright 2020 The Chromium OS Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI="7"

inherit cros-rust

DESCRIPTION="Protobuf code generator and a protoc-gen-rust protoc plugin"
HOMEPAGE="https://github.com/stepancheg/rust-protobuf/protobuf-codegen"
SRC_URI="https://crates.io/api/v1/crates/${PN}/${PV}/download -> ${P}.crate"

LICENSE="MIT"
SLOT="0/${PVR}"
KEYWORDS="*"

DEPEND="
	~dev-rust/protobuf-${PV}:=
"

src_compile() {
	ecargo_build
}

src_install() {
	cros-rust_publish "${PN}" "$(cros-rust_get_crate_version)"
	dobin "$(cros-rust_get_build_dir)/protoc-gen-rust"
}
