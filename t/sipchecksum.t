
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../C4/SIP"; # sip software doesn't use Koha's PERL5LIB 
use Test::More tests => 8;

require_ok('Sip::Checksum');

my $c = Sip::Checksum::checksum('97AZ');
my $cstr = sprintf '%04.4X', $c;

cmp_ok( $cstr, 'eq', 'FEF5', 'Checksum minimal calculation' );

my $msg1 =
'101YNN20110524    165019AOWID|AB34148008815190|AQWID|AJThe illusion of murder /|AA24148000241041|CRT|AY6AZ';
my $chksum1 = 'E348';

my $msg2 =
q{101YNN20110524    165019AOWID|AB34148004236888|AQWID|AJIn search of Schrödinger's cat /|AA24148000553262|CRSCI|CS530.12|AY0AZ};
my $chksum2 = 'DCAA';

$c = Sip::Checksum::checksum($msg1);
$cstr = sprintf '%04.4X', $c;
cmp_ok( $cstr, 'eq', $chksum1, 'Checksum calculated correctly on ascii only' );

$msg1 .= $chksum1;
my $ret = Sip::Checksum::verify_cksum($msg1);
cmp_ok( $ret, '==', 1, 'Checksum verifys ok' );

$c = Sip::Checksum::checksum($msg2);
$cstr = sprintf '%04.4X', $c;
cmp_ok( $cstr, 'eq', $chksum2,
    'Checksum calculated correctly with non-ascii chars' );

$msg2 .= $chksum2;
$ret = Sip::Checksum::verify_cksum($msg2);
cmp_ok( $ret, '==', 1, 'Checksum verifys ok' );

$ret = Sip::Checksum::verify_cksum('97');
cmp_ok( $ret, '==', 0, 'Correct return if no checksum' );

$ret = Sip::Checksum::verify_cksum('97AZBEEF');
cmp_ok( $ret, '==', 0, 'Correct return if checksum fails validation' );

