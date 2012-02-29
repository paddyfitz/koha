#!/usr/bin/perl

use warnings;
use strict;

use CGI;
use CGI::Carp qw( fatalsToBrowser );
use Mail::Sendmail;
use Readonly;

#Readonly my $staff_email => 'jonathan.field@ptfs-europe.com';
Readonly my $staff_email => 'Jeff.Proffitt@halton.gov.uk';
#Readonly my $staff_email => 'Haltonlea.library@halton.gov.uk';
Readonly my $from_addr   => 'Haltonlea.library@halton.gov.uk';
Readonly my $mailserver  => 'localhost';

my $q = CGI->new;

my $firstname    = $q->param('firstname');
my $title     = $q->param('title');
my $surname = $q->param('surname');
my $dob   = $q->param('dob');
my $property      = $q->param('property');
my $address     = $q->param('address');
my $address2     = $q->param('address2');
my $town     = $q->param('town');
my $county     = $q->param('county');
my $postcode     = $q->param('postcode');
my $phone     = $q->param('phone');
my $mobile     = $q->param('mobile');
my $email_addr = $q->param('email_address');

my $branch = $q->param('branch');

my $date_time = localtime;

if (!$email_addr) {
        error( $q, 'No Email provided');
    }

if ($email_addr) {

    my %mail = (
        To                          => $email_addr,
        From                        => $from_addr,
        Subject                     => 'New Library User Registration Request Notification',
        'Content-Type'              => 'text/plain; charset=utf-8',
        'Content-Transfer-Encoding' => 'quoted-printable',
        Message =>
"Thank you for registering for the library.  The following details have been recorded:\n\nTitle: $title\nFirst Name: $firstname\nSurname: $surname\nDOB: $dob\nProperty: $property\nAddress: $address\nAddress 2: $address2\nTown: $town\nCounty: $county\nPostcode: $postcode\nPhone: $phone\nMobile: $mobile\nContact email: $email_addr\nBranch: $branch\nRegistration Date: $date_time\n\n. ",
        Smtp => $mailserver,
    );

    sendmail(%mail) or croak $Mail::Sendmail::error;
}

my %alert = (
    To             => $staff_email,
    From           => $from_addr,
    Subject        => 'New User Registration Request alert',
    'Content-Type' => 'text/plain; charset=utf-8',
    Message =>
"The following patron has requested to register with the library :\n\nTitle: $title\nFirst Name: $firstname\nSurname: $surname\nDOB: $dob\nProperty: $property\nAddress: $address\nAddress 2: $address2\nTown: $town\nCounty: $county\nPostcode: $postcode\nPhone: $phone\nMobile: $mobile\nContact email: $email_addr\nBranch: $branch\nRegistration Date: $date_time\n\n. ",
    Smtp => $mailserver,
);

sendmail(%alert) or croak $Mail::Sendmail::error;

my $html =
qq{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
   <meta http-equiv="Content-Type" content="text/html"; charset="utf-8" />
   <title>Thanks!</title>
   <style type="text/css">
     img {border: none;}
   </style>
 </head>
 <body>
   <p><b>Thank you for registering. We will get back to you as soon as possible</b></p>
   <p><b>Your name:</b> $title $firstname $surname</p>
   <p><b>DOB:</b> $dob</p>
   <p><b>Address:</b> $property $address, $address2, $town, $county, $postcode</p>
   <p><b>Phone:</b> $phone</p>
   <p><b>Mobile:</b> $mobile</p>
   <p><b>Email address:</b> $email_addr</p>
   <p><b>Branch:</b> $branch</p>
   };

$html .= qq{
   <p>To return to the form, <a href="http://kohalibrary.halton.gov.uk/cgi-bin/koha/opac-newuser.pl">click here</a></p>
   <p><A HREF="javascript:window.print()">Print Page</A></p>
 </body>
</html>
};
print $q->header;
print $html;

sub error {
    my ( $qq, $reason ) = @_;

    print $qq->header('text/html'), $qq->start_html('Error'), $qq->h1('Error'),
      $qq->p(
        'Your request was not processed because the following error ',
        'occured: '
      ),
      $qq->p( $q->i($reason) ),
      $qq->p(
        'Please click the back button on your browser to return to the form '),
      $qq->end_html;
    exit;
}
