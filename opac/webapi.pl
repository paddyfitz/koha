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
use C4::Auth;
use C4::Output;
use C4::Context;
use C4::SimpleWebAPI;

my $cgi = new CGI;

my %services;
foreach my $service(qw(ca test))
{
	$services{$service}=1;
}

if (!$cgi->param('service') || !$services{$cgi->param('service')})
{
	my $xmlresponse=ServiceError();
	print "Content-type: text/xml\n\n";
	print $xmlresponse;
	exit 0;
}

# Check availability
if ($cgi->param('service') eq 'ca')
{
	my $id=$cgi->param('id');
	my $xmlresponse=CheckAvailability($id);
	print "Content-type: text/xml\n\n";
	print $xmlresponse;
	exit 0;
}
