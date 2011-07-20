#!/usr/bin/perl -w
# Student Create
use warnings;
use strict;
use Data::Dumper;
use DBI;                           # Connect to DB
use DBD::mysql;                    # Manipulate MySQL
use XML::Twig;                     # Process XML File
use Digest::MD5 qw(md5_base64);    # Encode Passwords

# MySQL Variables
#
my $db      = 'koha';                             # DB
my $dbuser  = "kohaadmin";                        # DB User
my $dbpass  = 'koha@staff';                       # DB User Password
my $dbhost  = "localhost";                        # DB Host
my $dbtable = 'borrowers borrower_attributes';    # Tables to Backup

# Backup Variables
#
my $backup_directory = '/home/koha/Usersync/Backups';    #Location for backups
my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
  localtime(time);

$year += 1900;
$mon++;

$mday = '0' . $mday if ( $mday < 10 );                   # Zero Padding
$mon  = '0' . $mon  if ( $mon < 10 );                    # Zero Padding

my $today  = "$mday-$mon-$year";
my $rtoday = "$year-$mon-$mday";

# Reporting Variables
#
my $report_directory = '/home/koha/Usersync/Reports';    #Location for reports

# Other Variables
#
my $ccount;
my @inserts;
my @fails;

# Reports
#
open( REPORT, ">$report_directory/Create_$today.log" );
print REPORT "Reporting results of Registry Import - Create Operation \n\n";

#
# Backup Routine
print REPORT "Backing up $dbtable for $db \n";
system
"mysqldump -u root -p'melB1n' $db $dbtable | gzip > $backup_directory/userbackup_$today.sql.gz";

#system("mysqldump -u root -p'melB1n' $db $dbtable > userbackup_$today.sql") or die("Backup Failed: $?");
#system("gzip userbackup_$today.sql") or die "Compression Failed: $?";
print REPORT "Backup Complete \n";

#
# Create Routine
# Process XML File one user at a time (to save on memory usage)
print REPORT "\n Parsing XML File";
my $twig =
  XML::Twig->new( twig_handlers => { LEARNER => \&LEARNER }, )
  ;    # Create XML Twig Object
$twig->parsefile('/home/syncuser/imports/learner_create.xml') or die();  # Parse XML File

# Print Summary of Results to log file
if ( defined($ccount) ) {
    print REPORT "\n\n\n Import Complete \n";
    print REPORT " Records Found in file: " . "$ccount" . "\n";
    if (@inserts){
    print REPORT " Records Imported to DB (Cardnumbers): " . "@inserts" . "\n";
    }
    if (@fails){
    print REPORT " Records Failing Import (Cardnumbers): " . "@fails" . "\n";
    }
    print REPORT "\n\n\n";
}
else {
    print REPORT "\n\n\n Empty Import File, No Users To Import";
}
close REPORT;

# Email Report to Admin
my $email   = 'martin.renvoize@ptfs-europe.com';
my $subject = "'" . "Student Registry Create Report " . "$today" . "'";
my $message = "$report_directory/Create_$today.log";
system "mutt -s $subject $email < $message";

# Move file to backup
system(
    "sudo", "mv",
    "/home/syncuser/imports/learner_create.xml",
    "/home/syncuser/imports/past/learner_create_$today.xml"
);
print "Import Complete \n";

