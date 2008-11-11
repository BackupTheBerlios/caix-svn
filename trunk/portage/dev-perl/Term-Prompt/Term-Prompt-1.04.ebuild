# Copyright 1999-2006 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# This ebuild generated by g-cpan 0.15.0

inherit perl-module

S=${WORKDIR}/Term-Prompt-1.04

DESCRIPTION="Prompt a user"
HOMEPAGE="http://search.cpan.org/search?query=Term-Prompt&mode=dist"
SRC_URI="mirror://cpan/authors/id/P/PE/PERSICOM/Term-Prompt-1.04.tar.gz"


IUSE=""

SLOT="0"
LICENSE="|| ( Artistic GPL-2 )"
KEYWORDS="~x86"

DEPEND=">=dev-perl/TermReadKey-2.30
	dev-lang/perl"
