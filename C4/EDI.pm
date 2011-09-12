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
use Net::FTP;
use Edifact::Interchange;
use C4::Biblio;
use C4::Items;
use Business::ISBN;
use parent qw(Exporter);

our $VERSION = 0.01;
our $debug   = $ENV{DEBUG} || 0;
our @EXPORT  = qw(
  GetEDIAccounts
  GetEDIAccountDetails
  CreateEDIDetails
  UpdateEDIDetails
  LogEDIFactOrder
  LogEDIFactQuote
  DeleteEDIDetails
  GetVendorList
  GetEDIfactMessageList
  GetEDIFTPAccounts
  LogEDITransaction
  GetVendorSAN
  CreateEDIOrder
  SendEDIOrder
  SendQueuedEDIOrders
  ParseEDIQuote
  GetDiscountedPrice
  GetBudgetID
  CheckOrderItemExists
  GetBranchCode
  string35escape
  GetOrderItemInfo
  CheckVendorFTPAccountExists
);

=head1 NAME

C4::EDI - Perl Module containing functions for Vendor EDI accounts and EDIfact messages

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

use C4::EDI;

=head1 DESCRIPTION

This module contains routines for adding, modifying and deleting EDI account details for vendors, interacting with vendor FTP sites to send/retrieve quote and order messages, formatting EDIfact orders, and parsing EDIfact quotes to baskets

=head2 GetVendorList

Returns a list of vendors from aqbooksellers to populate drop down select menu

=cut

sub GetVendorList {
    my $dbh = C4::Context->dbh;
    my $sth;
    $sth = $dbh->prepare("select id, name from aqbooksellers order by name asc");
    $sth->execute();
    my $vendorlist = $sth->fetchall_arrayref( {} );
    return $vendorlist;
}

=head2 CreateEDIDetails

Inserts a new EDI vendor FTP account

=cut

sub CreateEDIDetails {
    my ( $provider, $description, $host, $user, $pass, $in_dir, $san ) = @_;
    my $dbh = C4::Context->dbh;
    my $sth;
    if ($provider) {
        $sth = $dbh->prepare(
"insert into vendor_edi_accounts (description, host, username, password, provider, in_dir, san) values (?,?,?,?,?,?,?)"
        );
        $sth->execute( $description, $host, $user,
            $pass, $provider, $in_dir, $san );
    }
    return;
}

=head2 GetEDIAccounts

Returns all vendor FTP accounts

=cut

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

=head2 DeleteEDIDetails

Remove a vendor's FTP account

=cut

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

=head2 UpdateEDIDetails

Update a vendor's FTP account

=cut

sub UpdateEDIDetails {
    my ($editid, $description, $host, $user, $pass, $provider, $in_dir, $san) = @_;
    my $dbh = C4::Context->dbh;
    my $sth;
    if ($editid) {
        $sth = $dbh->prepare(
"update vendor_edi_accounts set description=?, host=?, username=?, password=?, provider=?, in_dir=?, san=? where id=?"
        );
        $sth->execute($description, $host, $user, $pass, $provider, $in_dir, $san, $editid);
    }
    return;
}

=head2 LogEDIFactOrder

Updates or inserts to the edifact_messages table when processing an order and assigns a status and basket number

=cut

sub LogEDIFactOrder {
	my ($provider,$status,$basketno) = @_;
	my $dbh = C4::Context->dbh;
    my $sth;
    my $key;
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
	$year=1900+$year;
	$mon=1+$mon;
	my $date_sent = $year."-".$mon."-$mday";
    $sth = $dbh->prepare("select edifact_messages.key from edifact_messages where basketno=? and provider=?");
    $sth->execute($basketno,$provider);
    #my $key=$sth->fetchrow_array();
    while(my @row=$sth->fetchrow_array())
    {
    	$key=$row[0];
    }
    $sth->finish;
    if ($key)
    {
    	$sth=$dbh->prepare("update edifact_messages set date_sent=?, status=? where edifact_messages.key=?");
   		$sth->execute($date_sent,$status,$key);
    }
    else
    {
    	$sth=$dbh->prepare("insert into edifact_messages (message_type,date_sent,provider,status,basketno) values (?,?,?,?,?)");
   		$sth->execute('ORDER',$date_sent,$provider,$status,$basketno);
    }
}

