#!/usr/bin/env perl
use strict;
use warnings;
use 5.10.0;
use C4::Context;
use DateTime;

my $dbh = C4::Context->dbh;

# dateexpiry;
# categorycode
# borrowernumber
my $sql = 'UPDATE borrowers set categorycode = ?, dateexpiry = ? where categorycode = ?';
my $sth = $dbh->prepare($sql);
my $newexpiry = '2050-03-31';
my $newcat    = 'A';
my $dt        = DateTime->now;
my $oldcat    = 'AL' . $dt->year;

$sth->execute($newcat, $newexpiry, $oldcat);


__END__
= head1 Update all AL9999 users to A

Designed to ruin once a year on 31st Mar/ 1st April

Updates all users with category AL9999 where 9999 is the current year
to A ('Adult') and sets their expirydate to 2050


