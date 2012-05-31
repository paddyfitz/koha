#!/usr/bin/env perl
use strict;
use warnings;
use 5.10.0;
use C4::Context;
use DateTime;

my $dbh = C4::Context->dbh;

my $itype = '';
my $newitype = '';
my @myTypes;

@myTypes = ( 'DVDM16_12', 'DVDM16_15', 'DVDM16_18', 'DVDM16_PG', 'DVDM16_U' );
foreach (@myTypes) {
    print "$_\n";
    my $sql =
'UPDATE items set itype = ? where itype = ? and dateaccessioned = DATE_SUB(curdate(),INTERVAL 112 day)';
    my $sth      = $dbh->prepare($sql);
    my $itype    = $_;
    my $newitype = $itype;
    $newitype =~ s/16//;
    print "$newitype\n";
    #print "$sql\n";
    my $dt = DateTime->now;

    #$sth->execute( $newitype, $itype );
}

__END__

= head1 Update all DVD16_ itypes to DVDM

Designed to run every night

Updates all items with itype DVD16% to DVDM where dateaccessioned is 112 days 
ago (16 weeks).