=head2 LogEDIFactOrder

Updates or inserts to the edifact_messages table when processing a quote and assigns a status and basket number

=cut

sub LogEDIFactQuote {
	my ($provider,$status,$basketno,$key) = @_;
	my $dbh = C4::Context->dbh;
    my $sth;
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
	$year=1900+$year;
	$mon=1+$mon;
	my $date_sent = $year."-".$mon."-$mday";
    if ($key != 0)
    {
    	$sth=$dbh->prepare("update edifact_messages set date_sent=?, status=?, basketno=? where edifact_messages.key=?");
   		$sth->execute($date_sent,$status,$basketno,$key);
    }
    else
    {
    	$sth=$dbh->prepare("insert into edifact_messages (message_type,date_sent,provider,status,basketno) values (?,?,?,?,?)");
   		$sth->execute('QUOTE',$date_sent,$provider,$status,$basketno);
   		$key = $dbh->last_insert_id(undef,undef,qw(edifact_messages key),undef);
    }
    return $key;
}

=head2 GetEDIAccountDetails

Returns FTP account details for a given vendor

=cut

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

=head2 GetEDIfactMessageList

Returns a list of edifact_messages that have been processed, including the type (quote/order) and status

=cut

sub GetEDIfactMessageList {
    my $dbh = C4::Context->dbh;
    my $sth;
    $sth = $dbh->prepare(
    "select edifact_messages.key, edifact_messages.message_type, DATE_FORMAT(edifact_messages.date_sent,'%d/%m/%Y') as date_sent, aqbooksellers.id as providerid, aqbooksellers.name as providername, edifact_messages.status, edifact_messages.basketno from edifact_messages inner join aqbooksellers on edifact_messages.provider = aqbooksellers.id order by edifact_messages.date_sent desc, edifact_messages.key desc"
    );
    $sth->execute();
    my $messagelist = $sth->fetchall_arrayref( {} );
    return $messagelist;
}

=head2 GetEDIFTPAccounts

Returns all vendor FTP accounts. Used when retrieving quotes messages overnight

=cut

sub GetEDIFTPAccounts {
    my $dbh = C4::Context->dbh;
    my $sth;
    $sth = $dbh->prepare(
"select id, host, username, password, provider, in_dir from vendor_edi_accounts order by id asc"
    );
    $sth->execute();
    my $ftpaccounts = $sth->fetchall_arrayref( {} );
    return $ftpaccounts;
}

=head2 LogEDITransaction

Updates the timestamp for a given vendor FTP account whenever there is activity

=cut

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

=head2 GetVendorSAN

Returns the stored SAN number for a given vendor

=cut

sub GetVendorSAN {
	my $booksellerid=$_[0];
	my $dbh = C4::Context->dbh;
    my $sth;
    my @result;
    my $san;
    $sth = $dbh->prepare("select san from vendor_edi_accounts where provider=?");
    $sth->execute($booksellerid);
    while (@result=$sth->fetchrow_array())
    {
    	$san=$result[0];
    }
    return $san;
}

=head2 CreateEDIOrder

Formats an EDIfact order message from a given basket and stores as a file on the server

=cut

