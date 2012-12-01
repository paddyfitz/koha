#!/usr/bin/env perl 

use strict;
use warnings;
use 5.10.1;
use XML::Compile::WSDL11 ();
use XML::Compile::SOAP11;
use XML::Compile::Transport::SOAPHTTP;
use CGI;

# read soap params
my $wsdlfile = q/LlpgSearchService.asmx.xml/;
my $wsdl = XML::Compile::WSDL11->new($wsdlfile);
my $server = 'llpguser:4zSr17pd@www.halton.gov.uk';

# read CGI params
my $input = new CGI;
my $streetnumber = $input->param("streetnumber");
my $address = $input->param("address");
my $zipcode = $input->param("zipcode");

# invoke llpg client
my $call = $wsdl->compileClient('GetAddressesByComponents', server => $server, port => 'LlpgSearchServiceSoap');

# do lookup
my $addr = lookup_address( Postcode => "$zipcode", PropertyNo => "$streetnumber", Street => "$address" );

# create a JSON string according to the database result
my $json;
if ( @$addr == 1 ) {
    $json = "{ \"single\" : \"LLPG Returned a single result\", ";
    $json .= "\"streetnumber\" : \"@$addr[0]->{FullPropertyName}\", ";
    $json .= "\"address\" : \"@$addr[0]->{Street}\", ";
    $json .= "\"address2\" : \"@$addr[0]->{Town}\", ";
    $json .= "\"zipcode\" : \"@$addr[0]->{Postcode}\" }";
}
elsif ( @$addr >> 1 ) {
    $json = "{ \"multiple\" : \"Please select an address\", \"addresses\" : [ ";
    foreach my $address (@$addr) {
        $json .= "{ \"streetnumber\" : \"$address->{FullPropertyName}\",";
        $json .= "\"address: \" : \"$address->{Street}\",";
        $json .= "\"address2: \" : \"$address->{Town}\",";
        $json .= "\"address3: \" : \"$address->{County}\",";
        $json .= "\"zipcode: \" : \"$address->{Postcode}\" } ";
    }
    $json .= "] }";
}
else {
    $json = "{ \"error\" : \"An error occured\" }";
}

# return JSON string
print $input->header(-type => "application/json", -charset => "utf-8");
print $json;

sub lookup_address {
    my @params = @_;

    my ($answer, $trace) = $call->(@params);

    if ( my $f = $answer->{Fault} ) {
        my $errname = $f->{_NAME};
        my $error = $answer->{$errname};
        say $error->{code};

        my $details = $error->{detail};
        if (! $details) {
            # system error, bo details
        }
        exit 1;
    }
    return $answer->{parameters}->{GetAddressesByComponentsResult}->{LlpgAddress};;
    return $answer;
}
