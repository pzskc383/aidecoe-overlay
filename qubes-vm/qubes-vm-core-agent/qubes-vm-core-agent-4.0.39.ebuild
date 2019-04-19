# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

PYTHON_COMPAT=( python2_7 )

inherit desktop distutils-r1 systemd udev

MY_PN="qubes-core-agent-linux"
MY_P="${MY_PN}-${PV}"

DESCRIPTION="Qubes VM core agent"
HOMEPAGE="https://www.qubes-os.org/"
SRC_URI="https://github.com/QubesOS/${MY_PN}/archive/v${PV}.tar.gz -> ${MY_P}.tar.gz"

LICENSE="GPL-2+"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+network"

S="${WORKDIR}/${MY_P}"

CDEPEND="app-emulation/xen-tools
	x11-libs/libX11
	virtual/pam"
DEPEND="${CDEPEND}
	dev-python/setuptools
	sys-apps/systemd[-resolvconf]
	virtual/pkgconfig"
RDEPEND="${CDEPEND}
	dev-python/python-daemon[${PYTHON_USEDEP}]
	dev-python/dbus-python[${PYTHON_USEDEP}]
	dev-python/pygobject:3[${PYTHON_USEDEP}]
	dev-python/pyxdg[${PYTHON_USEDEP}]
	gnome-base/dconf
	gnome-base/librsvg[tools]
	gnome-extra/zenity
	media-gfx/imagemagick
	sys-apps/ethtool
	sys-auth/polkit
	sys-block/parted
	qubes-vm/qubes-db-vm[python,${PYTHON_USEDEP}]
	qubes-vm/qubes-libvchan-xen
	qubes-vm/qubes-rpc
	qubes-vm/qubes-vm-qrexec
	x11-misc/xdg-utils
	x11-terms/xterm"

NETWORK_SERVICES=( vm-systemd/qubes-firewall.service
	vm-systemd/qubes-iptables.service
	vm-systemd/qubes-updates-proxy.service )
OTHER_PACKAGE_SERVICES=( vm-systemd/qubes-qrexec-agent.service )

sudoers_newins() (
	insopts -m 0440
	insinto /etc/sudoers.d
	newins "${@}"
)

systemd_dopreset() (
	local unitdir="$(systemd_get_systemunitdir)"
	local presetdir="${unitdir%/}-preset"
	insopts -m 0644
	insinto "${presetdir}"
	doins "${@}"
)

src_prepare() {
	default

	sed -e 's:/sbin/ifconfig:ifconfig:g' \
		-e 's:/sbin/route:route:g' \
		-e 's:/sbin/ethtool:ethtool:g' \
		-e 's:/sbin/ip:ip:g' \
		-e 's:/bin/grep:grep:g' \
		-e 's:/usr/sbin/qubes-firewall:/usr/bin/qubes-firewall:g' \
		-i network/* vm-systemd/*
}

src_compile() {
	distutils-r1_src_compile
	emake -C misc xenstore-watch close-window
}

src_install() {
	#$(MAKE) -C autostart-dropins install

	distutils-r1_src_install

	sudoers_newins misc/qubes.sudoers qubes
	sudoers_newins misc/sudoers.d_qt_x11_no_mitshm qt_x11_no_mitshm

	insinto /etc/sysctl.d
	doins misc/20_tcp_timestamps.conf

	newbin misc/xenstore-watch xenstore-watch-qubes

	udev_newrules misc/udev-qubes-misc.rules 50-qubes-misc.rules

	local qubeslibdir=/usr/lib/qubes

	exeinto "${qubeslibdir}"
	doexe misc/qubes-trigger-sync-appmenus.sh
	doexe misc/resize-rootfs
	doexe misc/close-window
	doexe misc/upgrades-installed-check
	doexe misc/upgrades-status-notify

	exeinto "${qubeslibdir}/init"
	doexe init/*.sh
	doexe vm-systemd/*.sh
	insinto "${qubeslibdir}/init"
	doins init/functions
	systemd_dopreset vm-systemd/75-qubes-vm.preset
	systemd_dounit vm-systemd/qubes-*.timer

	local service
	local ignore_services=" ${NETWORK_SERVICES[@]}"
	ignore_services+=" ${OTHER_PACKAGE_SERVICES[@]} "
	for  service in vm-systemd/qubes-*.service; do
		if ! [[ ${ignore_services} = *" ${service} "* ]]; then
			systemd_dounit "${service}"
		fi
	done

	insinto /etc/polkit-1/rules.d
	newins misc/polkit-1-qubes-allow-all.rules 00-qubes-allow-all.rules
	insinto /etc/polkit-1/localauthority/50-local.d
	newins misc/polkit-1-qubes-allow-all.pkla qubes-allow-all.pkla

	insinto /usr/share/qubes/mime-override/globs
	doins misc/mime-globs

	insinto /usr/share/glib-2.0/schemas
	doins misc/20_org.gnome.settings-daemon.plugins.updates.qubes.gschema.override
	doins misc/20_org.gnome.nautilus.qubes.gschema.override
	doins misc/20_org.mate.NotificationDaemon.qubes.gschema.override
	doins misc/20_org.gnome.desktop.wm.preferences.qubes.gschema.override

	insinto /usr/share/qubes
	doins misc/qubes-master-key.asc

	dobin misc/qubes-session-autostart
	dobin misc/qvm-features-request
	dobin misc/qubes-run-terminal
	dobin misc/qubes-desktop-run

	domenu misc/qubes-run-terminal.desktop

	insinto /etc/dconf/db/local.d
	newins misc/dconf-db-local-dpi dpi

	insinto /etc/X11
	doins misc/xorg-preload-apps.conf

	insinto /usr/lib/qubes-bind-dirs.d
	doins misc/30_cron.conf

	keepdir /rw
	keepdir /var/lib/qubes

	if use network; then
		systemd_dounit vm-systemd/qubes-updates-proxy-forwarder.socket
		systemd_dounit vm-systemd/qubes-updates-proxy-forwarder@.service
		udev_newrules network/udev-qubes-network.rules 99-qubes-network.rules

		exeinto "${qubeslibdir}"
		doexe network/setup-ip
	fi
}

pkg_postint() {
	udev_reload
}
