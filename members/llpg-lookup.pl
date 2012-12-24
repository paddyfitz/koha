#!/usr/bin/env perl 

use strict;
use warnings;
use 5.010;
use XML::Compile::WSDL11 ();
use XML::Compile::SOAP11;
use XML::Compile::Transport::SOAPHTTP;
use CGI;
use URI::Escape;
use JSON;

# read soap params
my $wsdlfile = q/LlpgSearchService.asmx.xml/;
my $wsdl     = XML::Compile::WSDL11->new($wsdlfile);
my $server   = 'llpguser:4zSr17pd@www.halton.gov.uk';

# read CGI params
my $input        = CGI->new();
my $streetnumber = $input->param('streetnumber');

#$streetnumber  = uri_unescape($streetnumber);
my $address = $input->param('address');

#$address  = uri_unescape($address);
my $zipcode = $input->param('zipcode');
$zipcode = uri_unescape($zipcode);

# invoke llpg client
my $call = $wsdl->compileClient(
    'GetAddressesByComponents',
    server => $server,
    port   => 'LlpgSearchServiceSoap'
);

# do lookup
my $addr = lookup_address(
    Postcode   => $zipcode,
    PropertyNo => $streetnumber,
    Street     => $address
);

#my $addr = lookup_address( Postcode => "WA8 0QT", PropertyNo => "$streetnumber", Street => "West Bank" );

# create a JSON string according to the database result
my $json;
if ( @{$addr} == 1 ) {
    $json = {
        single       => q|LLPG Returned a single result|,
        streetnumber => $addr->[0]->{FullPropertyName},
        streettype   => q{},
        address      => $addr->[0]->{Street},
        address2     => q{},
        city         => $addr->[0]->{Town},
        state        => $addr->[0]->{County},
        zipcode      => $addr->[0]->{Postcode},
        country      => q{UK},
    };
}
elsif ( @{$addr} > 1 ) {
    my $arr = [];

    foreach my $address ( @{$addr} ) {
        push @{$arr},
          {
            streetnumber => $address->{FullPropertyName},
            streettype   => q{},
            address      => $address->{Street},
            address2     => q{},
            city         => $address->{Town},
            state        => $address->{County},
            zipcode      => $address->{Postcode},
            country      => q{UK},
          };
    }
    $json = {
        multiple  => 'Please select an address',
        addresses => $arr,
    };
}
else {
    $json = { error => 'An error occured', };
}
my $jtext = encode_json($json);

# return JSON string
print $input->header( -type => 'application/json', -charset => 'utf-8' ),
  $jtext;

sub lookup_address {
    my @params = @_;

    my ( $answer, $trace ) = $call->(@params);

    if ( my $f = $answer->{Fault} ) {
        my $errname = $f->{_NAME};
        my $error   = $answer->{$errname};
        say $error->{code};

        print $input->header(
            -type    => 'application/json',
            -charset => 'utf-8'
          ),
          encode_json( { error => 'An error occured', } );
        exit;
    }
    return $answer->{parameters}->{GetAddressesByComponentsResult}
      ->{LlpgAddress};
}
