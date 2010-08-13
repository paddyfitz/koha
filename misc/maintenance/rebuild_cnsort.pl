#!/usr/bin/perl
#
# Copyright 2010 PTFS Inc
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;

#  Passed a valid class scheme this will recreate the cn_sort field in all
#  items using that scheme. If no scheme is passed it defaults to lccn
#
use C4::Context;
use C4::ClassSource;
use C4::ClassSortRoutine;
use DBI;
use Carp;

my $class_scheme = shift;

$class_scheme ||= 'lcc';

my $source   = C4::ClassSource::GetClassSource($class_scheme);
my $rule     = C4::ClassSource::GetClassSortRule($source->{class_sort_rule});
my $sort_rtn = $rule->{sort_routine};

my @sort_routines = C4::ClassSortRoutine->subclasses();

my $found = 0;
for (@sort_routines) {
    if ( $sort_rtn eq $_ ) {
        $found = 1;
        last;
    }
}
if ( !$found ) {
    croak "No routine $sort_rtn found for schema $class_scheme";
}

my $dbh = C4::Context->dbh;

my $sth = $dbh->prepare('update items set cn_sort = ? where itemnumber = ?');

my $items = $dbh->selectall_arrayref(
    'select itemnumber, itemcallnumber from items where cn_source = ?',
    { Slice => {} },
    $class_scheme
);

for my $item ( @{$items} ) {
    my $key =
      C4::ClassSortRoutine::GetClassSortKey( $sort_rtn, $item->{itemcallnumber},
        '' );
    $sth->execute( $key, $item->{itemnumber} );
}

