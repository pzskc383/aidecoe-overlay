# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=5

inherit eutils pam rebar ssl-cert systemd

DESCRIPTION="Robust, Scalable and Extensible XMPP Server"
HOMEPAGE="http://www.ejabberd.im/ https://github.com/processone/ejabberd/"
SRC_URI="http://www.process-one.net/downloads/${PN}/${PV}/${P}.tgz
	-> ${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"
REQUIRED_USE="mssql? ( odbc )"
# TODO: Add 'tools' flag.
IUSE="captcha debug full-xml hipe ldap mssql mysql nls odbc pam postgres redis
	riak roster-gw sqlite zlib"

RESTRICT="test"

# TODO: Add dependencies for 'tools' flag enabled.
# TODO: tools? (
# TODO: 	>=dev-erlang/meck-0.8.4
# TODO: 	>=dev-erlang/moka-1.0.5b
# TODO: )
DEPEND=">=dev-erlang/lager-3.0.2
	>=dev-erlang/p1_utils-1.0.4
	>=dev-erlang/cache_tab-1.0.2
	>=dev-erlang/fast_tls-1.0.3
	>=dev-erlang/stringprep-1.0.3
	>=dev-erlang/fast_xml-1.1.3
	>=dev-erlang/stun-1.0.3
	>=dev-erlang/esip-1.0.4
	>=dev-erlang/fast_yaml-1.0.3
	>=dev-erlang/jiffy-0.14.7
	>=dev-erlang/p1_oauth2-0.6.1
	>=dev-erlang/p1_xmlrpc-1.15.1
	>=dev-erlang/luerl-0.2
	>=dev-lang/erlang-17.1[hipe?,odbc?,ssl]
	>=net-im/jabber-base-0.01
	ldap? ( =net-nds/openldap-2* )
	mysql? ( >=dev-erlang/p1_mysql-1.0.1 )
	nls? ( >=dev-erlang/iconv-1.0.0 )
	odbc? ( dev-db/unixODBC )
	pam? ( >=dev-erlang/p1_pam-1.0.0 )
	postgres? ( >=dev-erlang/p1_pgsql-1.1.0 )
	redis? ( >=dev-erlang/eredis-1.0.8 )
	riak? (
		>=dev-erlang/hamcrest-0.1.0_p20150103
		>=dev-erlang/riakc-2.1.1_p20151111
	)
	sqlite? ( >=dev-erlang/sqlite3-1.1.5 )
	zlib? ( >=dev-erlang/ezlib-1.0.1 )"
RDEPEND="${DEPEND}
	captcha? ( media-gfx/imagemagick[truetype,png] )"

# Paths in net-im/jabber-base
JABBER_ETC="${EPREFIX}/etc/jabber"
JABBER_LOG="${EPREFIX}/var/log/jabber"
JABBER_SPOOL="${EPREFIX}/var/spool/jabber"

src_prepare() {
	epatch "${FILESDIR}/${P}-ejabberdctl.patch"

	rebar_remove_deps

	# Set paths to defined by net-im/jabber-base.
	sed -e "/^EJABBERDDIR[[:space:]]*=/{s:ejabberd:${PF}:}" \
		-e "/^ETCDIR[[:space:]]*=/{s:@sysconfdir@/ejabberd:${JABBER_ETC}:}" \
		-e "/^LOGDIR[[:space:]]*=/{s:@localstatedir@/log/ejabberd:${JABBER_LOG}:}" \
		-e "/^SPOOLDIR[[:space:]]*=/{s:@localstatedir@/lib/ejabberd:${JABBER_SPOOL}:}" \
		-i Makefile.in || die
	sed -e "/EJABBERDDIR=/{s:ejabberd:${PF}:}" \
		-e "s|\(ETC_DIR=\){{sysconfdir}}.*|\1${JABBER_ETC}|" \
		-e "s|\(LOGS_DIR=\){{localstatedir}}.*|\1${JABBER_LOG}|" \
		-e "s|\(SPOOL_DIR=\){{localstatedir}}.*|\1${JABBER_SPOOL}|" \
		-i ejabberdctl.template || die

	# Use our sample certificates.
	# Correct PAM service name.
	# Correct path to captcha script in example ejabberd.yml.
	sed -e "s|/path/to/ssl.pem|/etc/ssl/ejabberd/server.pem|g" \
		-e "s|pamservicename|xmpp|" \
		-e 's|\({captcha_cmd,[[:space:]]*"\).\+"}|\1/usr/'$(get_erl_libs)'/'${P}'/priv/bin/captcha.sh"}|' \
		-i ejabberd.yml.example || die

	epatch_user
}

src_configure() {
	econf \
		--docdir="${EPREFIX}/usr/share/doc/${PF}/html" \
		$(use_enable hipe) \
		$(use_enable roster-gw roster-gateway-workaround) \
		$(use_enable full-xml) \
		$(use_enable mssql) \
		$(use_enable odbc) \
		$(use_enable mysql) \
		$(use_enable postgres pgsql) \
		$(use_enable sqlite) \
		$(use_enable pam) \
		$(use_enable zlib) \
		$(use_enable riak) \
		$(use_enable redis) \
		$(use_enable nls iconv) \
		$(use_enable debug) \
		--enable-user=jabber
}

src_compile() {
	emake src
}

src_install() {
	default

	if use pam; then
		# PAM helper module permissions
		# https://www.process-one.net/docs/ejabberd/guide_en.html#pam
		pamd_mimic_system xmpp auth account || die "cannot create pam.d file"
		install -D -m 4750 -g jabber \
			-t "${ED}$(get_erl_libs)/${PF}/priv/bin/" \
			"${EPREFIX}$(get_erl_libs)"/p1_pam-*/priv/bin/epam \
			|| die "failed to copy epam bin from p1_pam"
	fi

	newinitd "${FILESDIR}/${PN}.initd" "${PN}"
	newconfd "${FILESDIR}/${PN}.confd" "${PN}"
	systemd_dounit "${FILESDIR}/${PN}.service"
	systemd_dotmpfilesd "${FILESDIR}/${PN}.tmpfiles.conf"

	insinto /etc/logrotate.d
	newins "${FILESDIR}/${PN}.logrotate" "${PN}"
}

pkg_postinst() {
	if [[ ! ${REPLACING_VERSIONS} ]]; then
		elog "For configuration instructions, please see"
		elog "  /usr/share/doc/${PF}/html/guide.html"
		elog "or the online version at"
		elog "  http://www.process-one.net/en/ejabberd/docs/"
	elif [[ -f ${EROOT}/etc/jabber/ejabberd.cfg ]]; then
		elog "Ejabberd now defaults to using a YAML format for its config file."
		elog "The old ejabberd.cfg file can be converted using the following instructions:"
		echo
		elog "1. Make sure all processes related to the previous version of ejabberd aren't"
		elog "   running. Usually this just means the ejabberd and epmd daemons and possibly"
		elog "   the pam-related process (epam) if pam support is enabled."
		elog "2. Run \`ejabberdctl start\` with sufficient permissions. Note that this can"
		elog "   fail to start ejabberd properly for various reasons. Check ejabberd's main"
		elog "   log file at /var/log/jabber/ejabberd.log to confirm it started successfully."
		elog "3. Run"
		elog "     \`ejabberdctl convert_to_yaml /etc/jabber/ejabberd.cfg /etc/jabber/ejabberd.yml.new\`"
		elog "   with sufficient permissions, edit and rename /etc/jabber/ejabberd.yml.new to"
		elog "   /etc/jabber/ejabberd.yml, and finally restart ejabberd with the new config"
		elog "   file."
		echo
	fi

	SSL_ORGANIZATION="${SSL_ORGANIZATION:-ejabberd XMPP Server}"
	install_cert /etc/ssl/ejabberd/server
	# Fix ssl cert permissions (bug #369809).
	chown root:jabber "${EROOT}/etc/ssl/ejabberd/server.pem"
	chmod 0440 "${EROOT}/etc/ssl/ejabberd/server.pem"
}
