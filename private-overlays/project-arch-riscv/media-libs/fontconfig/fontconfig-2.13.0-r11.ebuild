# Copyright 1999-2018 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=6

# CrOS change.
# eapi-ver7.eclass is not present. Drop it as well as check for the
# 3rd component of version number >= 90, '[[ $(ver_cut 3) -ge 90 ]]'
# before the KEYWORDS line.
# The 3rd component of fontconfig version >= 90 indicates that it's a release
# candidate.
inherit autotools multilib-minimal readme.gentoo-r1

DESCRIPTION="A library for configuring and customizing font access"
HOMEPAGE="https://fontconfig.org/"
SRC_URI="https://fontconfig.org/release/${P}.tar.bz2"

LICENSE="MIT"
SLOT="1.0"
KEYWORDS="*"
IUSE="cros_host doc static-libs +subpixel_rendering touchview"

# Purposefully dropped the xml USE flag and libxml2 support.  Expat is the
# default and used by every distro.  See bug #283191.
RDEPEND=">=dev-libs/expat-2.1.0-r3[${MULTILIB_USEDEP}]
	>=media-libs/freetype-2.9[${MULTILIB_USEDEP}]
	!elibc_Darwin? ( sys-apps/util-linux[${MULTILIB_USEDEP}] )
	elibc_Darwin? ( sys-libs/native-uuid )
	virtual/libintl[${MULTILIB_USEDEP}]"
DEPEND="${RDEPEND}
	virtual/pkgconfig
	>=sys-devel/gettext-0.19.8
	doc? ( =app-text/docbook-sgml-dtd-3.1*
		app-text/docbook-sgml-utils[jadetex] )"
# CrOS change: we don't need fontconfig eselect.
PDEPEND="virtual/ttf-fonts"

PATCHES=(
	"${FILESDIR}"/${PN}-2.10.2-docbook.patch # 310157
	"${FILESDIR}"/${P}-fonts-config.patch
	"${FILESDIR}"/${P}-locale.patch #650332
	"${FILESDIR}"/${P}-mtime.patch
	"${FILESDIR}"/${P}-names.patch #650370
	"${FILESDIR}"/${P}-fccache-sysroot.patch
	"${FILESDIR}"/${P}-fc-cache-doesn-t-use-y-option.patch # crbug.com/907781
)

# Checks that a passed-in fontconfig default symlink (e.g. "10-autohint.conf")
# is present and dies if it isn't.
check_fontconfig_default() {
	local path="${D}"/etc/fonts/conf.d/"$1"
	if [[ ! -L ${path} ]]; then
		die "Didn't find $1 among default fontconfig settings (at ${path})."
	fi
}

MULTILIB_CHOST_TOOLS=( /usr/bin/fc-cache$(get_exeext) )

