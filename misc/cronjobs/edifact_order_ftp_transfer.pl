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
use C4::EDI;
use Net::FTP;

my $ftpaccounts=C4::EDI::GetEDIFTPAccounts;
	
my @ERRORS;
my @putdirlist;
my $newerr;
my @files;
my $f;
my $putdir = "$ENV{'PERL5LIB'}/misc/edi_files/";
opendir(CURRENT, $putdir);
@putdirlist=readdir CURRENT;
closedir CURRENT;

foreach my $accounts(@$ftpaccounts)
{
	my $ftp=Net::FTP->new($accounts->{host},Timeout=>10) or $newerr=1;
	push @ERRORS, "Can't ftp to $accounts->{host}: $!\n" if $newerr;
	myerr() if $newerr;
	if (!$newerr)
	{
		$newerr=0;
		print "Connected to $accounts->{host}\n";

		$ftp->login("$accounts->{username}","$accounts->{password}") or $newerr=1;
		print "Getting file list\n";
		push @ERRORS, "Can't login to $accounts->{host}: $!\n" if $newerr;
		$ftp->quit if $newerr;
		myerr() if $newerr; 
		if (!$newerr)
		{
			print "Logged in\n";
			$ftp->cwd($accounts->{in_dir}) or $newerr=1; 
			push @ERRORS, "Can't cd in server $accounts->{host} $!\n" if $newerr;
			myerr() if $newerr;
			$ftp->quit if $newerr;

				@files=$ftp->ls or $newerr=1;
				push @ERRORS, "Can't get file list from server $accounts->{host} $!\n" if $newerr;
				myerr() if $newerr;
				if (!$newerr)
				{
					print "Got  file list\n";   
					foreach(@files) {
						if ((index lc($_),'.ceq') > -1)
						{
							my $match;
							foreach $f (@putdirlist)
							{
								if ($f eq $_)
								{
									$match=1;
									last;
								}
							}
							if ($match ne 1)
							{
								chdir "$putdir";
								$ftp->get($_) or $newerr=1;
								push @ERRORS, "Can't transfer file ($_) from $accounts->{host} $!\n" if $newerr;
								$ftp->quit if $newerr;
								myerr() if $newerr;
								if (!$newerr)
								{
									my $ediparse=ParseEDIQuote($_,$accounts->{provider});
								}
							}
						}
					}
				}
		}
		if (!$newerr)
			{
				LogEDITransaction("$accounts->{id}");
			}
		$ftp->quit;
	}
	$newerr=0;
}

print "\n@ERRORS\n";

if (@ERRORS) {
	open LOGFILE, ">>$ENV{'PERL5LIB'}/misc/edi_files/edi_ftp_error.log";
	my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
	printf LOGFILE "%4d-%02d-%02d %02d:%02d:%02d\n-----\n",$year+1900,$mon+1,$mday,$hour,$min,$sec;
	print LOGFILE "@ERRORS\n";
	close LOGFILE;
}

sub myerr {
  print "Error: ";
  print @ERRORS;
}
 