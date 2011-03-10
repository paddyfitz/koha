package C4::EDI;

# Copyright 2011 Mark Gavillet
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
use C4::Context;
use C4::Acquisition;
use parent qw(Exporter);

our $VERSION = 1.00;
our $debug   = $ENV{DEBUG} || 0;
our @EXPORT  = qw(
  GetEDIAccounts
  GetEDIAccountDetails
  CreateEDIDetails
  UpdateEDIDetails
  DeleteEDIDetails
  GetVendorList
  GetEDIfactMessageList
  GetEDIFTPAccounts
  LogEDITransaction
  CreateEDIOrder
);

=head1 NAME

C4::EDI - Perl Module containing functions for Vendor EDI accounts

=head1 SYNOPSIS

use C4::EDI;

=head1 DESCRIPTION

This module contains routines for adding, modifying and deleting EDI account details for vendors

=cut

sub GetVendorList {
    my $dbh = C4::Context->dbh;
    my $sth;
    $sth = $dbh->prepare("select id, name from aqbooksellers order by name asc");
    $sth->execute();
    my $vendorlist = $sth->fetchall_arrayref( {} );
    return $vendorlist;
}

sub CreateEDIDetails {
    my ( $provider, $description, $host, $user, $pass, $path, $in_dir, $san ) = @_;
    my $dbh = C4::Context->dbh;
    my $sth;
    if ($provider) {
        $sth = $dbh->prepare(
"insert into vendor_edi_accounts (description, host, username, password, provider, path, in_dir, san) values (?,?,?,?,?,?,?,?)"
        );
        $sth->execute( $description, $host, $user,
            $pass, $provider, $path, $in_dir, $san );
    }
    return;
}

sub GetEDIAccounts {
    my $dbh = C4::Context->dbh;
    my $sth;
    $sth = $dbh->prepare(
"select vendor_edi_accounts.id, aqbooksellers.id as providerid, aqbooksellers.name as vendor, vendor_edi_accounts.description, vendor_edi_accounts.last_activity from vendor_edi_accounts inner join aqbooksellers on vendor_edi_accounts.provider = aqbooksellers.id order by aqbooksellers.name asc"
    );
    $sth->execute();
    my $ediaccounts = $sth->fetchall_arrayref( {} );
    return $ediaccounts;
}

sub DeleteEDIDetails {
    my ($id) = @_;
    my $dbh = C4::Context->dbh;
    my $sth;
    if ($id) {
        $sth =
          $dbh->prepare("delete from vendor_edi_accounts where id=?");
        $sth->execute($id);
    }
    return;
}

sub UpdateEDIDetails {
    my ($editid, $description, $host, $user, $pass, $provider, $path, $in_dir, $san) = @_;
    my $dbh = C4::Context->dbh;
    my $sth;
    if ($editid) {
        $sth = $dbh->prepare(
"update vendor_edi_accounts set description=?, host=?, username=?, password=?, provider=?, path=?, in_dir=?, san=? where id=?"
        );
        $sth->execute($description, $host, $user, $pass, $provider, $path, $in_dir, $san, $editid);
    }
    return;
}

sub GetEDIAccountDetails {
    my ($id) = @_;
    my $dbh = C4::Context->dbh;
    my $sth;
    if ($id) {
        $sth = $dbh->prepare("select * from vendor_edi_accounts where id=?");
        $sth->execute($id);
        my $edi_details = $sth->fetchrow_hashref;
        return $edi_details;
    }
    return;
}

sub GetEDIfactMessageList {
    my $dbh = C4::Context->dbh;
    my $sth;
    $sth = $dbh->prepare(
    "select edifact_messages.key, edifact_messages.message_type, DATE_FORMAT(edifact_messages.date_sent,'%d/%m/%Y') as date_sent, aqbooksellers.id as providerid, aqbooksellers.name as providername, edifact_messages.status from edifact_messages inner join aqbooksellers on edifact_messages.provider = aqbooksellers.id order by edifact_messages.date_sent desc"
    );
    $sth->execute();
    my $messagelist = $sth->fetchall_arrayref( {} );
    return $messagelist;
}

sub GetEDIFTPAccounts {
    my $dbh = C4::Context->dbh;
    my $sth;
    $sth = $dbh->prepare(
"select id, host, username, password, provider, path from vendor_edi_accounts order by id asc"
    );
    $sth->execute();
    my $ftpaccounts = $sth->fetchall_arrayref( {} );
    #my $ftpaccounts = $sth->fetchrow_hashref;
    return $ftpaccounts;
}

