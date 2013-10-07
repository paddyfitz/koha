package C4::SimpleWebAPI;

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
use CGI;
use C4::Biblio;
use Data::Dumper;
use C4::Items;
use C4::Branch;
use C4::Reserves;
use C4::Members;
use C4::Circulation;

our $VERSION="0.1";
use base 'Exporter';
our @EXPORT=qw(CheckAvailability ServiceError CancelHold RenewItem RenewAll HoldTitle);

=head1 NAME

C4::SimpleWebAPI - Services to expose simple XML format responses for common queries

=head1 DESCRIPTION


=head1 SYNOPSIS


=cut

=head1 FUNCTIONS

=head2 CheckAvailability

Checks CGI param ID and returns fleshed items for a biblionumber

Parameters:

=head3 id (Required)

ID value of the biblio record (biblio.biblionumber)

=cut

sub CheckAvailability {
    my ($id) = shift;

    my $xmlresponse = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\" ?>\n";
    $xmlresponse .= "<SimpleWebAPI_response>\n";
    
    # ERROR - No biblio ID entered
    if (!$id)
    {
    	$xmlresponse .= "\t<error>You must enter an ID to retrieve availability</error>\n";
    	$xmlresponse .= "</SimpleWebAPI_response>\n";
	    return $xmlresponse;
    }
    
    my $biblioitem = (GetBiblioItemByBiblioNumber($id));
    
    # ERROR - biblio ID not found
    if (!$biblioitem)
    {
    	$xmlresponse .= "\t<error>The item $id was not found</error>\n";
    	$xmlresponse .= "</SimpleWebAPI_response>\n";
	    return $xmlresponse;
    }
    
    my $items=GetItemsByBiblioitemnumber($id);
    
    # ERROR - no items found
    if (!$items)
    {
    	$xmlresponse .= "\t<error>No items were found for the ID $id</error>\n";
    	$xmlresponse .= "</SimpleWebAPI_response>\n";
	    return $xmlresponse;
    }
    
    $xmlresponse .= "\t<biblionumber>$id</biblionumber>\n";
    $xmlresponse .= "\t<items>\n";
    
    my $total_items;
    my $total_available;
    my $na;
    my $curdate=sprintf "%d%02d%02d",(localtime)[5] + 1900,(localtime)[4] + 1, (localtime)[3] ;
	for my $item (@$items)
	{
		$na=0;
		my $onloan=0;
		my $duedate=$item->{onloan};
		$duedate=~ s/-//g;
		$xmlresponse .= "\t\t<item>\n";
		$xmlresponse .= "\t\t\t<itemnumber>".clean_xml($item->{itemnumber})."</itemnumber>\n";
		$xmlresponse .= "\t\t\t<itembarcode>".clean_xml($item->{barcode})."</itembarcode>\n";
		my $issued=CheckOverdue($item->{itemnumber});
		if ($item->{restricted}!=0)
		{
			$xmlresponse .= "\t\t\t<status>Restricted</status>\n";
			$total_items++;
			$na=1;
		}
		elsif ($item->{withdrawn}!=0)
		{
			$xmlresponse .= "\t\t\t<status>Withdrawn</status>\n";
			$total_items++;
			$na=1;
		}
		elsif ($item->{notforloan}!=0)
		{
			$xmlresponse .= "\t\t\t<status>Not for loan</status>\n";
			$total_items++;
			$na=1;
		}
		elsif ($item->{itemlost}!=0)
		{
			$xmlresponse .= "\t\t\t<status>Item lost</status>\n";
			$total_items++;
			$na=1;
		}
		elsif ($item->{damaged}!=0)
		{
			$xmlresponse .= "\t\t\t<status>Damaged</status>\n";
			$total_items++;
			$na=1;
		}
		elsif ($duedate >= $curdate || $curdate eq '')
		{
			$xmlresponse .= "\t\t\t<status>On loan</status>\n";
			$total_items++;
			$na=1;
			$onloan=1;
		}
		elsif ($issued>0)
		{
			$xmlresponse .= "\t\t\t<status>Overdue</status>\n";
			$total_items++;
			$na=1;
			$onloan=1;
		}
		if ($na==0)
		{
			$xmlresponse .= "\t\t\t<status>Available</status>\n";
			$total_available++;
			$total_items++;
		}
		if ($onloan==0)
		{
			$xmlresponse .= "\t\t\t<duedate></duedate>\n";
		}
		else
		{
			$xmlresponse .= "\t\t\t<duedate>".clean_xml($item->{onloan})."</duedate>\n";
		}
		$xmlresponse .= "\t\t\t<branch>".clean_xml(GetBranchName($item->{holdingbranch}))."</branch>\n";
		$xmlresponse .= "\t\t\t<type>".clean_xml(GetItemType($item->{itype}))."</type>\n";
		$xmlresponse .= "\t\t\t<callnumber>".clean_xml($item->{itemcallnumber})."</callnumber>\n";
		$xmlresponse .= "\t\t\t<collection>".clean_xml(GetCollection($item->{ccode}))."</collection>\n";
		$xmlresponse .= "\t\t\t<location>".clean_xml(GetLocation($item->{location}))."</location>\n";
		$xmlresponse .= "\t\t</item>\n";
	}
    $xmlresponse .= "\t</items>\n";
    $xmlresponse .= "\t<totalitems>$total_items</totalitems>\n";
    $xmlresponse .= "\t<totalavailable>$total_available</totalavailable>\n";

    $xmlresponse .= "</SimpleWebAPI_response>\n";
    return $xmlresponse;
    #return $items;
    
    sub GetCollection {
    	my $collection=shift;
    	my $dbh = C4::Context->dbh;
		my $sth = $dbh->prepare("SELECT lib FROM authorised_values WHERE category='CCODE' 
			and authorised_value = ?");
		$sth->execute($collection);
		$collection=$sth->fetchrow_array;
		return $collection;
    }

    sub GetLocation {
    	my $location=shift;
    	my $dbh = C4::Context->dbh;
		my $sth = $dbh->prepare("SELECT lib FROM authorised_values WHERE category='LOC' 
			and authorised_value = ?");
		$sth->execute($location);
		$location=$sth->fetchrow_array;
		return $location;
    }

    sub GetItemType {
    	my $itemtype=shift;
    	my $dbh = C4::Context->dbh;
		my $sth = $dbh->prepare("SELECT description FROM itemtypes WHERE itemtype = ?");
		$sth->execute($itemtype);
		$itemtype=$sth->fetchrow_array;
		return $itemtype;
    }
    
    sub CheckOverdue {
    	my $itemnumber=shift;
    	my $dbh = C4::Context->dbh;
		my $sth = $dbh->prepare("SELECT count(*) FROM issues WHERE itemnumber = ?");
		$sth->execute($itemnumber);
		$itemnumber=$sth->fetchrow_array;
		return $itemnumber;
    }
}

=head2 CancelHold

Cancel a hold for a given patron and bib

=cut

sub CancelHold {
	my ($borrowernumber, $biblionumber) = @_;
	
	my $xmlresponse = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\" ?>\n";
    $xmlresponse .= "<SimpleWebAPI_response>\n";
    
    # ERROR - No borrowernumber entered
    if (!$borrowernumber)
    {
    	$xmlresponse .= "\t<error>You must specify a borrowernumber</error>\n";
    	$xmlresponse .= "</SimpleWebAPI_response>\n";
	    return $xmlresponse;
    }
    
    # ERROR - No biblionumber entered
    if (!$biblionumber)
    {
    	$xmlresponse .= "\t<error>You must specify a biblionumber</error>\n";
    	$xmlresponse .= "</SimpleWebAPI_response>\n";
	    return $xmlresponse;
    }
    
    # ERROR - Borrower not found
    my $borrower = GetMemberDetails( $borrowernumber );
    if (!$$borrower{borrowernumber})
    {
    	$xmlresponse .= "\t<error>Borrower not found</error>\n";
    	$xmlresponse .= "</SimpleWebAPI_response>\n";
	    return $xmlresponse;
    }
    
    # ERROR - Biblio not found
    my $biblio = GetBiblio( $biblionumber );
    if (!$$biblio{biblionumber})
    {
    	$xmlresponse .= "\t<error>Biblio not found</error>\n";
    	$xmlresponse .= "</SimpleWebAPI_response>\n";
	    return $xmlresponse;
    }
    
    # ERROR - Hold not found
	my $holdmatch=0;
	my @reserves = GetReservesFromBorrowernumber( $borrowernumber, undef );
	foreach my $reserve (@reserves)
	{
		if ($$reserve{biblionumber} eq $biblionumber)
		{
			$holdmatch=1;
		}
	}
	if ($holdmatch!=1)
	{
    	$xmlresponse .= "\t<error>Hold not found</error>\n";
    	$xmlresponse .= "</SimpleWebAPI_response>\n";
	    return $xmlresponse;
	}
	CancelReserve( $biblionumber, '', $borrowernumber );
	$xmlresponse .= "\t<message>HoldCancelled</message>\n";
    $xmlresponse .= "</SimpleWebAPI_response>\n";
	return $xmlresponse;

}

=head2 RenewItem

Renew an item for a given patron and biblionumber

=cut

sub RenewItem {
	my ($borrowernumber, $biblionumber) = @_;
	
	my $xmlresponse = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\" ?>\n";
    $xmlresponse .= "<SimpleWebAPI_response>\n";
    
    # ERROR - No borrowernumber entered
    if (!$borrowernumber)
    {
    	$xmlresponse .= "\t<error>You must specify a borrowernumber</error>\n";
    	$xmlresponse .= "</SimpleWebAPI_response>\n";
	    return $xmlresponse;
    }
    
    # ERROR - No biblionumber entered
    if (!$biblionumber)
    {
    	$xmlresponse .= "\t<error>You must specify a biblionumber</error>\n";
    	$xmlresponse .= "</SimpleWebAPI_response>\n";
	    return $xmlresponse;
    }
    
    # ERROR - Borrower not found
    my $borrower = GetMemberDetails( $borrowernumber );
    if (!$$borrower{borrowernumber})
    {
    	$xmlresponse .= "\t<error>Borrower not found</error>\n";
    	$xmlresponse .= "</SimpleWebAPI_response>\n";
	    return $xmlresponse;
    }
    
    # Find item number from current borrower issues
    my $issues = GetPendingIssues($borrowernumber);
	my $itemnumber=0;

	foreach my $item (@{$issues})
	{
		if ($item->{biblionumber} eq $biblionumber)
		{
			$itemnumber=$item->{itemnumber};
		}
	}
	
	# ERROR - item not found
	if ($itemnumber==0)
	{
    	$xmlresponse .= "\t<error>Item loan not found</error>\n";
    	$xmlresponse .= "</SimpleWebAPI_response>\n";
    	return $xmlresponse;
	}

	my @renewal = CanBookBeRenewed( $borrowernumber, $itemnumber );
	if ($renewal[0]) 
	{
		my $renewalbranch = C4::Context->preference('OpacRenewalBranch');
		my $branchcode;
		if ($renewalbranch eq 'itemhomebranch'){
			my $item = GetItem($itemnumber);
			$branchcode=$item->{'homebranch'};
		}
		elsif ($renewalbranch eq 'patronhomebranch'){
			my $borrower = GetMemberDetails($borrowernumber);
			$branchcode = $borrower->{'branchcode'};
		}
		elsif ($renewalbranch eq 'checkoutbranch'){
			my $issue = GetOpenIssue($itemnumber);
			$branchcode = $issue->{'branchcode'};
		}
		elsif ($renewalbranch eq 'NULL'){
			$branchcode='';
		}
		else {
			$branchcode='OPACRenew';
		}
		AddRenewal($borrowernumber, $itemnumber, $branchcode);
	}
	else
	{
		# ERROR - item cannot be renewed
    	$xmlresponse .= "\t<error>Item cannot be renewed</error>\n";
    	$xmlresponse .= "</SimpleWebAPI_response>\n";
    	return $xmlresponse;
	}

	my $issue = GetItemIssue($itemnumber);

    $xmlresponse .= "\t<renewals>".$issue->{'renewals'}."</renewals>\n";
    $xmlresponse .= "\t<date_due>".$issue->{'date_due'}."</date_due>\n";
    $xmlresponse .= "\t<success>".$renewal[0]."</success>\n";
    $xmlresponse .= "\t<error>".$renewal[1]."</error>\n";
    $xmlresponse .= "</SimpleWebAPI_response>\n";
	return $xmlresponse;

}

=head2 RenewAll

Renew items for a given patron

=cut

sub RenewAll {
	my $borrowernumber=shift;

	my $total_items=0;
	my $total_renewed=0;
	
	my $xmlresponse = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\" ?>\n";
    $xmlresponse .= "<SimpleWebAPI_response>\n";

    # ERROR - No borrowernumber entered
    if (!$borrowernumber)
    {
    	$xmlresponse .= "\t<error>You must specify a borrowernumber</error>\n";
    	$xmlresponse .= "</SimpleWebAPI_response>\n";
	    return $xmlresponse;
    }

    # Find item numbers from current borrower issues
    my $issues = GetPendingIssues($borrowernumber);
	$total_items=scalar(@$issues);
	my $itemnumber=0;

	if ($total_items!=0)
	{
		foreach my $item (@{$issues})
		{
			$itemnumber=$item->{itemnumber};
			my @renewal = CanBookBeRenewed( $borrowernumber, $itemnumber );
			my $branchcode;
			if ($renewal[0]) 
			{
				my $renewalbranch = C4::Context->preference('OpacRenewalBranch');
				if ($renewalbranch eq 'itemhomebranch'){
					my $item = GetItem($itemnumber);
					$branchcode=$item->{'homebranch'};
				}
				elsif ($renewalbranch eq 'patronhomebranch'){
					my $borrower = GetMemberDetails($borrowernumber);
					$branchcode = $borrower->{'branchcode'};
				}
				elsif ($renewalbranch eq 'checkoutbranch'){
					my $issue = GetOpenIssue($itemnumber);
					$branchcode = $issue->{'branchcode'};
				}
				elsif ($renewalbranch eq 'NULL'){
					$branchcode='';
				}
				else {
					$branchcode='OPACRenew';
				}
				AddRenewal($borrowernumber, $itemnumber, $branchcode);
				$total_renewed++;
			}

			my $issue = GetItemIssue($itemnumber);

		}
		$xmlresponse .= "\t<total_items>".$total_items."</total_items>\n";
		$xmlresponse .= "\t<total_renewed>".$total_renewed."</total_renewed>\n";
		$xmlresponse .= "</SimpleWebAPI_response>\n";
		return $xmlresponse;
	}
	else
	{
		$xmlresponse .= "\t<total_items>0</total_items>\n";
		$xmlresponse .= "\t<total_renewed>0</total_renewed>\n";
		$xmlresponse .= "</SimpleWebAPI_response>\n";
		return $xmlresponse;
	}
}

=head2 ServiceError

If no service is requested, output error

=cut

sub ServiceError {
    my $xmlresponse = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\" ?>\n";
    $xmlresponse .= "<SimpleWebAPI_response>\n";
    $xmlresponse .= "\t<error>You must request a valid service</error>\n";
    $xmlresponse .= "</SimpleWebAPI_response>\n";
	return $xmlresponse;
}

=head2 clean_xml

Clean reserved XML characters

=cut

sub clean_xml
{
	my $xml=shift;
	$xml=~ s/&/&amp;/g;
	$xml=~ s/\"/&quot;/g;
	$xml=~ s/</&lt;/g;
	$xml=~ s/>/&gt;/g;
	return $xml;
}

=head2 HoldTitle

Create a hold for a given biblionumber and borrowernumber

=cut

sub HoldTitle {
	my ($borrowernumber, $biblionumber, $pickup_location)=@_;
	
    my $xmlresponse = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\" ?>\n";
    $xmlresponse .= "<SimpleWebAPI_response>\n";

    # ERROR - No borrowernumber entered
    if (!$borrowernumber)
    {
    	$xmlresponse .= "\t<error>You must specify a borrowernumber</error>\n";
    	$xmlresponse .= "</SimpleWebAPI_response>\n";
	    return $xmlresponse;
    }
	
    # ERROR - No biblionumber entered
    if (!$biblionumber)
    {
    	$xmlresponse .= "\t<error>You must specify a biblionumber</error>\n";
    	$xmlresponse .= "</SimpleWebAPI_response>\n";
	    return $xmlresponse;
    }
	
    # ERROR - No pickup_location entered
    if (!$pickup_location)
    {
    	$xmlresponse .= "\t<error>You must specify a pickup location</error>\n";
    	$xmlresponse .= "</SimpleWebAPI_response>\n";
	    return $xmlresponse;
    }
    
	# ERROR - borrower does not exist
	my $borrower = GetMemberDetails( $borrowernumber );
	if (!$$borrower{borrowernumber})
	{
		$xmlresponse .= "\t<error>Borrower does not exist</error>\n";
		$xmlresponse .= "</SimpleWebAPI_response>\n";
	    return $xmlresponse;
	}

	# ERROR - biblio does not exist
	my ( $count, $biblio ) = GetBiblio( $biblionumber ); #HALTON
	#my ( $biblio, $count ) = GetBiblio( $biblionumber ); #MG
	if (!$$biblio{biblionumber})
	{
		$xmlresponse .= "\t<error>Item does not exist</error>\n";
		$xmlresponse .= "</SimpleWebAPI_response>\n";
	    return $xmlresponse;
	}

	my $title = $$biblio{title};

	# ERROR - Item cannot be reserved
	if (!CanBookBeReserved($borrowernumber, $biblionumber))
	{
		$xmlresponse .= "\t<error>Item cannot be reserved</error>\n";
		$xmlresponse .= "</SimpleWebAPI_response>\n";
	    return $xmlresponse;
	}

	my $branch;

	# ERROR - Pickup branch does not exist
	my $branches=GetBranches;
	if (!$$branches{$pickup_location})
	{
		$xmlresponse .= "\t<error>Pickup branch does not exist</error>\n";
		$xmlresponse .= "</SimpleWebAPI_response>\n";
	    return $xmlresponse;
	}
	
	my $resdate = C4::Dates->today( 'iso' );
	
	my $priority;
	my ( $count, $reserves ) = GetReservesFromBiblionumber($biblionumber,1);
	
	foreach my $res (@$reserves)
	{
		if ( defined $res->{found} && $res->{found} eq 'W' )
		{
			$count--;
		}

		if ($borrowernumber eq $res->{borrowernumber} )
		{
			# ERROR - Borrower has already reserved item
			$xmlresponse .= "\t<error>You have already reserved this title</error>\n";
			$xmlresponse .= "</SimpleWebAPI_response>\n";
			return $xmlresponse;
		}
    }
    
    #ERROR - maximum reservations reached
	if (CanBookBeReserved($borrowernumber, $biblionumber)==0 )
	{
		$xmlresponse .= "\t<error>You have exceeded the maximum number of allowed reservations</error>\n";
		$xmlresponse .= "</SimpleWebAPI_response>\n";
		return $xmlresponse;
    }
	
	$priority=$count+1;
	AddReserve( $pickup_location, $borrowernumber, $biblionumber, 'a', undef, $priority, undef, $title, undef, undef );
	
	$xmlresponse.="\t<title>".clean_xml($title)."</title>\n";
	$xmlresponse.="\t<pickup_location>".GetBranchName($pickup_location)."</pickup_location>\n";
	$xmlresponse .= "</SimpleWebAPI_response>\n";
	return $xmlresponse;
}

1;