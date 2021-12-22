# Copyright (c) 2018 The Chromium OS Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI="6"

inherit autotools eutils user

DESCRIPTION="The USBGuard software framework helps to protect your computer against rogue USB devices (a.k.a. BadUSB) by implementing basic whitelisting and blacklisting capabilities based on device attributes."
HOMEPAGE="https://usbguard.github.io/"
GIT_REV="4957d2d0bc4c2ed4529e8b69f9813c735d51a69a"
CATCH_REV="35f510545d55a831372d3113747bf1314ff4f2ef"
PEGTL_REV="ecec1f68d5ddae123aa7fb82b88abc1e03dd3587"
SRC_URI="https://github.com/USBGuard/usbguard/archive/${GIT_REV}.tar.gz -> ${P}.tar.gz
https://github.com/catchorg/Catch2/archive/${CATCH_REV}.tar.gz -> ${PN}-201807-catch.tar.gz
https://github.com/taocpp/PEGTL/archive/${PEGTL_REV}.tar.gz -> ${PN}-20190808-pegtl.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="*"
IUSE="cfm_enabled_device hammerd"

COMMON_DEPEND="
	dev-libs/dbus-glib
	dev-libs/libgcrypt
	dev-libs/protobuf:=
	sys-apps/dbus
	sys-cluster/libqb"

DEPEND="${COMMON_DEPEND}"

RDEPEND="${COMMON_DEPEND}"

S="${WORKDIR}/usbguard-${GIT_REV}/"

PATCHES=(
	"${FILESDIR}/daemon_conf.patch"
	"${FILESDIR}/dbus.patch"
	"${FILESDIR}/disable_optional.patch"
)

src_prepare() {
	rm -rf "${S}/src/ThirdParty/Catch"
	mv "${WORKDIR}/Catch2-${CATCH_REV}" "${S}/src/ThirdParty/Catch"

	rm -rf "${S}/src/ThirdParty/PEGTL"
	mv "${WORKDIR}/PEGTL-${PEGTL_REV}" "${S}/src/ThirdParty/PEGTL"

	default
	eautoreconf
}

src_configure() {
	cros_enable_cxx_exceptions
	econf \
		--without-polkit \
		--without-ldap \
		--with-dbus \
		--with-bundled-catch \
		--with-bundled-pegtl \
		--with-crypto-library=gcrypt \
		--disable-audit \
		--disable-libcapng \
		--disable-seccomp \
		--disable-umockdev
}

src_install() {
	emake DESTDIR="${D}" install
	# Cleanup unwanted files from the emake install command.
	rm "${D}/etc/usbguard/rules.conf" || die
	rm "${D}/usr/share/dbus-1/system.d/org.usbguard1.conf" || die

	insinto /etc/usbguard/rules.d
	use cfm_enabled_device && doins "${FILESDIR}/50-cfm-rules.conf"
	use hammerd && doins "${FILESDIR}/50-hammer-rules.conf"
	doins "${FILESDIR}/99-rules.conf"

	insinto /usr/share/policy
	newins "${FILESDIR}/usbguard-daemon-seccomp-${ARCH}.policy" usbguard-daemon-seccomp.policy

	insinto /etc/init
	doins "${FILESDIR}"/usbguard.conf
	doins "${FILESDIR}"/usbguard-wrapper.conf

	insinto /usr/share/dbus-1/interfaces
	newins "${S}/src/DBus/DBusInterface.xml" org.usbguard1.xml

	insinto /etc/dbus-1/system.d
	doins "${FILESDIR}/org.usbguard1.conf"

	insinto /etc/usbguard
	insopts -o usbguard -g usbguard -m600
	doins usbguard-daemon.conf
}

pkg_setup() {
	enewuser usbguard
	enewgroup usbguard
}
