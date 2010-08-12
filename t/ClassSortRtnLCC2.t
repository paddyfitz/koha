use Test::More tests => 15;

BEGIN { use_ok( 'C4::ClassSortRoutine::LCC2' || print "Bail out!" ); }

diag( "Testing C4::ClassSortRoutine::LCC2 $C4::ClassSortRoutine::LCC::VERSION, Perl $], $^X");

my $key = C4::ClassSortRoutine::LCC2::get_class_sort_key('PS345', '');

ok( $key eq 'ps  345','simple lccn normalization');

$key = C4::ClassSortRoutine::LCC2::get_class_sort_key('E178.G35 2010','');

ok( $key eq 'e   178 g35 2010','lccn with year');

$key = C4::ClassSortRoutine::LCC2::get_class_sort_key('QA1765.9B32D45', '');

ok( $key eq 'qa 1765.9 b32 d45','normalize more complex strings');

$key = C4::ClassSortRoutine::LCC2::get_class_sort_key('', 'PS1323 H45 v.1');

ok( $key eq 'ps 1323 h45  v    1','volume normalization');

$key = C4::ClassSortRoutine::LCC2::get_class_sort_key('not a classmark', '');

ok( $key eq 'not a classmark','Non lccn normalization');

$key = C4::ClassSortRoutine::LCC2::get_class_sort_key('a lengthy prefix before W4', '');

ok( $key eq 'w     4','Ignore text before valid LCCN');

$key = C4::ClassSortRoutine::LCC2::get_class_sort_key('Fiction shelf','');

ok( $key eq 'fiction shelf','Normalize Non LC Shelfmark');

$key = C4::ClassSortRoutine::LCC2::get_class_sort_key('Thesis Econ 1994','');

ok( $key eq 'thesis econ 1994','Non LC including numeric');

$key = C4::ClassSortRoutine::LCC2::get_class_sort_key('H1 B45 B3 1987','');

ok( $key eq 'h     1 b45 b3 1987','Multiple elements plus date');

$key = C4::ClassSortRoutine::LCC2::get_class_sort_key('M452F237Q3','');

ok( $key eq 'm   452 f237 q3','Multple elements without spaces');

$key = C4::ClassSortRoutine::LCC2::get_class_sort_key('PS1323.5 H45 v.1','');

ok( $key eq 'ps 1323.5 h45  v    1','Decimal and volume');

$key = C4::ClassSortRoutine::LCC2::get_class_sort_key('REF H1 B45','');

ok( $key eq 'h     1 b45','Ignore prestamps');

$key = C4::ClassSortRoutine::LCC2::get_class_sort_key('Thesis Econ 1994 W4','');
ok( $key eq 'w     4','Ignore non-lc prestamp');

$key = C4::ClassSortRoutine::LCC2::get_class_sort_key('Thesis EE 1994 W4','');
ok( $key eq 'w     4','Ignore non-lc prestamp with code');
