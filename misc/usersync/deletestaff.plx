#!/usr/bin/perl -w
# Staff Delete
use warnings;
use strict;
use Data::Dumper;
use DBI;            # Connect to DB
use DBD::mysql;     # Manipulate MySQL
use XML::Twig;      # Process XML File
use C4::Members;    # Use Koha Members Routine to manipulate Borrower Records.

# MySQL Variables
#
my $db      = 'koha';                             # DB
my $dbuser  = "kohaadmin";                        # DB User
my $dbpass  = 'koha@staff';                       # DB User Password
my $dbhost  = "localhost";                        # DB Host
my $dbtable = 'borrowers borrower_attributes';    # Tables to Backup

# Reporting Variables
#
my $report_directory = '/home/koha/Usersync/Reports';    #Location for reports

# Other Variable
#
my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
  localtime(time);

$year += 1900;
$mon++;

$mday = '0' . $mday if ( $mday < 10 );                   # Zero Padding
$mon  = '0' . $mon  if ( $mon < 10 );                    # Zero Padding

my $today  = "$mday-$mon-$year";
my $rtoday = "$year-$mon-$mday";

my $dcount = 0;
my $errors = 0;
my @deletes;
my @fails;

# Reports
#
open( REPORT, ">$report_directory/DeleteStaff_$today.log" );
print REPORT "Reporting results of Registry Import - Delete Operation \n\n";

#
# Delete Routine
# Process XML File one user at a time (to save on memory usage)
print REPORT "  Parsing XML File \n\n";
my $twig =
  XML::Twig->new( twig_handlers => { EMPLOYEE => \&EMPLOYEE }, )
  ;    # Create XML Twig Object
$twig->parsefile('/home/syncuser/imports/staff_delete.xml');    # Parse XML File

# Print Summary of Results to log file
if ( defined($dcount) ) {
    print REPORT "\n\n\n Staff Delete Complete \n";
    if ( defined($errors) ) {
        print REPORT $errors . " Errors";
        if ( defined(@fails) ) {
            print REPORT " Records Failing Import (Registry No.): " . "@fails"
              . "\n";
        }
    }
    if ( defined(@deletes) ) {
        print REPORT "\n"
          . " Records Deleted Succesfully (Registry No.): "
          . "@deletes";
    }
}
else {
    print REPORT "\n\n\n Empty Delete File, No Users to Delete ";
    print REPORT "\n\n\n";
}
close REPORT;

# Email Report to Admin
my $email   = 'martin.renvoize@ptfs-europe.com';
my $subject = "'" . "Registry Import Report - Delete Staff (" . "$today" . ")'";
my $message = "$report_directory/DeleteStaff_$today.log";
system "mutt -s $subject $email < $message";

# Move file to backup
system(
    "sudo", "mv",
    "/home/syncuser/imports/staff_delete.xml",
    "/home/syncuser/imports/past/staff_delete_$today.xml"
);

print "Delete Complete \n\n";

# Subroutine to execute upon each User Record in XML file.
sub EMPLOYEE {
    $dcount++;
    print REPORT "  Processing Delete: " . $dcount . "\n";
    my ( $twig, $EMPLOYEE ) = @_;

    # User Attributes
    #
    my $reference_number =
      $EMPLOYEE->first_child('REFERENCE');    # borrower_attributes REGISTRY
    if ( defined($reference_number) ) {
        print REPORT "  Attempting to DELETE user with Registry: "
          . $reference_number->text
          . "\n";                             # Testing Message

        # SQL Veriables
        #
        my $fields;
        my $dbtable;
        my $field;

        my $query;
        my $sqlQuery;

        #
        # SQL Manipulation
        # DB Connection
        my $dbh = DBI->connect( "DBI:mysql:$db:$dbhost", $dbuser, $dbpass )
          or die "Unable to connect: $DBI::errstr\n";

        # Lookup Borrowernumber
        $fields  = "borrowernumber";
        $dbtable = "borrower_attributes";
        $field   = "attribute";
        my $ref = $reference_number->text;
        $query =
          "SELECT $fields FROM $dbtable WHERE code='REGISTRY' AND $field=$ref;";
        $sqlQuery = $dbh->prepare($query)
          or die "Can't prepare $query: $dbh->errstr\n";
        $sqlQuery->execute()
          or die "Can't execute the query: $sqlQuery->errstr\n";
        my $count = $sqlQuery->fetchrow_arrayref();
        $sqlQuery->finish;
        my $borrowernumber;

        # IF not present, report error.
        if ( !$count->[0] ) {
            $errors++;
            push( @fails, $ref );
            print REPORT "  DELETE FAILED: USER NOT FOUND \n";
            print REPORT "  User with registry number " . $ref
              . " does not appear in the database? \n";
        }

        # IF present, do delete operation.
        else {

            # Fetch borrowernumber
            $sqlQuery = $dbh->prepare($query)
              or die "Can't prepare $query: $dbh->errstr\n";
            $sqlQuery->execute()
              or die "Can't execute the query: $sqlQuery->errstr\n";
            $sqlQuery->bind_columns( \$borrowernumber );
            while ( $sqlQuery->fetch() ) {
                print REPORT $ref
                  . " has borrowernumber: "
                  . $borrowernumber . "\n";
            }

            # Delete user with borrowernumber
            print REPORT " Attempting to DELETE User with borrowernumber: "
              . $borrowernumber . "\n";
            my $issues      = GetPendingIssues($borrowernumber);
            my $countissues = scalar(@$issues);

            my ($bor) = GetMemberDetails( $borrowernumber, '' );
            my $flags = $bor->{flags};

            if ( $countissues > 0 or $flags->{'CHARGES'} ) {
                $errors++;
                push( @fails, $ref );
                if ( $countissues > 0 ) {
                    print REPORT "Staff " 
                      . $ref
                      . " still has "
                      . $countissues
                      . " issues outstanding. \n";
                }
                if ( $flags->{'CHARGES'} ne '' ) {
                    print REPORT "Staff " 
                      . $ref
                      . " still has "
                      . $flags->{'CHARGES'}->{'amount'}
                      . " in charges outstanding. \n";
                }
            }
            else {
                MoveMemberToDeleted($borrowernumber);
                DelMember($borrowernumber);
                push( @deletes, $ref );
                print REPORT " Delete Succesful \n";
            }
            $sqlQuery->finish;

            #Close SQL Connection
            $dbh->disconnect;

            # Cleanup
            $EMPLOYEE->purge;
        }
    }
    else {
        print REPORT
          "\n\n CANNOT DELETE RECORD: NO REFERENCE TO USER FOUND \n\n";
    }
}
