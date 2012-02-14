#!/usr/bin/perl

# Copyright 2011 Mark Gavillet & PTFS Europe Ltd
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

use strict;
use warnings;
use CGI;
use C4::Context;
use C4::Auth;
use C4::Output;
use C4::Members;
use C4::Koha;
use C4::Branch;
use C4::Housebound;

use vars qw($debug);

BEGIN {
    $debug = $ENV{DEBUG} || 0;
}

my $input = CGI->new();

sub nl2br {
    my ($t) = shift or return;
    $t =~ s/\n/\n<br>/g;
    return ($t);
}

my $dbh = C4::Context->dbh;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {   template_name   => "members/housebound.tmpl",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { borrowers => 1 },
        debug           => ($debug) ? 1 : 0,
    }
);

my $borrowernumber = $input->param('borrowernumber');

my $borrowerdetails      = C4::Members::GetMemberDetails($borrowernumber);
my $branchdetail         = GetBranchDetail( $borrowerdetails->{'branchcode'} );
my $categorydetail       = GetMember( $borrowernumber, 'borrowernumber' );
my $housebound           = GetHouseboundDetails($borrowernumber);
my $housebound_instances = GetCurrentHouseboundInstanceList($borrowernumber);

$template->param(
    surname        => $borrowerdetails->{'surname'},
    firstname      => $borrowerdetails->{'firstname'},
    cardnumber     => $borrowerdetails->{'cardnumber'},
    borrowernumber => $borrowerdetails->{'borrowernumber'},
    houseboundview => 'on',
    address        => $borrowerdetails->{'address'},
    address2       => $borrowerdetails->{'address2'},
    city           => $borrowerdetails->{'city'},
    phone          => $borrowerdetails->{'phone'},
    phonepro       => $borrowerdetails->{'phonepro'},
    mobile         => $borrowerdetails->{'mobile'},
    email          => $borrowerdetails->{'email'},
    emailpro       => $borrowerdetails->{'emailpro'},
    categoryname   => $categorydetail->{'description'},
    categorycode   => $borrowerdetails->{'categorycode'},
    branch         => $borrowerdetails->{'branch'},
    branchname     => $branchdetail->{branchname},
    zipcode        => $borrowerdetails->{'zipcode'}
);

$template->param(
    hbnumber     => $housebound->{'hbnumber'},
    day          => $housebound->{'day'},
    frequency    => $housebound->{'frequency'},
    Itype_quant  => $housebound->{'Itype_quant'},
    Item_subject => $housebound->{'Item_subject'},
    Item_authors => $housebound->{'Item_authors'},
    referral     => $housebound->{'referral'},
    notes        => $housebound->{'notes'}
);

if ($housebound_instances) {
    $template->param( instanceloop => $housebound_instances );
}

output_html_with_http_headers $input, $cookie, $template->output;

