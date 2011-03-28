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

my $edidir="$ENV{'PERL5LIB'}/misc/edi_files";
opendir(EDIDIR,$edidir);
my @files=readdir(EDIDIR);
close EDIDIR;

foreach my $file(@files)
{
	my $now=time;
	my @stat=stat("$edidir/$file");
	if ($stat[9]<($now-2592000) && ((index lc($file),'.ceq') > -1 || (index lc($file),'.cep') > -1))
	{
		print "Deleting file $edidir/$file...";
		unlink("$edidir/$file");
		print "Done.\n";
	}
}