sub CreateEDIOrder {
	my ($basketno,$booksellerid) = @_;
	my @datetime=localtime(time);
	my $longyear=($datetime[5]+1900);
	my $shortyear=sprintf "%02d",($datetime[5]-100);
	my $date=sprintf "%02d%02d",($datetime[4]+1),$datetime[3];
	my $hourmin=sprintf "%02d%02d",$datetime[2],$datetime[1];
	my $year=($datetime[5]-100);
	my $month=sprintf "%02d",($datetime[4]+1);
	my $linecount=0;
	my $filename="ediorder_".$basketno.".CEP";
	my $exchange=int(rand(99999999999999));
	my $ref=int(rand(99999999999999));
	my $san=GetVendorSAN($booksellerid);
	my $message_type=GetMessageType($basketno);
	
	open(EDIORDER,">$ENV{'PERL5LIB'}/misc/edi_files/$filename");
	
	print EDIORDER "UNA:+.? '";																							# print opening header
	print EDIORDER "UNB+UNOC:2+".C4::Context->preference("EDIfactEAN").":14+$san:31B+$shortyear$date:$hourmin+".$exchange."++ORDERS+++EANCOM'";		# print identifying EANs/SANs, date/time, exchange reference number
	print EDIORDER "UNH+".$ref."+ORDERS:D:96A:UN:EAN008'";																# print message reference number
	if ($message_type eq 'QUOTE')
	{
		print EDIORDER "BGM+22V+".$basketno."+9'";																		# print order number and quote confirmation ref
	}
	else
	{
		print EDIORDER "BGM+220+".$basketno."+9'";																		# print order number
	}
	print EDIORDER "DTM+137:$longyear$date:102'";																		# print date of message
	print EDIORDER "NAD+BY+".C4::Context->preference("EDIfactEAN")."::9'";																			# print buyer EAN  
	print EDIORDER "NAD+SU+".$san."::31B'";																				# print vendor SAN
	print EDIORDER "NAD+SU+".$booksellerid."::92'";																		# print internal ID 

	# get items from basket
	my @results = GetOrders( $basketno );
	foreach my $item (@results)
	{
		$linecount++;
		my $price;
		my $title=string35escape(escape($item->{title}));
		my $author=string35escape(escape($item->{author}));
		my $publisher=string35escape(escape($item->{publishercode}));
		$price=sprintf "%.2f",$item->{listprice};
		my $isbn;
		if (length($item->{isbn})==10 || substr($item->{isbn},0,3) eq "978" || index($item->{isbn},"|") !=-1)
		{
			$isbn=cleanisbn($item->{isbn});
			$isbn=Business::ISBN->new($isbn);
			if ($isbn)
			{
				if ($isbn->is_valid)
				{
					$isbn=($isbn->as_isbn13)->isbn;
				}
				else
				{
					$isbn="0";
				}
			}
			else
			{
				$isbn=0;
			}
		}
		else
		{
			$isbn=$item->{isbn};
		}
		my $copyrightdate=escape($item->{publicationyear});
		my $quantity=escape($item->{quantity});
		my $ordernumber=escape($item->{ordernumber});
		my $notes;
		if ($item->{notes})
		{
			$notes=$item->{notes};
			$notes =~ s/[\r\n]+//g;
			$notes=string35escape(escape($notes));
		}
		
		my ($branchcode,$callnumber,$itype,$lsqccode,$fund) = GetOrderItemInfo($item->{'ordernumber'});
		$callnumber=escape($callnumber);
		
		print EDIORDER "LIN+$linecount++".$isbn.":EN'";											# line number, isbn
		print EDIORDER "PIA+5+".$isbn.":IB'";														# isbn as main product identification
		print EDIORDER "IMD+L+050+:::$title'";															# title
		print EDIORDER "IMD+L+009+:::$author'";															# full name of author
		print EDIORDER "IMD+L+109+:::$publisher'";														# publisher
		print EDIORDER "IMD+L+170+:::$copyrightdate'";													# date of publication
		print EDIORDER "IMD+L+220+:::O'";																# binding (e.g. PB) (O if not specified)
		if ($callnumber ne '')
		{
			print EDIORDER "IMD+L+230+:::$callnumber'";													# shelfmark
		}
		print EDIORDER "QTY+21:$quantity'";																# quantity
		print EDIORDER "GIR+001+$branchcode:LLO+$fund:LFN+";											# branchcode, fund code
		if ($callnumber ne '')
		{
			print EDIORDER "$callnumber:LCL+";																# shelfmark
		}
		print EDIORDER $itype.":LST+$lsqccode:LSQ'";													# stock category, sequence
		if ($notes)
		{
			print EDIORDER "FTX+LIN+++:::$notes'";
		}
		###REQUEST ORDERS TO REVISIT
		#if ($message_type ne 'QUOTE')
		#{
		#	print EDIORDER "FTX+LIN++$linecount:10B:28'";													# freetext ** used for request orders to denote priority (to revisit)
		#}
		print EDIORDER "PRI+AAB:$price'";																# price per item
		print EDIORDER "CUX+2:GBP:9'";																	# currency (GBP)
		print EDIORDER "RFF+LI:$ordernumber'";															# Local order number
		if ($message_type eq 'QUOTE')
		{
			print EDIORDER "RFF+QLI:".$item->{booksellerinvoicenumber}."'";								# If QUOTE confirmation, include booksellerinvoicenumber
		}
	}
	print EDIORDER "UNS+S'";																			# print summary section header
	print EDIORDER "CNT+2:$linecount'";																	# print number of line items in the message
	my $segments=(($linecount*13)+9);
	print EDIORDER "UNT+$segments+".$ref."'";															# No. of segments in message (UNH+UNT elements included, UNA, UNB, UNZ excluded)
																										# Message ref number 
	print EDIORDER "UNZ+1+".$exchange."'\n";															# Exchange ref number

	close EDIORDER;
	
    LogEDIFactOrder($booksellerid,'Queued',$basketno);
	
	return $filename;
	
	sub GetMessageType
	{
		my $basketno=shift;
		my $dbh = C4::Context->dbh;
	    my $sth;
	    my $message_type;
	    my @row;
	    $sth = $dbh->prepare(
	    "select message_type from edifact_messages where basketno=?"
	    );
	    $sth->execute($basketno);
	    while (@row=$sth->fetchrow_array())
	    {
	    	$message_type=$row[0];
	    }
		return $message_type;
	}

	sub cleanisbn
	{
		my $isbn=$_[0];
		if ($isbn ne "")
		{
			my $i=index($isbn,'(');
			if ($i>1)
			{
				$isbn=substr($isbn,0,($i-1));
			}
			if (index($isbn,"|") !=-1)
			{
				my @isbns=split(/\|/,$isbn);
				$isbn=$isbns[0];
				#print "0: ".$isbns[0]."\n";
			}
			$isbn=escape($isbn);
			$isbn =~ s/^\s+//;
			$isbn =~ s/\s+$//;
			return $isbn;
		}
		else
		{
			return undef;
		}
	}
	
	sub escape
	{
		my $string=$_[0];
		if ($string ne "")
		{
			$string=~ s/\?/\?\?/g;
			$string=~ s/\'/\?\'/g;
			$string=~ s/\:/\?\:/g;
			$string=~ s/\+/\?\+/g;
			return $string;
		}
		else
		{
			return;
		}
	}

}

