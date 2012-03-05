#!/usr/bin/perl

use warnings;
use strict;

use CGI;
use CGI::Carp qw( fatalsToBrowser );
use CGI::Untaint;
use CGI::Untaint::email;
use CGI::Untaint::uk_postcode;
use CGI::Untaint::date;
use Date::Simple qw( today );
use Mail::Sendmail;
use Readonly;

#Readonly my $staff_email => 'jonathan.field@ptfs-europe.com';
Readonly my $staff_email => 'Jeff.Proffitt@halton.gov.uk';

#Readonly my $staff_email => 'Haltonlea.library@halton.gov.uk';
Readonly my $from_addr  => 'Haltonlea.library@halton.gov.uk';
Readonly my $mailserver => 'localhost';

my $q = CGI->new;

my $handler = CGI::Untaint->new( $q->Vars );

my $email_addr = $handler->extract( -as_email => 'email_address' );
if ( my $err_str = $handler->error ) {
    error( $q, $err_str );
}
my $firstname = $handler->extract( -as_printable   => 'firstname' );
my $title     = $handler->extract( -as_printable   => 'title' );
my $surname   = $handler->extract( -as_printable   => 'surname' );
my $dob       = $handler->extract( -as_date        => 'dob' );
my $property  = $handler->extract( -as_printable   => 'property' );
my $address   = $handler->extract( -as_printable   => 'address' );
my $address2  = $handler->extract( -as_printable   => 'address2' );
my $town      = $handler->extract( -as_printable   => 'town' );
my $county    = $handler->extract( -as_printable   => 'county' );
my $postcode  = $handler->extract( -as_uk_postcode => 'postcode' );
my $phone     = $handler->extract( -as_printable   => 'phone' );
my $mobile    = $handler->extract( -as_printable   => 'mobile' );
my $branch    = $handler->extract( -as_printable   => 'branch' );

my $date_time = today();

my $msg =
    "\n\nTitle: $title\nFirst Name: $firstname\nSurname: $surname\nDOB: "
  . $dob->as_str('%d-%m-%Y')
  . "\nProperty: $property\nAddress: $address\nAddress 2: $address2\n"
  . "Town: $town\nCounty: $county\nPostcode: $postcode\n"
  . "Phone: $phone\nMobile: $mobile\nContact email: "
  . $email_addr->format
  . "\nBranch: $branch\nRegistration Date: "
  . $date_time->as_str('%d-%m-%Y')
  . "\n\n. ";

my %mail = (
    To             => $email_addr->format,
    From           => $from_addr,
    Subject        => 'New Library User Registration Request Notification',
    'Content-Type' => 'text/plain; charset=utf-8',
    'Content-Transfer-Encoding' => 'quoted-printable',
    Message =>
"Thank you for registering for the library.  The following details have been recorded:$msg",
    Smtp => $mailserver,
);

sendmail(%mail) or croak $Mail::Sendmail::error;

my %alert = (
    To             => $staff_email,
    From           => $from_addr,
    Subject        => 'New User Registration Request alert',
    'Content-Type' => 'text/plain; charset=utf-8',
    Message =>
      "The following patron has requested to register with the library :$msg",
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
   <p><b>DOB:</b>} . $dob->as_str('%d-%m-%Y') . qq{</p>
   <p><b>Address:</b> $property $address, $address2, $town, $county, $postcode</p>
   <p><b>Phone:</b> $phone</p>
   <p><b>Mobile:</b> $mobile</p>
   <p><b>Email address:</b>} . $email_addr->format . qq{</p>
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
