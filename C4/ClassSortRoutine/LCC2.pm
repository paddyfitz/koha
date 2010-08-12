package C4::ClassSortRoutine::LCC2;

use strict;
use warnings;

use version; our $VERSION = qw('0.0.1');

sub get_class_sort_key {
    my ( $cn_class, $cn_item ) = @_;

    $cn_class ||= q{};
    $cn_item  ||= q{};
    my $key = lc "$cn_class $cn_item";
    $key =~ s/\s*$//;
    my $norm_key = q| | x 7;
    if ( $key =~ m/.*?([a-z]{1,3})(\d{1,4})(.*)/ ) {    # find the main lccn
        my ( $alpha, $num, $rem ) = ( $1, $2, $3 );
        substr $norm_key, 0, length($alpha), $alpha;
        my $offset = 3 + ( 4 - length($num) );
        substr $norm_key, $offset, length($num), $num;
        if ($rem) {
            if ( $rem =~ s/^(\.\d+)// ) {
                $norm_key .= $1;
            }
            if ($rem) {
                $rem =~ s/v\.(\d)/V_$1/g;
                $rem =~ s/no\.(\d)/NO_$1/g;
                $rem =~ s/cop.(\d)/COP_$1/g;
                $rem =~ s/\W/ /g;
                $rem =~ s/  +/ /;
                $rem =~ s/^ //;
                $rem =~ s/(\d)([a-z])/$1 $2/g;
                while ( $rem =~ m/V_(\d+)/ )
                {    # ensure volumes sort before years
                    my $n           = $1;
                    my $replacement = ' v';
                    my $num_length  = length $n;
                    if ( $num_length < 5 ) {
                        $replacement .= ( q{ } x ( 5 - $num_length ) );
                    }
                    $replacement .= $n;
                    $rem =~ s/V_$n/$replacement/;
                }

                while ( $rem =~ m/NO_(\d+)/ ) {
                    my $n           = $1;
                    my $replacement = ' no';
                    my $num_length  = length($n);
                    if ( $num_length < 5 ) {
                        $replacement .= ( q{ } x ( 5 - $num_length ) );
                    }
                    $replacement .= $n;
                    $rem =~ s/NO_$n/$replacement/;
                }
                $norm_key .= " $rem";
            }
        }
        return $norm_key;
    } else {
        return $key;
    }
}

1;
__END__

=head1 NAME 

C4::ClassSortRoutine::LCC2 - LC call number sorting key routine

=head1 VERSION

This Documentation refers to C4::ClassSortRoutine::LCC2 Version 0.0.1

=head1 SYNOPSIS

use C4::ClassSortRoutine;

my $cn_sort = GetClassSortKey('LCC2', $cn_class, $cn_item);

=head1 DESCRIPTION

This routine normalizes LCC call numbers skipping any prestamps

For the purpose of this routine LC call numbers are defined as 1-3 alphabetic
characters followed by 1-4 numeric characters. Data in the field preceding a valid
LC call number is skipped (i.e. prestamps are ignored).
The normalized key reserves 3 characters for the alpha portion and 4 characters for
the numeric portion i. e. PS345 normalizes to

ps  345

If a decimal value follows the class number, the decimal point and the number are
appended immediately after the class number.
If there is any additional data consisting of letters followed without space by numbers,
a space is inserted after the class number or decimal portion, if any, and then
the additional data is inserted. When it is inserted, a blank space is added between each
number portion and the next letter.

Any remaining characters in the call number are then normalized and appended.
The normalization rules applied to these remaining characters are: replace punctuation with a single space;
collapse multiple spaces to a single space;
translate all characters to lowercase;
numbers preceded by "v." or "no." take up 5 spaces and are right justified ending in the fifth position.

If no elements of the call number fit the LC pattern, the entire field is indexed character-by-character.

For examples see the tests in t/ClassSortRtnLCC2.t

=head1 SUBROUTINES/METHODS

=head2 get_class_sort_key

  my $cn_sort = C4::ClassSortRoutine::LCC2::GetClassSortKey($cn_class, $cn_item);

Generates sorting key for LC call numbers.

=head1 DIAGNOSTICS

No module-specific error messages are generated

Testscript is t/ClassSortRtnLCC2.t

=head1 CONFIGURATION AND ENVIRONMENT

The script rebuild_cnsort.pl will regenerate all lcc sortkeys
This should be run when this version is first installed
or the logic changed

=head1 DEPENDENCIES

No special dependencies

=head1 INCOMPATIBILITIES

Existing lcc normalization fields will need to be regenerated
by rebuild_cnsort.pl inorder to interfile correctly

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.
Please report problems to http://bugs.koha-community.org
Patches are welcome.

=head1 AUTHOR

Koha Development Team <http://koha-community.org/>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007 LibLime

Copyright (c) 2010 PTFS Inc.

Copyright (c) 2010 PTFS-Europe Ltd.
 
This file is part of Koha.

Koha is free software; you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

Koha is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with Koha; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

