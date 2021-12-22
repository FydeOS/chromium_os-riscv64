# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=5
inherit autotools eutils

DESCRIPTION="Connection tracking userspace tools"
HOMEPAGE="http://conntrack-tools.netfilter.org"
SRC_URI="http://www.netfilter.org/projects/conntrack-tools/files/${P}.tar.bz2"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS=*
IUSE="doc +libtirpc +seccomp"

RDEPEND="
	>=net-libs/libmnl-1.0.3
	>=net-libs/libnetfilter_conntrack-1.0.6
	>=net-libs/libnetfilter_cthelper-1.0.0
	>=net-libs/libnetfilter_cttimeout-1.0.0
	>=net-libs/libnetfilter_queue-1.0.2
	>=net-libs/libnfnetlink-1.0.1
	!libtirpc? ( sys-libs/glibc[rpc(-)] )
	libtirpc? ( net-libs/libtirpc )
"
DEPEND="
	${RDEPEND}
	doc? (
		app-text/docbook-xml-dtd:4.1.2
		app-text/xmlto
	)
	virtual/pkgconfig
	sys-devel/bison
	sys-devel/flex
"

src_prepare() {
	default

	# bug #474858
	sed -i -e 's:/var/lock:/run/lock:' doc/stats/conntrackd.conf || die

	epatch "${FILESDIR}"/${P}-mdns-helper.patch
	epatch "${FILESDIR}"/${P}-lazy-binding.patch
	epatch "${FILESDIR}"/${P}-upnp-helper.patch
	epatch "${FILESDIR}"/${P}-pktb-memory-leak.patch
	epatch "${FILESDIR}"/${P}-rpc.patch
	eautoreconf
}

src_configure() {
	econf $(use_with libtirpc)
}

src_compile() {
	default
	use doc && emake -C doc/manual
}

src_install() {
	default

	insinto /etc/conntrackd
	doins "${FILESDIR}/conntrackd.conf"

	insinto /etc/init
	doins "${FILESDIR}/init/conntrackd.conf"

	insinto /usr/share/policy/
	use seccomp && newins "${FILESDIR}/conntrackd-seccomp-${ARCH}.policy" \
		conntrackd-seccomp.policy
}
