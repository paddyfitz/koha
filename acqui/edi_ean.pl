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

use C4::Auth;
use C4::Koha;
use C4::Output;
use CGI;
use C4::Edifact;

my $eans=GetEDIfactEANs();
my $total_eans=scalar(@{$eans});
my $query        = new CGI;
my $basketno     = $query->param('basketno');
my $ean;

if ($total_eans==1)
{
	$ean=@{$eans}[0]->{'ean'};
	print $query->redirect("/cgi-bin/koha/acqui/basket.pl?basketno=$basketno&op=ediorder&ean=$ean");
}
else
{
	my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
		{
			template_name   => "acqui/edi_ean.tt",
			query           => $query,
			type            => "intranet",
			authnotrequired => 0,
			flagsrequired   => { acquisition => 'order_manage' },
			debug           => 1,
		}
	);
	$template->param(eans=>$eans);
	$template->param(basketno=>$basketno);
	
	output_html_with_http_headers $query, $cookie, $template->output;
}