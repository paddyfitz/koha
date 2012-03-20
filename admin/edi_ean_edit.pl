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
	{ template_name => "admin/edi_ean_edit.tt",
		query => $input,
		type => "intranet",
		authnotrequired => 0,
		flagsrequired => { borrowers => 1 },
		debug => ($debug) ? 1 : 0,
	}
);
my $branchlist = C4::Edifact::GetBranchList;

my $op = $input->param('op');
$template->param( op => $op );

if ( $op eq "add" ) {
    $template->param( opaddsubmit => "addsubmit" );
}
if ( $op eq "edit" ) {
	$template->param( opeditsubmit => "editsubmit" );
	
	$template->param(
		ean					=> $input->param('ean'),
		selectedbranch		=> $input->param('branchcode'),
		branchcode			=> $input->param('branchcode')
		);
}
if ( $op eq "del" ) {
	$template->param( opdelsubmit => "delsubmit" );
	$template->param( opdel => 1 );
	$template->param( ean => $input->param('ean'));
	$template->param( branchcode => $input->param('branchcode'));
}
    

$template->param(branchlist => $branchlist);

output_html_with_http_headers $input, $cookie, $template->output;
