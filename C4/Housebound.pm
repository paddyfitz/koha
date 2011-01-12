package C4::Housebound;

# Mark Gavillet

use strict;
use C4::Context;

our ($VERSION,@ISA,@EXPORT,@EXPORT_OK,$debug);

BEGIN {
	$VERSION = 3.02;
	$debug = $ENV{DEBUG} || 0;
	require Exporter;
	@ISA = qw(Exporter);
	push @EXPORT, qw(
		&GetHouseboundDetails
		&CreateHouseboundDetails
		&UpdateHouseboundDetails
		&GetCurrentHouseboundInstanceList
		&GetHouseboundInstanceDetails
		&UpdateHouseboundInstanceDetails
		&CreateHouseboundInstanceDetails
		&DeleteHouseboundInstanceDetails
		&GetVolunteerNameAndID
		&GetVolunteerList
	) 
};

=head1 NAME

C4::Housebound - Perl Module containing functions for housebound patrons

=head1 SYNOPSIS

use C4::Housebound;

=head1 DESCRIPTION

This module contains routines for adding, modifying and deleting housebound details for patrons, and instances of item delivery by volunteers 

=head1 FUNCTIONS

=over 2

=item GetHouseboundDetails

  ($hbnumber, $day, $frequency, $borrowernumber, $Itype_quant, $Item_subject, $Item_authors, $referral, $notes) = &SearchMember($borrowernumber);

=back

Values returned
$hbnumber 			- the id of the database record in table housebound
$day				- preferred day of the week for delivery
$frequency			- pattern of delivery (e.g. weeks 1/3, week 4, etc.)
$borrowernumber		- borrowernumber that is fed into the function, returned for convenience
$Itype_quant		- one or more values from the list of loanable Itypes (e.g. 2 BKS, 1 DVD, etc.)
$Item_subject		- one or more values defining subjects the borrower is interested in
$Item_authors		- one or more values defining authors the borrower is interested in
$referral			- person or organisation that referred this borrower
$notes				- freetext notes containing useful information about the patron (e.g. beware of the dog!)

=cut

sub GetHouseboundDetails
{
    my ($borrowernumber) = @_;
    my $dbh = C4::Context->dbh;
    my $query;
    my $sth;
    if ($borrowernumber)
	{
        $sth = $dbh->prepare("select * from housebound where borrowernumber=?");
        $sth->execute($borrowernumber);
    }
    else
	{
        return undef;
    }
    my $housebound = $sth->fetchrow_hashref;
    return ($housebound);
}


sub CreateHouseboundDetails
{
    my ($borrowernumber, $day, $frequency, $Itype_quant, $Item_subject, $Item_authors, $referral, $notes) = @_;
    my $dbh = C4::Context->dbh;
    my $query;
    my $sth;
	if ($borrowernumber)
	{
        $sth = $dbh->prepare("insert into housebound (day, frequency, borrowernumber, Itype_quant, Item_subject, Item_authors, referral, notes) values (?,?,?,?,?,?,?,?)");
        $sth->execute($day,$frequency,$borrowernumber,$Itype_quant,$Item_subject,$Item_authors,$referral,$notes);
	}
	else
	{
		return undef;
	}
}


sub UpdateHouseboundDetails
{
    my ($hbnumber, $borrowernumber, $day, $frequency, $Itype_quant, $Item_subject, $Item_authors, $referral, $notes) = @_;
    my $dbh = C4::Context->dbh;
    my $query;
    my $sth;
	if ($hbnumber)
	{
        $sth = $dbh->prepare("update housebound set day=?,frequency=?,borrowernumber=?,Itype_quant=?,Item_subject=?,Item_authors=?,referral=?,notes=? where hbnumber=?");
        $sth->execute($day,$frequency,$borrowernumber,$Itype_quant,$Item_subject,$Item_authors,$referral,$notes,$hbnumber);
	}
	else
	{
		return undef;
	}
}


