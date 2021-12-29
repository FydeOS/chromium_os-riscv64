# Copyright 2021 The Chromium OS Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI=7
CROS_WORKON_PROJECT="chromiumos/third_party/adhd"
CROS_WORKON_LOCALNAME="adhd"
CROS_WORKON_USE_VCSID=1

inherit toolchain-funcs cros-workon cros-bazel

DESCRIPTION="Performance benchmarks for ChromeOS audio server"
HOMEPAGE="https://chromium.googlesource.com/chromiumos/third_party/adhd/"
LICENSE="BSD-Google"
KEYWORDS="~*"
IUSE="+cras-apm"

DEPEND="
	media-libs/alsa-lib
	cras-apm? ( media-libs/webrtc-apm:= )
"
RDEPEND="${DEPEND}"

bazel_external_uris="
	https://github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz -> bazel-skylib-1.0.3.tar.gz
	https://github.com/bazelbuild/rules_cc/archive/01d4a48911d5e7591ecb1c06d3b8af47fe872371.zip -> bazelbuild-rules_cc-01d4a48911d5e7591ecb1c06d3b8af47fe872371.zip
	https://github.com/bazelbuild/rules_java/archive/7cf3cefd652008d0a64a419c34c13bdca6c8f178.zip -> bazelbuild-rules_java-7cf3cefd652008d0a64a419c34c13bdca6c8f178.zip
	https://github.com/google/benchmark/archive/refs/tags/v1.5.5.tar.gz -> google-benchmark-1.5.5.tar.gz
"
SRC_URI="${bazel_external_uris}"

src_unpack() {
	bazel_load_distfiles "${bazel_external_uris}"
	cros-workon_src_unpack
}

src_prepare() {
	export JAVA_HOME=$(ROOT="${BROOT}" java-config --jdk-home)
	cd cras || die
	bazel_setup_crosstool
	default
}

src_configure() {
	cros_optimize_package_for_speed
}

src_compile() {
	cd cras || die
	args=(
		"$(use cras-apm && echo "--//src/benchmark:apm=true")"
	)
	ebazel build //src/benchmark:cras_bench "${args[*]}"
}

src_install() {
	dobin cras/bazel-bin/src/benchmark/cras_bench
}