=head2 GetBranchCode

Return branchcode for an order when formatting an EDIfact order message

=cut

sub GetBranchCode {
	my $biblioitemnumber=shift;
	my $dbh = C4::Context->dbh;
    my $sth;
    my $branchcode;
    my @row;
    $sth = $dbh->prepare(
    "select homebranch from items where biblioitemnumber=?"
    );
    $sth->execute($biblioitemnumber);
    while (@row=$sth->fetchrow_array())
    {
    	$branchcode=$row[0];
    }
	return $branchcode;
}

=head2 SendEDIOrder

Transfers an EDIfact order message to the relevant vendor's FTP site

=cut

sub SendEDIOrder {
	my ($basketno,$booksellerid) = @_;
	my @ERRORS;
	my $newerr;
	my $result;
	
	# check edi order file exists
	if (-e "$ENV{'PERL5LIB'}/misc/edi_files/ediorder_$basketno.CEP")
	{
		my $dbh = C4::Context->dbh;
    	my $sth;
    	$sth = $dbh->prepare(
		"select id, host, username, password, provider, in_dir from vendor_edi_accounts where provider=?"
    	);
    	$sth->execute($booksellerid);
   		my $ftpaccount = $sth->fetchrow_hashref;
    
    	#check vendor edi account exists
   		if ($ftpaccount)
    	{			
			# connect to ftp account
			my $ftp=Net::FTP->new($ftpaccount->{host},Timeout=>10) or $newerr=1;
			if (!$newerr)
			{
				$newerr=0;
				
				# login
				$ftp->login("$ftpaccount->{username}","$ftpaccount->{password}") or $newerr=1;
				$ftp->quit if $newerr;
				if (!$newerr)
				{				
					# cd to directory
					$ftp->cwd("$ftpaccount->{in_dir}") or $newerr=1; 
					$ftp->quit if $newerr;
					
					# put file
					if (!$newerr)
					{
						$newerr=0;
     					 $ftp->put("$ENV{'PERL5LIB'}/misc/edi_files/ediorder_$basketno.CEP") or $newerr=1;
     					 $ftp->quit if $newerr;
     					 if (!$newerr)
     					 {
     					 	#$result="$ENV{'PERL5LIB'}/misc/edi_files/ediorder_$basketno.CEP transferred successfully";
     					 	$result="File: ediorder_$basketno.CEP transferred successfully";
     					 	$ftp->quit;
     					 	unlink("$ENV{'PERL5LIB'}/misc/edi_files/ediorder_$basketno.CEP");
     					 	LogEDITransaction($ftpaccount->{id});
     					 	LogEDIFactOrder($booksellerid,'Sent',$basketno);
     					 	return $result;
     					 }
     					 else
     					 {
							$result="Could not transfer the file $ENV{'PERL5LIB'}/misc/edi_files/ediorder_$basketno.CEP to $ftpaccount->{host}: $_";
 	  			 			FTPError($result);
     					 	LogEDIFactOrder($booksellerid,'Failed',$basketno);
							return $result;
     					 }
     				}
     				else
     				{
     					$result="Cannot get remote directory ($ftpaccount->{in_dir}) on $ftpaccount->{host}";
 	   					FTPError($result);
     					LogEDIFactOrder($booksellerid,'Failed',$basketno);
     					return $result;
     				}				
				}
				else
				{
					$result="Cannot log in to $ftpaccount->{host}: $!";
 	   				FTPError($result);
     				LogEDIFactOrder($booksellerid,'Failed',$basketno);
					return $result;
				}				
			}
			else
			{
				$result="Cannot make an FTP connection to $ftpaccount->{host}: $!";
 	   			FTPError($result);
     			LogEDIFactOrder($booksellerid,'Failed',$basketno);
				return $result;
			}
	    }
	    else
	    {
 	   		$result="Vendor ID: $booksellerid does not have a current EDIfact FTP account";
 	   		FTPError($result);
     		LogEDIFactOrder($booksellerid,'Failed',$basketno);
	    	return $result;
	    }
	}
	else
	{
		$result="There is no EDIfact order for this basket";
		return $result;
	}
	sub FTPError {
		my $error=$_[0];
		open LOGFILE, ">>$ENV{'PERL5LIB'}/misc/edi_files/edi_ftp_error.log" or die "Could not open file";
		my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
		printf LOGFILE "%4d-%02d-%02d %02d:%02d:%02d\n-----\n",$year+1900,$mon+1,$mday,$hour,$min,$sec;
		print LOGFILE "$error\n\n";
		close LOGFILE;
	}
}