sub LogEDITransaction {
	my $id = $_[0];
	my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
	$year=1900+$year;
	$mon=1+$mon;
	my $datestamp = $year."/".$mon."/$mday";
	my $dbh = C4::Context->dbh;
	my $sth;
	$sth = $dbh->prepare(
	"update vendor_edi_accounts set last_activity=? where id=?"
	);
	$sth->execute($datestamp,$id);
	return;
}

sub CreateEDIOrder {
	my ($basketno,$booksellerid) = @_;
	my @datetime=localtime(time);
	my $longyear=($datetime[5]+1900);
	my $shortyear=sprintf "%02d",($datetime[5]-100);
	my $date=sprintf "%02d%02d",$datetime[4],$datetime[3];
	my $hourmin=sprintf "%02d%02d",$datetime[2],$datetime[1];
	my $year=($datetime[5]-100);
	my $month=sprintf "%02d",$datetime[4];
	my $linecount=0;
	my $filename="ediorder_".$basketno.".edi";
	my $exchange=int(rand(99999999999999));
	my $ref=int(rand(99999999999999));
	
	open(EDIORDER,">$ENV{'PERL5LIB'}/misc/edi_files/$filename");

	print EDIORDER "UNA:+.? '";																										# print opening header
	print EDIORDER "UNB+UNOA:2+5013546121974:14+5013546025078:14+$shortyear$date:$hourmin+".$exchange."++ORDERS+++EANCOM'";		# print identifying EANs, date/time, exchange reference number
	print EDIORDER "UNH+".$ref."+ORDERS:D:96A:UN:EAN007'";																# print message reference number
	print EDIORDER "BGM+220+".$basketno."+9'";																						# print order number
	print EDIORDER "DTM+137:$longyear$date:102'";																					# print date of message
	print EDIORDER "NAD+BY+5013546121974::9'";																						# print buyer EAN  ) 9 denotes EAN for both - check if number changes if alternative to EAN used
	print EDIORDER "NAD+SU+5013546025078::9'";																						# print vendor EAN )
	print EDIORDER "NAD+SU+".$booksellerid."::92'";																						# print internal ID assigned by Halton

	# get items from basket
	my @results = GetOrders( $basketno );
	foreach my $item (@results)
	{
		$linecount++;
		my $price;
		my $title=escape($item->{title});
		my $author=escape($item->{author});
		my $publisher=escape($item->{publishercode});
		$price=sprintf "%.2f",$item->{listprice};
		print EDIORDER "LIN+$linecount++$item->{isbn}:EN'";									# line number, isbn
		print EDIORDER "PIA+5+$item->{isbn}:IB'";									# isbn as main product identification
		print EDIORDER "IMD+L+050+:::$title'";										# title
		print EDIORDER "IMD+L+009+:::$author'";										# full name of author
		print EDIORDER "IMD+L+109+:::$publisher'";								# publisher
		print EDIORDER "IMD+L+170+:::$item->{copyrightdate}'";								# date of publication (if)
		print EDIORDER "IMD+L+220+:::O'";													# binding (e.g. PB) (O if not specified)
		print EDIORDER "QTY+21:$item->{quantity}'";															# quantity
		print EDIORDER "GIR+001+HLE:LLO+AGHBK:LSQ+HBK:LST'";									# branch code, sequence or collection code, stock category
		print EDIORDER "FTX+LIN+++:::Request'";												# freetext
		print EDIORDER "PRI+AAB:$price'";														# price per item
		print EDIORDER "CUX+2:GBP:9'";														# currency (GBP)
		print EDIORDER "RFF+LI:$item->{ordernumber}'";														# Halton order number
	}
	print EDIORDER "UNS+S'";															# print summary section header
	print EDIORDER "CNT+2:$linecount'";										# print number of line items in the message
	my $segments=(($linecount*13)+9);
	print EDIORDER "UNT+$segments+".$exchange."'";						# No. of segments in message (UNH+UNT elements included, UNA, UNB, UNZ excluded)
																		# Message ref number as line 15
	print EDIORDER "UNZ+1+".$ref."'\n";										# Exchange ref number as line 14

	close EDIORDER;
	
	return $filename;

	sub escape
	{
		my $string=$_[0];
		$string=~ s/\?/\?\?/g;
		$string=~ s/\'/\?\'/g;
		$string=~ s/\:/\?\:/g;
		$string=~ s/\+/\?\+/g;
		return $string;
	}

}

1;

__END__

=head1 AUTHOR

Mark Gavillet

=cut