sub GetCurrentHouseboundInstanceList
{
    my ($borrowernumber) = @_;
    my $dbh = C4::Context->dbh;
    my $query;
    my $sth;
    if ($borrowernumber)
	{
        #$sth = $dbh->prepare("select * from housebound_instance where borrowernumber=?");
		$sth = $dbh->prepare("SELECT housebound_instance . * , concat( volunteer.firstname, ' ', volunteer.surname ) AS vol, concat(chooser.firstname, ' ', chooser.surname) as cho, concat(deliverer.firstname, ' ', deliverer.surname) as del FROM housebound_instance left JOIN borrowers volunteer ON volunteer.borrowernumber = housebound_instance.volunteer left join borrowers chooser on chooser.borrowernumber = housebound_instance.chooser left join borrowers deliverer on deliverer.borrowernumber = housebound_instance.deliverer where housebound_instance.borrowernumber=? order by housebound_instance.dmy desc");
        $sth->execute($borrowernumber);
    }
    else
	{
        return undef;
    }
    my $housebound_instances = $sth->fetchall_arrayref({});
		
    return (scalar(@$housebound_instances),$housebound_instances);	
}

sub GetVolunteerNameAndID
{
    my ($borrowernumber) = @_;
    my $dbh = C4::Context->dbh;
    my $query;
    my $sth;
    if ($borrowernumber)
	{
        $sth = $dbh->prepare("select borrowernumber,title,firstname,surname from borrowers where borrowernumber=?");
        $sth->execute($borrowernumber);
    }
    else
	{
        return undef;
    }
    my $volunteer = $sth->fetchrow_hashref;
    return ($volunteer);	
}


sub GetVolunteerList
{
    my $dbh = C4::Context->dbh;
    my $query;
    my $sth;
	$sth = $dbh->prepare("SELECT borrowernumber as volbornumber, concat(title, ' ', firstname, ' ', surname) as fullname from borrowers where categorycode='VOL' order by surname, firstname asc");
	$sth->execute();
	my $volunteers=$sth->fetchall_arrayref({});
	return (scalar(@$volunteers),$volunteers);
}


sub GetHouseboundInstanceDetails
{
    my ($instanceid) = @_;
    my $dbh = C4::Context->dbh;
    my $query;
    my $sth;
    if ($instanceid)
	{
        $sth = $dbh->prepare("SELECT * from housebound_instance where instanceid=?");
        $sth->execute($instanceid);
    }
    else
	{
        return undef;
    }
    my $instancedetails = $sth->fetchrow_hashref;
    return ($instancedetails);	
}


sub UpdateHouseboundInstanceDetails
{
    my ($instanceid, $hbnumber, $dmy, $time, $borrowernumber, $volunteer, $chooser, $deliverer) = @_;
    my $dbh = C4::Context->dbh;
    my $query;
    my $sth;
	if ($hbnumber)
	{
        $sth = $dbh->prepare("update housebound_instance set hbnumber=?, dmy=?, time=?, borrowernumber=?, volunteer=?, chooser=?, deliverer=? where instanceid=?");
        $sth->execute($hbnumber,$dmy,$time,$borrowernumber,$volunteer,$chooser,$deliverer,$instanceid);
	}
	else
	{
		return undef;
	}
}


sub CreateHouseboundInstanceDetails
{
    my ($hbnumber, $dmy, $time, $borrowernumber, $volunteer, $chooser, $deliverer) = @_;
    my $dbh = C4::Context->dbh;
    my $query;
    my $sth;
	if ($borrowernumber)
	{
        $sth = $dbh->prepare("insert into housebound_instance (hbnumber, dmy, time, borrowernumber, volunteer, chooser, deliverer) values (?,?,?,?,?,?,?)");
        $sth->execute($hbnumber,$dmy,$time,$borrowernumber,$volunteer,$chooser,$deliverer);
	}
	else
	{
		return undef;
	}
}

sub DeleteHouseboundInstanceDetails
{
	my ($instanceid) =@_;
    my $dbh = C4::Context->dbh;
    my $query;
    my $sth;
	if ($instanceid)
	{
        $sth = $dbh->prepare("delete from housebound_instance where instanceid=?");
        $sth->execute($instanceid);
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