=head2 SendQueuedEDIOrders

Sends all EDIfact orders that are held in the Queued

=cut

sub SendQueuedEDIOrders {
    my $dbh = C4::Context->dbh;
    my $sth;
    my @orders;
    $sth = $dbh->prepare(
    "select basketno, provider from edifact_messages where status='Queued'"
    );
    $sth->execute();
    while (@orders=$sth->fetchrow_array())
    {
    	SendEDIOrder($orders[0],$orders[1]);
    }
    return;
}

=head2 ParseEDIQuote

Uses Edifact::Interchange to parse a stored EDIfact quote message, creates basket, biblios, biblioitems, and items

=cut

sub ParseEDIQuote {
	my ($filename,$booksellerid) = @_;
	my $ordernumber;
	my $basketno;
	my $ParseEDIQuoteItem;
	print "file: $filename\n";
	my $edi=Edifact::Interchange->new;
	$edi->parse_file("$ENV{'PERL5LIB'}/misc/edi_files/$filename");
	my $messages=$edi->messages();
	my $msg_cnt=@{$messages};
	print "messages: $msg_cnt\n";
	print "type: ".$messages->[0]->type()."\n";
	print "date: ".$messages->[0]->date_of_message()."\n";
	
	# create default edifact_messages entry
	my $messagekey=LogEDIFactQuote($booksellerid,'Failed',0,0);
	
	#create basket
	if ($msg_cnt>0 && $booksellerid)
	{
		$basketno=NewBasket($booksellerid, 0, $filename, '', '', '');
	}	
	
	$ParseEDIQuoteItem = sub {
			my ($item,$gir,$booksellerid)=@_;
			my $relnos=$item->{related_numbers};
			my $author=$item->author_surname.", ".$item->author_firstname;
			
			my $ecost=GetDiscountedPrice($booksellerid,$item->{price}->{price});
			
			my $ftxlin;
			my $ftxlno;
			if ($item->{free_text}->{qualifier} eq "LIN")
			{
				$ftxlin=$item->{free_text}->{text};
			}
			if ($item->{free_text}->{qualifier} eq "LNO")
			{
				$ftxlno=$item->{free_text}->{text};
			}
	        
			my ($llo,$lfn,$lsq,$lst,$lfs,$lcl,$id);
			my $relcount=0;
			foreach my $rel (@$relnos)
			{
				if ($rel->{id}==($gir+1))
				{
					if ($item->{related_numbers}->[$relcount]->{LLO}->[0])
					{
						$llo=$item->{related_numbers}->[$relcount]->{LLO}->[0];
					}
					if ($item->{related_numbers}->[$relcount]->{LFN}->[0])
					{
						$lfn=$item->{related_numbers}->[$relcount]->{LFN}->[0];
					}
					if ($item->{related_numbers}->[$relcount]->{LSQ}->[0])
					{
						$lsq=$item->{related_numbers}->[$relcount]->{LSQ}->[0];
					}
					if ($item->{related_numbers}->[$relcount]->{LST}->[0])
					{
						$lst=$item->{related_numbers}->[$relcount]->{LST}->[0];
					}
					if ($item->{related_numbers}->[$relcount]->{LFS}->[0])
					{
						$lfs=$item->{related_numbers}->[$relcount]->{LFS}->[0];
					}
					if ($item->{related_numbers}->[$relcount]->{LCL}->[0])
					{
						$lcl=$item->{related_numbers}->[$relcount]->{LCL}->[0];
					}
					if ($item->{related_numbers}->[$relcount]->{id})
					{
						$id=$item->{related_numbers}->[$relcount]->{id};
					}
				}
				$relcount++;
			}
	        
			my $lclnote;
			if (!$lst)
			{
				$lst=uc($item->item_format);
			}
			if (!$lcl)
			{
				$lcl=$item->shelfmark;
			}
			else
			{
				($lcl,$lclnote) = DawsonsLCL($lcl);
			}
			if ($lfs)
			{
				$lcl=$lcl." ".$lfs;
			}
			
			my $budget_id=GetBudgetID($lfn);
	        
	        #Uncomment section below to define a default budget_id if there is no match
	        #if (!defined $budget_id)
	        #{
	        #	$budget_id=0;
	        #}
		
			# create biblio record
			my $record = TransformKohaToMarc(
	        {
	            "biblio.title"                => $item->title,
	            "biblio.author"               => $author			          ? $author			           : "",
	            "biblio.seriestitle"          => "",
	            "biblioitems.isbn"            => $item->{item_number}         ? $item->{item_number}       : "",
	            "biblioitems.publishercode"   => $item->publisher			  ? $item->publisher		   : "",
	            "biblioitems.publicationyear" => $item->date_of_publication   ? $item->date_of_publication : "",
	            "biblio.copyrightdate"        => $item->date_of_publication   ? $item->date_of_publication : "",
	            "biblioitems.itemtype"		  => uc($item->item_format),
	            "biblioitems.cn_source"		  => "ddc",
	            "items.cn_source"			  => "ddc",
	            "items.notforloan"			  => "-1",
	            #"items.ccode"				  => $lsq,
	            "items.location"			  => $lsq,
	            "items.homebranch"			  => $llo,
	            "items.holdingbranch"		  => $llo,
	            "items.booksellerid"		  => $booksellerid,
	            "items.price"				  => $item->{price}->{price},
	            "items.replacementprice"	  => $item->{price}->{price},
	            "items.itemcallnumber"		  => $lcl,
	            "items.itype"				  => $lst,
	            "items.cn_sort"				  => "",
	        });
	        
	        #check if item already exists in catalogue
			my $biblionumber;
			my $bibitemnumber;
			($biblionumber,$bibitemnumber)=CheckOrderItemExists($item->{item_number});
        
	        if (!defined $biblionumber)
			{
		        # create the record in catalogue, with framework ''
		        ($biblionumber,$bibitemnumber) = AddBiblio($record,'');
	        }
	        
	        my $ordernote;
	        if ($lclnote)
	        {
	        	$ordernote=$lclnote;
	        }
	        if ($ftxlno)
	        {
	        	$ordernote=$ftxlno;
	        }
	        if ($ftxlin)
	        {
	        	$ordernote=$ftxlin;
	        }
	        
	        my %orderinfo = (
	        	basketno				=> $basketno,
	        	ordernumber				=> "",
	        	subscription			=> "no",
	        	uncertainprice			=> 0,
	        	biblionumber			=> $biblionumber,
	        	title					=> $item->title,
	        	quantity				=> 1,
	        	biblioitemnumber		=> $bibitemnumber,
	        	rrp						=> $item->{price}->{price},
	        	ecost					=> $ecost,
	 	       	sort1					=> "",
	 	       	sort2					=> "",
	        	booksellerinvoicenumber	=> $item->{item_reference}[0][1],
	        	listprice				=> $item->{price}->{price},
	        	branchcode				=> $llo,
	        	budget_id				=> $budget_id,
	        	notes					=> $ordernote,
	        );
        
	        my $orderinfo = \%orderinfo;
        
	        my ($retbasketno, $ordernumber ) = NewOrder($orderinfo); 
		
		    # now, add items if applicable
		    if (C4::Context->preference('AcqCreateItem') eq 'ordering')
		    {
		    	my $itemnumber;
		    	($biblionumber,$bibitemnumber,$itemnumber) = AddItemFromMarc($record,$biblionumber);
	            NewOrderItem($itemnumber, $ordernumber);
		    }		
	};

	
	my $count;
	for ($count=0; $count<$msg_cnt; $count++)
	{
		my $items=$messages->[$count]->items();
		my $ref_num=$messages->[$count]->{ref_num};
	
		foreach my $item (@{$items})
		{
			for (my $i=0; $i<$item->{quantity}; $i++)
			{
				&$ParseEDIQuoteItem($item,$i,$booksellerid,$basketno);
			}
		}
	}
	# update edifact_messages entry
	$messagekey=LogEDIFactQuote($booksellerid,'Received',$basketno,$messagekey);
	return 1;
	
}

