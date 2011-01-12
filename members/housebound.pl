#!/usr/bin/perl

# Mark Gavillet

use strict;
use warnings;
use CGI;
use C4::Context;
use C4::Auth;
use C4::Output;
use C4::Members;
use C4::Koha;
use C4::Branch;
use C4::Housebound;

use vars qw($debug);

BEGIN {
		$debug = $ENV{DEBUG} || 0;
}

my $input=CGI->new();
#print $input->header;
#print "test";

sub nl2br
{
	my ($t) = shift or return;
	$t =~ s/\n/\n<br>/g;
	return ($t);
}

my $dbh = C4::Context->dbh;

my ($template, $loggedinuser, $cookie)
	= get_template_and_user({template_name => "members/housebound.tmpl",
		query => $input,
		type => "intranet",
		authnotrequired => 0,
		flagsrequired => {borrowers => 1},
		debug => ($debug) ? 1 : 0,
	});

my $borrowernumber	= $input->param('borrowernumber');
#print "<br>$borrowernumber";

my $borrowerdetails=C4::Members::GetMemberDetails($borrowernumber);
my $branchdetail = GetBranchDetail( $borrowerdetails->{'branchcode'});
my $categorydetail = GetMember($borrowernumber ,'borrowernumber');
my $housebound = GetHouseboundDetails($borrowernumber);
my $housebound_instances = GetCurrentHouseboundInstanceList($borrowernumber);



$template->param(surname => $borrowerdetails->{'surname'}, firstname=>$borrowerdetails->{'firstname'}, cardnumber=>$borrowerdetails->{'cardnumber'}, borrowernumber=>$borrowerdetails->{'borrowernumber'}, houseboundview=>'on', address=>$borrowerdetails->{'address'}, address2=>$borrowerdetails->{'address2'}, city=>$borrowerdetails->{'city'}, phone=>$borrowerdetails->{'phone'}, phonepro=>$borrowerdetails->{'phonepro'}, mobile=>$borrowerdetails->{'mobile'}, email=>$borrowerdetails->{'email'}, emailpro=>$borrowerdetails->{'emailpro'}, categoryname=>$categorydetail->{'description'}, categorycode=>$borrowerdetails->{'categorycode'}, branch=>$borrowerdetails->{'branch'}, branchname=>$branchdetail->{branchname}, zipcode=>$borrowerdetails->{'zipcode'});

$template->param(hbnumber => $housebound->{'hbnumber'}, day => $housebound->{'day'}, frequency => $housebound->{'frequency'}, Itype_quant => $housebound->{'Itype_quant'}, Item_subject => $housebound->{'Item_subject'}, Item_authors => $housebound->{'Item_authors'}, referral => $housebound->{'referral'}, notes => $housebound->{'notes'});

if ($housebound_instances)
{
	$template->param(instanceloop => $housebound_instances);
}

output_html_with_http_headers $input, $cookie, $template->output;

my $borrowername=$borrowerdetails->{'surname'};
#print $borrowername;

##for my $key (keys %{$borrowerdetails}) {
##          print "$key => ${$borrowerdetails}{$key}<br>\n";
##        }

##for my $key (keys %{$housebound}) {
##          print "$key => ${$housebound}{$key}<br>\n";
##        }

####for my $key (keys %{$housebound_instances}) {
####          print "$key => ${$housebound_instances}{$key}<br>\n";
####        }

####while ( my ($key, $value) = each(%$housebound_instances) ) {
####        print "$key => $value\n";
####    }

#use Data::Dumper;
#print Dumper(\$housebound_instances);

#foreach my $row(%$housebound_instances)
#{
	#while ( my ($key, $value) = each(%$row) ) {
	#        print "$key => $value<br />";
	#    }
#	print "%$row<br>";
#}

####foreach my $key (keys(%{$housebound_instances}))
####{
####	print "$housebound_instances->{$key}->{'surname'}<br>";
####}

#####foreach my $row(@{$hounsebound_instances})
#####{
#####	print "@row<br>";
#####	}

#foreach my $r ({$housebound_instances})
#{
#	print join(", ",@{$r}),"<br>";
#}


#foreach my $row(@$housebound_instances)
#{
#	while (my $key,$value)=each($row))
#	{
#		print "$key - $value<br>";
#	}
#	#print "$row<br>";
#}
