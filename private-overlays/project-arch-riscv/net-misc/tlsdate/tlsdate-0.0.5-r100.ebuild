# Copyright 2012 The Chromium OS Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="6"
CROS_WORKON_COMMIT="f6185658498aa903ff47c9eb46e7ccd7f95c74da"
CROS_WORKON_TREE="aadb9cf0c326d4d0b1e9fd4d12b0192cdba2d8f8"
CROS_WORKON_PROJECT="chromiumos/third_party/tlsdate"
CROS_WORKON_EGIT_BRANCH=master

inherit autotools flag-o-matic toolchain-funcs cros-sanitizers cros-workon cros-debug systemd user

DESCRIPTION="Update local time over HTTPS"
HOMEPAGE="https://github.com/ioerror/tlsdate"

LICENSE="BSD"
SLOT="0"
KEYWORDS="*"
IUSE="-asan +dbus +seccomp systemd"

DEPEND="dev-libs/openssl:0=
	dev-libs/libevent
	dbus? ( sys-apps/dbus )"
RDEPEND="${DEPEND}
	chromeos-base/chromeos-ca-certificates
"

src_prepare() {
	# Use the system cert store rather than a custom one specific
	# to the tlsdate package. #534394
	sed -i \
		-e 's:/tlsdate/ca-roots/tlsdate-ca-roots.conf:/ssl/certs/ca-certificates.crt:' \
		Makefile.am || die

	default

	eautoreconf
}

src_configure() {
	sanitizers-setup-env
	cros-debug-add-NDEBUG
	econf \
		$(use_enable dbus) \
		$(use_enable seccomp seccomp-filter) \
		$(use_enable cros-debug seccomp-debugging) \
		--enable-cros \
		--with-dbus-client-group=chronos \
		--with-unpriv-user=tlsdate \
		--with-unpriv-group=tlsdate
}

src_compile() {
	tc-export CC
	emake CFLAGS="-Wall -Werror ${CFLAGS} ${CPPFLAGS} ${LDFLAGS}"
}

src_install() {
	default

	# Use the system cert store; see src_prepare. #446426 #534394
	rm "${ED}"/etc/tlsdate/ca-roots/tlsdate-ca-roots.conf || die
	rmdir "${ED}"/etc/tlsdate/ca-roots || die

	insinto /etc/tlsdate
	doins "${FILESDIR}/tlsdated.conf"
	insinto /etc/dbus-1/system.d
	doins "${S}/dbus/org.torproject.tlsdate.conf"
	insinto /usr/share/dbus-1/interfaces
	doins "${S}/dbus/org.torproject.tlsdate.xml"
	insinto /usr/share/dbus-1/services
	doins "${S}/dbus/org.torproject.tlsdate.service"

	if use systemd; then
		systemd_dounit init/tlsdated.service
		systemd_enable_service system-services.target tlsdated.service
		systemd_dotmpfilesd init/tlsdated-directories.conf
	else
		insinto /etc/init
		doins init/tlsdated.conf
	fi
}

pkg_preinst() {
	enewuser "tlsdate"
	enewgroup "tlsdate"
	enewuser "tlsdate-dbus"   # For tlsdate-dbus-announce.
	enewgroup "tlsdate-dbus"  # For tlsdate-dbus-announce.
}

PATCHES=( "${FILESDIR}/arch-riscv.patch" )