=head2 GetDiscountedPrice

Returns the discounted price for an order based on the discount rate for a given vendor

=cut

sub GetDiscountedPrice {
	my ($booksellerid, $price) = @_;
	my $dbh = C4::Context->dbh;
    my $sth;
    my @discount;
    my $ecost;
    my $percentage;
    $sth = $dbh->prepare(
    "select discount from aqbooksellers where id=?"
    );
    $sth->execute($booksellerid);
    while (@discount=$sth->fetchrow_array())
    {
    	$percentage=$discount[0];
    }
    $ecost=($price-(($percentage*$price)/100));
    return $ecost;
}

=head2 DawsonsLCL

Checks for a call number encased by asterisks. If found, returns call number as $lcl and string with
asterisks as $lclnote to go into FTX field enabling spine label creation by Dawsons bookseller

=cut

sub DawsonsLCL {
	my $lcl=shift;
	my $lclnote;
	my $f=index($lcl,'*');
	my $l=rindex($lcl,'*');
	if ($f==0 && $l==(length($lcl)-1))
	{
		$lclnote=$lcl;
		$lcl=~ s/\*//g;
	}
	return ($lcl,$lclnote);
}

=head2 GetBudgetID

Returns the budget_id for a given budget_code

=cut

sub GetBudgetID {
	my $fundcode=shift;
	my $dbh = C4::Context->dbh;
    my $sth;
    my @funds;
    my $ecost;
    my $budget_id;
    $sth = $dbh->prepare(
    "select budget_id from aqbudgets where budget_code=?"
    );
    $sth->execute($fundcode);
    while (@funds=$sth->fetchrow_array())
    {
    	$budget_id=$funds[0];
    }
    return $budget_id;
}

