# Copyright 2008 Andreas Leipelt
# Distributed under the terms of the GNU General Public License v2

inherit perl-module

DESCRIPTION="Certificate Service Provider, a simple PKI toolkit of the Stockholm University"
HOMEPAGE="http://devel.it.su.se/pub/jsp/polopoly.jsp?d=1026&a=3290"
SRC_URI="ftp://ftp.su.se/pub/users/leifj/${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~x86"
IUSE=""

DEPEND="dev-perl/Date-Calc
        dev-perl/IPC-Run
        dev-perl/Term-Prompt"

RDEPEND="${DEPEND}"

src_install() {
    perl-module_src_install
    dodir /usr/share/${P}/ca/etc/public_html/certs
    insinto /usr/share/${P}/ca/etc
    doins "${S}/ca/etc/aliases.txt"
    doins "${S}/ca/etc/types.txt"
    doins "${S}/ca/etc/crl_extensions.conf"
    doins "${S}/ca/etc/oids.conf"
    doins "${FILESDIR}/extensions.conf"
    insinto /usr/share/${P}/ca/etc/public_html
    doins "${S}/ca/etc/public_html/index.html.mpp"
    insinto /usr/share/${P}/ca/etc/public_html/certs
    doins "${S}/ca/etc/public_html/certs/expired.html.mpp"
    doins "${S}/ca/etc/public_html/certs/valid.html.mpp"
    doins "${S}/ca/etc/public_html/certs/revoked.html.mpp"
    doins "${S}/ca/etc/public_html/certs/cert.html.mpp"
    doins "${S}/ca/etc/public_html/certs/index.html.mpp"
    ln -sf /usr/share/${P} /usr/share/CSP
}
