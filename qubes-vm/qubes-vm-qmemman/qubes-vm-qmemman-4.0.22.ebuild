# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit systemd

MY_PN="qubes-linux-utils"
MY_P="${MY_PN}-${PV}"

DESCRIPTION="Qubes memory information reporter"
HOMEPAGE="https://www.qubes-os.org/"
SRC_URI="https://github.com/QubesOS/${MY_PN}/archive/v${PV}.tar.gz -> ${MY_P}.tar.gz"

LICENSE="GPL-2+"
SLOT="0"
KEYWORDS="~amd64"
IUSE=""

S="${WORKDIR}/${MY_P}/qmemman"

CDEPEND="qubes-vm/qubes-libvchan-xen"
DEPEND="${CDEPEND}
	virtual/pkgconfig"
RDEPEND="${CDEPEND}"

src_install() {
	dosbin meminfo-writer
	systemd_dounit qubes-meminfo-writer.service
	systemd_dounit qubes-meminfo-writer-dom0.service
}
