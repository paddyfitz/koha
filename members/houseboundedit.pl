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


my $dbh = C4::Context->dbh;

my ($template, $loggedinuser, $cookie)
	= get_template_and_user({template_name => "members/houseboundedit.tmpl",
		query => $input,
		type => "intranet",
		authnotrequired => 0,
		flagsrequired => {borrowers => 1},
		debug => ($debug) ? 1 : 0,
	});

my $borrowernumber	= $input->param('borrowernumber');
#print "<br>$borrowernumber";
my $op = $input->param('op');
if ($op eq "editsubmit")
{
	UpdateHouseboundDetails($input->param('hbnumber'),$input->param('borrowernumber'),$input->param('day'),$input->param('frequency'),$input->param('Itype_quant'),$input->param('Item_subject'),$input->param('Item_authors'),$input->param('referral'),$input->param('notes'));
	my $url="/cgi-bin/koha/members/housebound.pl?borrowernumber=$borrowernumber";
	print "Location: $url";
}
if ($op eq "addsubmit")
{
	CreateHouseboundDetails($input->param('borrowernumber'),$input->param('day'),$input->param('frequency'),$input->param('Itype_quant'),$input->param('Item_subject'),$input->param('Item_authors'),$input->param('referral'),$input->param('notes'));
	my $url="/cgi-bin/koha/members/housebound.pl?borrowernumber=$borrowernumber";
	print "Location: $url";
}
if ($op eq "edit")
{
	$template->param(opeditsubmit => "editsubmit");	
}
if ($op eq "add")
{
	$template->param(opaddsubmit => "addsubmit");
}


my $borrowerdetails=C4::Members::GetMemberDetails($borrowernumber);
my $branchdetail = GetBranchDetail( $borrowerdetails->{'branchcode'});
my $categorydetail = GetMember($borrowernumber ,'borrowernumber');
my $housebound = GetHouseboundDetails($borrowernumber);

$template->param(surname => $borrowerdetails->{'surname'}, firstname=>$borrowerdetails->{'firstname'}, cardnumber=>$borrowerdetails->{'cardnumber'}, borrowernumber=>$borrowerdetails->{'borrowernumber'}, houseboundview=>'on', address=>$borrowerdetails->{'address'}, address2=>$borrowerdetails->{'address2'}, city=>$borrowerdetails->{'city'}, phone=>$borrowerdetails->{'phone'}, phonepro=>$borrowerdetails->{'phonepro'}, mobile=>$borrowerdetails->{'mobile'}, email=>$borrowerdetails->{'email'}, emailpro=>$borrowerdetails->{'emailpro'}, categoryname=>$categorydetail->{'description'}, categorycode=>$borrowerdetails->{'categorycode'}, branch=>$borrowerdetails->{'branch'}, branchname=>$branchdetail->{branchname}, zipcode=>$borrowerdetails->{'zipcode'});

$template->param(hbnumber => $housebound->{'hbnumber'}, day => $housebound->{'day'}, frequency => $housebound->{'frequency'}, Itype_quant => $housebound->{'Itype_quant'}, Item_subject => $housebound->{'Item_subject'}, Item_authors => $housebound->{'Item_authors'}, referral => $housebound->{'referral'}, notes => $housebound->{'notes'});

if ($housebound->{'day'} eq "Sunday")
{
	$template->param(dsun => 1);
}
elsif ($housebound->{'day'} eq "Monday")
{
	$template->param(dmon => 1);
}
elsif ($housebound->{'day'} eq "Tuesday")
{
	$template->param(dtue => 1);
}
elsif ($housebound->{'day'} eq "Wednesday")
{
	$template->param(dwed => 1);
}
elsif ($housebound->{'day'} eq "Thursday")
{
	$template->param(dthu => 1);
}
elsif ($housebound->{'day'} eq "Friday")
{
	$template->param(dfri => 1);
}
elsif ($housebound->{'day'} eq "Saturday")
{
	$template->param(dsat => 1);
}

if ($housebound->{'frequency'} eq "Week 1/3")
{
	$template->param(wk1 => 1);
}
elsif ($housebound->{'frequency'} eq "Week 2/4")
{
	$template->param(wk2 => 1);
}

#print "*".$housebound->{'day'}."*";

output_html_with_http_headers $input, $cookie, $template->output;