# Subroutine to act on each User found in XML file.
sub LEARNER {
    $ccount++;
    print REPORT "\n\n User Count: " . $ccount;
    my ( $twig, $LEARNER ) = @_;

    # User Attributes
    #
    my $reference_number =
      $LEARNER->first_child('REFERENCE');    # borrower_attributes REGISTRY
    my $title     = $LEARNER->first_child('TITLE');      # borrowers TITLE
    my $surname   = $LEARNER->first_child('SURNAME');    # borrowers SURNAME
    my $forenames = $LEARNER->first_child('FORENAMES')
      ;    # borrowers FIRSTNAME OTHERNAMES (XML Concatenated by spaces)
    my $dob = $LEARNER->first_child('DOB');    # borrowers DOB
    my $pin = $LEARNER->first_child('PIN');    # borrowers PASSWORD (MD5 of PIN)
    my $btype   = $LEARNER->first_child('BTYPE');    # borrowers CATEGORYCODE
    my $barcode = $LEARNER->first_child('BARCODE');  # borrowers CARDNUMBER
    my $mifare  = $LEARNER->first_child('MIFARE');   # borrower_attributes SMART
    my $username = $LEARNER->first_child('USERNAME');         # borrowers USERID
    my $email    = $LEARNER->first_child('EMAIL');            # borrowers EMAIL
    my $phone    = $LEARNER->first_child('TELEPHONE');        # borrowers PHONE
    my $mobile   = $LEARNER->first_child('MOBILE_TELEPHONE'); # borrowers MOBILE
    my $location = $LEARNER->first_child('LOCATION');    # borrowers BRANCHCODE
    my $course_code =
      $LEARNER->first_child('COURSE');    # borrower_attributes COURSE
    my $level      = $LEARNER->first_child('STUDY_LEVEL');          # UNUSED
    my $address1_1 = $LEARNER->first_child('PRIMARY_ADDRESS_1');    #
    my $address2_1 = $LEARNER->first_child('PRIMARY_ADDRESS_2');    #
    my $address3_1 = $LEARNER->first_child('PRIMARY_ADDRESS_3');    #
    my $address4_1 = $LEARNER->first_child('PRIMARY_ADDRESS_4');    #
    my $address5_1 = $LEARNER->first_child('PRIMARY_ADDRESS_4');    #
    my $postcode_1 =
      $LEARNER->first_child('PRIMARY_POSTCODE');    # borrowers ZIPCODE
    my $address1_2 =
      $LEARNER->first_child('SECONDARY_ADDRESS_1');    # Other Address
    my $address2_2 = $LEARNER->first_child('SECONDARY_ADDRESS_2');    #
    my $address3_2 = $LEARNER->first_child('SECONDARY_ADDRESS_3');    #
    my $address4_2 = $LEARNER->first_child('SECONDARY_ADDRESS_4');    #
    my $address5_2 = $LEARNER->first_child('SECONDARY_POSTCODE');     #
    my $postcode_2 =
      $LEARNER->first_child('SECONDARY_POSTCODE');    # borrowers B_ZIPCODE

    print REPORT " "
      . $forenames->text . " "
      . $surname->text
      . " has cardnumber: "
      . $barcode->text;                               # Testing Message

    # MySQL Variables
    #
    my $fields;    # Field to request from the dbtable.
    my $field;     # Filed to match request upon.
    my $insert;    # Insert Statement.
    my $sqlInsert;
    my $sqlQuery;
    my $headers =
        "cardnumber,surname,firstname,title,othernames,"
      . "streetnumber,address,address2,city,state,zipcode,email,phone,"
      . "B_streetnumber,B_address,B_address2,B_city,B_state,B_zipcode,"
      . "dateofbirth,branchcode,categorycode,dateenrolled,password,userid";
    my $cardnumber = substr( $barcode->text, 0, 13 );
    my @names = split( / /, $forenames->text );
    my $firstname = $names[0];
    shift(@names);
    my $othernames = "@names";
    my $password   = md5_base64( $pin->text );
    my $values     = "'"
      . $cardnumber . "'" . "," . "'"
      . $surname->text . "'" . "," . "'"
      . $firstname . "'" . "," . "'"
      . $title->text . "'" . "," . "'"
      . $othernames . "'" . "," . "'"
      . $address1_1->text . "'" . "," . "'"
      . $address2_1->text . "'" . "," . "'"
      . $address3_1->text . "'" . "," . "'"
      . $address4_1->text . "'" . "," . "'"
      . $address5_1->text . "'" . "," . "'"
      . $postcode_1->text . "'" . "," . "'"
      . $email->text . "'" . "," . "'"
      . $phone->text . "'" . "," . "'"
      . $address1_2->text . "'" . "," . "'"
      . $address2_2->text . "'" . "," . "'"
      . $address3_2->text . "'" . "," . "'"
      . $address4_2->text . "'" . "," . "'"
      . $address5_2->text . "'" . "," . "'"
      . $postcode_2->text . "'" . "," . "'"
      . $dob->text . "'" . "," . "'"
      . $location->text . "'" . "," . "'"
      . $btype->text . "'" . "," . "'"
      . $rtoday . "'" . "," . "'"
      . $password . "'" . "," . "'"
      . $username->text . "'";

    #
    # SQL Manipulation
    # DB Connection
    my $dbh = DBI->connect( "DBI:mysql:$db:$dbhost", $dbuser, $dbpass )
      or die "Unable to connect: $DBI::errstr\n";

    # Query for Borrower Existance
    $dbtable = "borrowers";
    $fields  = "cardnumber";
    $field   = "cardnumber";
    my $query = "SELECT $fields FROM $dbtable WHERE $field='$cardnumber';";
    $sqlQuery = $dbh->prepare($query)
      or die "Can't prepare $query: $dbh->errstr\n";
    $sqlQuery->execute() or die "Can't execute the query: $sqlQuery->errstr\n";
    my $count = $sqlQuery->fetchrow_arrayref();
    $sqlQuery->finish;

    # IF not present Insert Borrower.
    if ( !$count->[0] ) {
        push( @inserts, "$cardnumber" );
        print REPORT "\n !!! User Not Found !!!\n";
        print REPORT " Inserting User Data into 'borrowers' \n";

        # Insert for 'borrowers'
        $insert = "INSERT INTO $dbtable($headers) VALUES ($values);";

     	$sqlInsert = $dbh->do($insert) or die "Can't do $insert: $dbh->errstr\n";
        print REPORT " User Data Inserted into 'borrowers' \n";

        # Query: Require 'borrowernumber' for 'borrower_attributes' insert
        print REPORT " Querying for borrowernumber; ";
        $fields   = "borrowernumber";
        $query    = "SELECT $fields FROM $dbtable WHERE $field='$cardnumber';";
        $sqlQuery = $dbh->prepare($query)
          or die "Can't prepare $query: $dbh->errstr\n";
        $sqlQuery->execute()
          or die "Can't execute the query: $sqlQuery->errstr\n";
        my $borrowernumber;
        $sqlQuery->bind_columns( \$borrowernumber );

        while ( $sqlQuery->fetch() ) {
            print REPORT $borrowernumber . "\n";
        }
        print REPORT " Inserting User Data into 'borrower_attributes' \n";

        # Insert for 'borrower_attributes'
        $dbtable = "borrower_attributes";
        $headers = "borrowernumber,code,attribute,password";
        ## REFERENCE => REGISTRY
        $values = "'"
          . $borrowernumber . "'" . "," . "'"
          . "REGISTRY" . "'" . "," . "'"
          . $reference_number->text . "'" . "," . "'" . "NULL" . "'";
        $insert = "INSERT INTO $dbtable($headers) VALUES ($values);";

     	$sqlInsert = $dbh->do($insert) or die "Can't do $insert: $dbh->errstr\n";
        print REPORT " Registry number inserted into 'borrower_attributes' \n";
        ## COURSE => COURSE
        $values = "'"
          . $borrowernumber . "'" . "," . "'"
          . "COURSE" . "'" . "," . "'"
          . $course_code->text . "'" . "," . "'" . "NULL" . "'";
        $insert = "INSERT INTO $dbtable($headers) VALUES ($values);";

     	$sqlInsert = $dbh->do($insert) or die "Can't do $insert: $dbh->errstr\n";
        print REPORT " Course Code inserted into 'borrower_attributes' \n";
        ## MIFARE => SMART
        $values = "'"
          . $borrowernumber . "'" . "," . "'" . "SMART" . "'" . "," . "'"
          . $mifare->text . "'" . "," . "'" . "NULL" . "'";
        $insert = "INSERT INTO $dbtable($headers) VALUES ($values);";

     	$sqlInsert = $dbh->do($insert) or die "Can't do $insert: $dbh->errstr\n";
        print REPORT " MIFARE number inserted into 'borrower_attributes' \n";
        print REPORT " Borrower Import Completed \n\n\n";
    }

    # IF present, modify user + report incident.
    else {
        push( @fails, "$cardnumber" );
        print REPORT "\n !!! User Found !!! \n";
        $fields   = "borrowernumber,cardnumber";
        $dbtable  = "borrowers";
        $query    = "SELECT $fields FROM $dbtable WHERE $field='$cardnumber';";
        $sqlQuery = $dbh->prepare($query)
          or die "Can't prepare $query: $dbh->errstr\n";
        $sqlQuery->execute()
          or die "Can't execute the query: $sqlQuery->errstr\n";

        # BIND TABLE COLUMNS TO VARIABLES
        my $bn;
        my $cn;
        $sqlQuery->bind_columns( \$bn, \$cn );

        # LOOP THROUGH RESULTS
        while ( $sqlQuery->fetch() ) {
            print REPORT " Borrowernumber: " . $bn . "\n";
            print REPORT " Cardnumber: " . $cn . "\n";
        }
    }

    #Close SQL Connection
    $dbh->disconnect;

    # Cleanup
    $LEARNER->purge;
}