=head2 CheckOrderItemExists

Checks to see if a biblio record already exists in the catalogue when parsing a quotes message
Converts 10-13 digit ISBNs and vice-versa if an initial match is not found

=cut

sub CheckOrderItemExists {
	my $isbn=shift;
	my $dbh = C4::Context->dbh;
    my $sth;
    my @matches;
    my $biblionumber;
    my $bibitemnumber;
    $sth = $dbh->prepare(
    "select biblionumber, biblioitemnumber from biblioitems where isbn=?"
    );
    $sth->execute($isbn);
    while (@matches=$sth->fetchrow_array())
    {
    	$biblionumber=$matches[0];
    	$bibitemnumber=$matches[1];
    }
    if ($biblionumber)
    {
    	return $biblionumber,$bibitemnumber;
    }
    else
    {
		$isbn=cleanisbn($isbn);
    	if (length($isbn)==10)
    	{
			$isbn=Business::ISBN->new($isbn);
			if ($isbn)
			{
				if ($isbn->is_valid)
				{
					$isbn=($isbn->as_isbn13)->isbn;
					$sth->execute($isbn);
    				while (@matches=$sth->fetchrow_array())
    				{
						$biblionumber=$matches[0];
    					$bibitemnumber=$matches[1];
   					}
				}
			}
    	}
    	elsif (length($isbn)==13)
    	{
			$isbn=Business::ISBN->new($isbn);
			if ($isbn)
			{
				if ($isbn->is_valid)
				{
					$isbn=($isbn->as_isbn10)->isbn;
					$sth->execute($isbn);
    				while (@matches=$sth->fetchrow_array())
    				{
						$biblionumber=$matches[0];
    					$bibitemnumber=$matches[1];
   					}
				}
			}
    	}
    	return $biblionumber,$bibitemnumber;
    }
}

