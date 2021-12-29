EAPI=7

DESCRIPTION="Workaround for obtaining various bits of low-level system info"
HOMEPAGE="http://mosys.googlecode.com/"

LICENSE="BSD-google"
SLOT="0/0"
KEYWORDS="*"
IUSE="unibuild vpd_file_cache"

RDEPEND=""

DEPEND="${RDEPEND}"

S=${FILESDIR}

src_install() {
  dosbin mosys
  insinto /usr/share/policy
  newins ${FILESDIR}/mosys-seccomp-riscv.policy mosys-seccomp.policy
}
