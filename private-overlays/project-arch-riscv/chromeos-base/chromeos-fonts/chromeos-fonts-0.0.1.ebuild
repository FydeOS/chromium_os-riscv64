# Copyright (c) 2012 The Chromium OS Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit cros-constants

DESCRIPTION="Chrome OS Fonts (meta package)"
HOMEPAGE="http://src.chromium.org"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="*"
IUSE="cros_host internal"

# List of font packages used in Chromium OS.  This list is separate
# so that it can be shared between the host in
# chromeos-base/hard-host-depends and the target in
# chromeos-base/chromeos.
#
# The glibc requirement is a bit funky.  For target boards, we make sure it is
# installed before any other package (by way of setup_board), but for the sdk
# board, we don't have that toolchain-specific tweak.  So we end up installing
# these in parallel and the chroot logic for font generation fails.  We can
# drop this when we stop executing the helper in the $ROOT via `chroot` and/or
# `qemu` (e.g. when we do `ROOT=/build/amd64-host/ emerge chromeos-fonts`).
#
# The gcc-libs requirement is a similar situation.  Ultimately this comes down
# to fixing http://crbug.com/205424.
DEPEND="
	internal? (
		chromeos-base/monotype-fonts:=
		chromeos-base/google-sans-fonts:=
	)
	media-fonts/croscorefonts:=
	media-fonts/crosextrafonts:=
	media-fonts/crosextrafonts-carlito:=
	media-fonts/noto-cjk:=
	media-fonts/notofonts:=
	media-fonts/ko-nanumfonts:=
	media-fonts/lohitfonts-cros:=
	media-fonts/robotofonts:=
	media-fonts/tibt-jomolhari:=
	media-libs/fontconfig:=
	!cros_host? ( sys-libs/gcc-libs:= )
	cros_host? ( sys-libs/glibc:= )
	"
RDEPEND="${DEPEND}"

BDEPEND="chromeos-base/minijail"

S=${WORKDIR}

# The following code uses sudo to generate the font-cache.  It is almost
# always not a good idea to use sudo in your ebuild.  This ebuild is an
# exception for the following reasons:
#
# - fc-cache was designed with the generic linux distribution use case
#   in mind where package maintainers have no idea what fonts are actually
#   installed on the system.  As a result fc-cache operates directly on
#   the target file system and needs permission to modify its cache
#   directory (/usr/share/cache/fontconfig).
# - /usr/share/cache/fontconfig normally is owned by root, but for various
#   reasons, we bind mount our own work directory on top of it. The bind
#   mounting requires root privileges.
# - When cross-compiling, the generated font caches need to be compatible
#   with the architecture on which they will be used.  To properly do
#   this, we need to run the architecture appropriate copy of fc-cache,
#   which may link against other arch-specific libraries, which means
#   we need to chroot it in the board sysroot and chrooting requires
#   root permissions.
#
# By themselves the above reasons are not sufficient to justify using sudo in
# the ebuild.  What makes this OK is that fc-cache takes a really long time
# when run under qemu for ARM (4 - 7 minutes), which is a very large percentage
# of the overall time spent in build_image. It doesn't make sense to force each
# developer to spend a bunch of time generating the exact same font cache on
# their machine every time they want to build an image.  And even then, we can
# only do this because chromeos-fonts is a specialized ebuild for Chrome OS
# only.
#
# All of which is to say: don't use sudo in your ebuild.  You have been
# warned.  -- chirantan
generate_font_cache() {
	mkdir -p "${WORKDIR}/out" || die

	# Run fc-cache in a mount namespace, to handle isolation and graceful
	# cleanup.
	#
	# platform2_test: helpful because it's a pain to open-code QEMU usage
	#   (needed for ARCHes that don't match the build system).
	# minijail0: helpful because platform2_test does not provide custom
	#   bind-mounting facilities.
	#   -v: mount namespace
	#   -K: don't change root mount propagation (not possible in a chroot,
	#     where chroot isn't a mount)
	#   -k ... 0x5000: MS_BIND|MS_PRIVATE
	local jail_args=(
		-vK
		-k "${WORKDIR}/out,${SYSROOT}/usr/share/cache/fontconfig,none,0x5000"
	)
	if [[ "${ARCH}" == "amd64" ]]; then
		# Special-case for amd64: the target ISA may not match our
		# build host (so we can't run natively;
		# https://crbug.com/856686), and we may not have QEMU support
		# for the full ISA either. Just run the SDK binary instead.
		sudo minijail0 "${jail_args[@]}" \
			/usr/bin/fc-cache -f -v --sysroot "${SYSROOT:-/}" || die

	else
		sudo minijail0 "${jail_args[@]}" \
			"${CHROOT_SOURCE_ROOT}"/src/platform2/common-mk/platform2_test.py \
			--sysroot "${SYSROOT}" -- /usr/bin/fc-cache -f -v || die
	fi
}

# TODO(cjmcdonald): crbug/913317 These .uuid files need to exist when fc-cache
#                   is run otherwise fontconfig tries to write them to the font
#                   directories and generates portage sandbox violations.
#                   Additionally, the .uuid files need to be installed as part
#                   of this package so that they exist when this package is
#                   installed as a binpkg. Remove this section once fontconfig
#                   no longer uses these .uuid files.
pkg_setup() {
	local fontdir fontdirs=( $(cd "${SYSROOT}"/usr/share/fonts; echo */) )
	for fontdir in "${fontdirs[@]}"; do
		uuidgen --sha1 -n @dns -N "$(usev cros_host)${fontdir}" > \
			"${SYSROOT}"/usr/share/fonts/"${fontdir}"/.uuid
	done
}

src_compile() {
	generate_font_cache
}

src_install() {
	insinto /usr/share/cache/fontconfig
	doins "${WORKDIR}"/out/*

	local fontdir fontdirs=( $(cd "${SYSROOT}"/usr/share/fonts; echo */) )
	for fontdir in "${fontdirs[@]}"; do
		insinto "/usr/share/fonts/${fontdir}"
		uuidgen --sha1 -n @dns -N "$(usev cros_host)${fontdir}" | newins - .uuid
	done
}