sub string35escape {
	my $string=shift;
	my $section;
	my $colon_string;
	my @sections;
	if (length($string)>35)
	{
		my ($chunk,$stringlength)=(35,length($string));
		for (my $counter=0;$counter<$stringlength;$counter+=$chunk)
		{
			push @sections,substr($string,$counter,$chunk);
		}
		foreach $section (@sections)
		{
			$colon_string.=$section.":";
		}
		chop($colon_string);
	}
	else
	{
		$colon_string=$string;
	}
	return $colon_string;
}

sub GetOrderItemInfo {
	my $ordernumber=shift;
	my $dbh = C4::Context->dbh;
	my $sth;
	my @rows;
	my $homebranch;
	my $callnumber;
	my $itype;
	my $ccode;
	my $fund;
	$sth = $dbh->prepare(
	"select items.homebranch, items.itemcallnumber, items.itype, items.location from items 
	inner join aqorders_items on aqorders_items.itemnumber=items.itemnumber 
	where aqorders_items.ordernumber=?");
	$sth->execute($ordernumber);
	while (@rows=$sth->fetchrow_array())
	{
		$homebranch=$rows[0];
		$callnumber=$rows[1];
		$itype=$rows[2];
		$ccode=$rows[3];
	}
	$sth = $dbh->prepare(
	"select aqbudgets.budget_code from aqbudgets inner join aqorders on 
	aqorders.budget_id=aqbudgets.budget_id where aqorders.ordernumber=?");
	$sth->execute($ordernumber);
	while (@rows=$sth->fetchrow_array())
	{
		$fund=$rows[0];
	}
	return $homebranch,$callnumber,$itype,$ccode,$fund;
}

sub CheckVendorFTPAccountExists {
	my $booksellerid=shift;
	my $dbh = C4::Context->dbh;
	my $sth;
	my @rows;
	my $cnt;
	$sth = $dbh->prepare(
	"select count(id) from vendor_edi_accounts where provider=?");
	$sth->execute($booksellerid);
	while (@rows=$sth->fetchrow_array())
	{
		$cnt=$rows[0];
	}
	if ($cnt != 0)
	{
		return 1;
	}
	else
	{
		return undef;
	}
}

1;

__END__

=head1 AUTHOR

Mark Gavillet

=cut
