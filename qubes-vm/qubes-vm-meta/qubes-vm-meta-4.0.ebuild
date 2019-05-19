# Copyright 1999-2019 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="Qubes VM interaction with dom0 (meta package)"
HOMEPAGE="http://qubes-os.org/"
SRC_URI=""

LICENSE="metapackage"
SLOT="0"
KEYWORDS="~amd64"
IUSE=""

RDEPEND="qubes-vm/xf86-input-mfndev
	qubes-vm/xf86-video-dummy-qubes
	qubes-vm/qubes-vm-qmemman
	qubes-vm/qubes-core-agent
	qubes-vm/qubes-vm-udev
	qubes-vm/qubes-gui-agent"
