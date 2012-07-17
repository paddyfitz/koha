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

our $VERSION="0.1";
use base 'Exporter';
our @EXPORT=qw(CheckAvailability ServiceError);

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


1;