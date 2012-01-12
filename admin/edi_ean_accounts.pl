#!/usr/bin/perl

# Copyright 2012 Mark Gavillet & PTFS Europe Ltd
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
use C4::Auth;
use C4::Output;
use C4::Edifact;

use vars qw($debug);

BEGIN {
	$debug = $ENV{DEBUG} || 0;
}

my $input = CGI->new();

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
	{ template_name => "admin/edi_ean_accounts.tt",
		query => $input,
		type => "intranet",
		authnotrequired => 0,
		flagsrequired => { borrowers => 1 },
		debug => ($debug) ? 1 : 0,
	}
);

my $op=$input->param('op');
$template->param(op => $op);

if ($op eq "delsubmit") {
	my $del = C4::Edifact::delete_edi_ean($input->param('branchcode'),$input->param('ean'));
	$template->param(opdelsubmit => 1);
}

if ( $op eq "addsubmit" ) {
    create_edi_ean(
        $input->param('branchcode'),$input->param('ean')
    );
    $template->param(opaddsubmit => 1);
}

if ($op eq "editsubmit" ) {
	update_edi_ean( 
		$input->param('branchcode'),$input->param('ean'),$input->param('oldbranchcode'),$input->param('oldean')
	);
	$template->param(opeditsubmit => 1);
}

my $eans = C4::Edifact::GetEDIfactEANs;
$template->param(eans => $eans);

output_html_with_http_headers $input, $cookie, $template->output;