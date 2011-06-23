#!/usr/bin/perl

# Copyright 2009-2010 Kyle Hall
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

#use strict;
#use warnings;

BEGIN {
    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}

use C4::Reserves;

# expire all waiting hold requests after 7 days

=head2 ExpireWaitingReserves

  ExpireWaitingReserves();

Expires all reserves with an waitingdate 7 days before today.

=cut

sub ExpireWaitingReserves {

	my $dbh = C4::Context->dbh;
	my $sth = $dbh->prepare( "
		SELECT * FROM reserves WHERE DATE(waitingdate) < DATE_SUB( CURDATE(), INTERVAL 7 DAY) AND found = 'W'
		" );
	$sth->execute();

	while ( my $res = $sth->fetchrow_hashref() ) {
		CancelReserve( $res->{'biblionumber'}, '', $res->{'borrowernumber'} );
	}
}
