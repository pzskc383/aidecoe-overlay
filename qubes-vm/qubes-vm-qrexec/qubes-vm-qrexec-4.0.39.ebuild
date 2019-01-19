# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit systemd tmpfiles user

MY_PN="qubes-core-agent-linux"
MY_P="${MY_PN}-${PV}"

DESCRIPTION="Qubes VM qrexec"
HOMEPAGE="https://www.qubes-os.org/"
SRC_URI="https://github.com/QubesOS/${MY_PN}/archive/v${PV}.tar.gz -> ${MY_P}.tar.gz"

LICENSE="GPL-2+"
SLOT="0"
KEYWORDS="~amd64"
IUSE=""

S="${WORKDIR}/${MY_P}/qrexec"

CDEPEND="qubes-vm/qubes-libvchan-xen
	qubes-vm/qubes-vm-qrexec-lib"
DEPEND="${CDEPEND}
	virtual/pkgconfig"
RDEPEND="${CDEPEND}"

PATCHES=( ${FILESDIR}/0001-Don-t-include-postlogin-in-pam-file.patch )

pkg_setup() {
	enewgroup qubes 98
}

src_compile() {
	BACKEND_VMM=xen default
}

src_install() {
	default
	systemd_dounit ../vm-systemd/qubes-qrexec-agent.service
	dotmpfiles "${FILESDIR}"/qubes-vm-qrexec.conf
}

pkg_postinst() {
	tmpfiles_process qubes-vm-qrexec.conf
}