pkg_setup() {
	DOC_CONTENTS="Please make fontconfig configuration changes using
	\`eselect fontconfig\`. Any changes made to /etc/fonts/fonts.conf will be
	overwritten. If you need to reset your configuration to upstream defaults,
	delete the directory ${EROOT%/}/etc/fonts/conf.d/ and re-emerge fontconfig."
}

src_prepare() {
	default
	export GPERF=$(type -P true)  # avoid dependency on gperf, #631980
	sed -i -e 's/FC_GPERF_SIZE_T="unsigned int"/FC_GPERF_SIZE_T=size_t/' \
		configure.ac || die # rest of gperf dependency fix, #631920
	eautoreconf
	rm test/out.expected || die #662048
}

multilib_src_configure() {
  cros_use_gcc
	cros_optimize_package_for_speed

	local addfonts
	# harvest some font locations, such that users can benefit from the
	# host OS's installed fonts
	case ${CHOST} in
		*-darwin*)
			addfonts=",/Library/Fonts,/System/Library/Fonts"
		;;
		*-solaris*)
			[[ -d /usr/X/lib/X11/fonts/TrueType ]] && \
				addfonts=",/usr/X/lib/X11/fonts/TrueType"
			[[ -d /usr/X/lib/X11/fonts/Type1 ]] && \
				addfonts="${addfonts},/usr/X/lib/X11/fonts/Type1"
		;;
		*-linux-gnu)
			use prefix && [[ -d /usr/share/fonts ]] && \
				addfonts=",/usr/share/fonts"
		;;
	esac

	local myeconfargs=(
		$(use_enable doc docbook)
		$(use_enable static-libs static)
		--enable-docs
		# Font cache should be in /usr/share/cache instead of /var/cache
		# because the latter is not in the read-only partition.
		--localstatedir="${EPREFIX}"/usr/share
		--with-default-fonts="${EPREFIX}"/usr/share/fonts
		--with-add-fonts="${EPREFIX}/usr/local/share/fonts${addfonts}"
		--with-templatedir="${EPREFIX}"/etc/fonts/conf.avail
	)

	ECONF_SOURCE="${S}" \
	econf "${myeconfargs[@]}"
}

multilib_src_install() {
	default

	# avoid calling this multiple times, bug #459210
	if multilib_is_native_abi; then
		# stuff installed from build-dir
		emake -C doc DESTDIR="${D}" install-man

		insinto /etc/fonts
		doins fonts.conf
	fi
}

multilib_src_install_all() {
	einstalldocs
	find "${ED}" -name "*.la" -delete || die

	insinto /etc/fonts
	doins "${FILESDIR}"/local.conf
	# Enable autohint by default
	# match what we want to use.
	dosym ../conf.avail/10-autohint.conf /etc/fonts/conf.d/10-autohint.conf
	check_fontconfig_default 10-autohint.conf

	# Make sure that hinting-slight is on.
	check_fontconfig_default 10-hinting-slight.conf

	# Set sub-pixel mode to RGB
	dosym ../conf.avail/10-sub-pixel-rgb.conf \
		/etc/fonts/conf.d/10-sub-pixel-rgb.conf
	check_fontconfig_default 10-sub-pixel-rgb.conf

	# Use the default LCD filter
	dosym ../conf.avail/11-lcdfilter-default.conf \
		/etc/fonts/conf.d/11-lcdfilter-default.conf
	check_fontconfig_default 11-lcdfilter-default.conf

	# CrOS: Delete unnecessary configurtaion files
	local confs_to_delete=(
		"20-unhint-small-vera"
		"40-nonlatin"
		"45-latin"
		"50-user"
		"60-latin"
		"65-fonts-persian"
		"65-nonlatin"
		"69-unifont"
		"80-delicious"
	)

	local conf
	for conf in "${confs_to_delete[@]}"; do
		rm -f "${D}"/etc/fonts/conf.d/"${conf}".conf
	done

	# There's a lot of variability across different displays with subpixel
	# rendering. Until we have a better solution, turn it off and use grayscale
	# instead on boards that don't have internal displays.
	#
	# Additionally, disable it for convertible devices with rotatable displays
	# (http://crbug.com/222208) and when installing to the host sysroot so the
	# images in the initramfs package won't use subpixel rendering
	# (http://crosbug.com/27872).
	if ! use subpixel_rendering || use touchview || use cros_host; then
		rm "${D}"/etc/fonts/conf.d/10-sub-pixel-rgb.conf
		rm "${D}"/etc/fonts/conf.d/11-lcdfilter-default.conf
		dosym ../conf.avail/10-no-sub-pixel.conf \
			/etc/fonts/conf.d/10-no-sub-pixel.conf
		check_fontconfig_default 10-no-sub-pixel.conf
	fi

	dodoc doc/fontconfig-user.{txt,pdf}

	if [[ -e ${ED}usr/share/doc/fontconfig/ ]];  then
		mv "${ED}"usr/share/doc/fontconfig/* "${ED}"/usr/share/doc/${P} || die
		rm -rf "${ED}"usr/share/doc/fontconfig
	fi

	# Changes should be made to /etc/fonts/local.conf, and as we had
	# too much problems with broken fonts.conf we force update it ...
	echo 'CONFIG_PROTECT_MASK="/etc/fonts/fonts.conf"' > "${T}"/37fontconfig
	doenvd "${T}"/37fontconfig

	# As of fontconfig 2.7, everything sticks their noses in here.
	# Replace /var/cache with /usr/share/cache for CrOS.
	dodir /etc/sandbox.d
	echo 'SANDBOX_PREDICT="/usr/share/cache/fontconfig"' > "${ED}"/etc/sandbox.d/37fontconfig

	readme.gentoo_create_doc
}

pkg_postinst() {
	einfo "Cleaning broken symlinks in ${EROOT%/}/etc/fonts/conf.d/"
	find -L "${EROOT}"etc/fonts/conf.d/ -type l -delete

	readme.gentoo_print_elog

	if [[ ${ROOT} = / ]]; then
		multilib_pkg_postinst() {
			ebegin "Creating global font cache for ${ABI}"
			"${EPREFIX}"/usr/bin/${CHOST}-fc-cache -srf
			eend $?
		}

		multilib_parallel_foreach_abi multilib_pkg_postinst
	fi
}
