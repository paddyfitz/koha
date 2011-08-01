#!/usr/bin/perl
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
open( REPORT, ">$report_directory/CreateStaff_$today.log" );
print REPORT
  "Reporting results of Registry Import - Create Staff Operation \n\n";

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
  XML::Twig->new( twig_handlers => { EMPLOYEE => \&EMPLOYEE }, )
  ;    # Create XML Twig Object
$twig->parsefile('/home/syncuser/imports/staff_create.xml');    # Parse XML File

# Print Summary of Results to log file
if ( defined($ccount) ) {
    print REPORT "\n\n\n Import Complete \n";
    print REPORT " Records Found in file: " . "$ccount" . "\n";
        if (@inserts){
   print REPORT " Records Imported to DB (Registry No.): " . "@inserts" . "\n";
    }
        if (@inserts){
    print REPORT " Records Failed Import (Registry No.): " . "@fails" . "\n";
    }
    print REPORT "\n\n\n";
}
else {
    print REPORT "\n\n\n Empty Import File, No Users To Import";
}
close REPORT;

# Email Report to Admin
my $email   = 'martin.renvoize@ptfs-europe.com';
my $subject = "'" . "Staff Registry Create Report " . "$today" . "'";
my $message = "$report_directory/CreateStaff_$today.log";
system "mutt -s $subject $email < $message";

# Move file to backup
system(
    "sudo", "mv",
    "/home/syncuser/imports/staff_create.xml",
    "/home/syncuser/imports/past/staff_create_$today.xml"
);
print "Import Complete \n";

# Subroutine to act on each User found in XML file.
sub EMPLOYEE {
    $ccount++;
    print REPORT "\n\n User Count: " . $ccount;
    my ( $twig, $EMPLOYEE ) = @_;

    # User Attributes
    #
    my $reference_number =
      $EMPLOYEE->first_child('REFERENCE');    # borrower_attributes REGISTRY

    #    my $title     = $EMPLOYEE->first_child('TITLE');      # borrowers TITLE
    my $surname   = $EMPLOYEE->first_child('SURNAME');    # borrowers SURNAME
    my $forenames = $EMPLOYEE->first_child('FORENAMES')
      ;    # borrowers FIRSTNAME OTHERNAMES (XML Concatenated by spaces)

#    my $dob = $EMPLOYEE->first_child('DOB');    # borrowers DOB
#    my $pin = $EMPLOYEE->first_child('PIN');    # borrowers PASSWORD (MD5 of PIN)
    my $btype = $EMPLOYEE->first_child('BTYPE');    # borrowers CATEGORYCODE

   #    my $barcode = $EMPLOYEE->first_child('BARCODE');  # borrowers CARDNUMBER
    my $mifare = $EMPLOYEE->first_child('MIFARE');   # borrower_attributes SMART
    my $username = $EMPLOYEE->first_child('USERNAME');     # borrowers USERID
    my $email    = $EMPLOYEE->first_child('EMAIL');        # borrowers EMAIL
    my $phone    = $EMPLOYEE->first_child('TELEPHONE');    # borrowers PHONE

#    my $mobile   = $EMPLOYEE->first_child('MOBILE_TELEPHONE'); # borrowers MOBILE
    my $location = $EMPLOYEE->first_child('LOCATION');    # borrowers BRANCHCODE

  #    my $course_code =
  #      $EMPLOYEE->first_child('COURSE');    # borrower_attributes COURSE
  #    my $level      = $EMPLOYEE->first_child('STUDY_LEVEL');          # UNUSED
  #    my $address1_1 = $EMPLOYEE->first_child('PRIMARY_ADDRESS_1');    #
  #    my $address2_1 = $EMPLOYEE->first_child('PRIMARY_ADDRESS_2');    #
  #    my $address3_1 = $EMPLOYEE->first_child('PRIMARY_ADDRESS_3');    #
  #    my $address4_1 = $EMPLOYEE->first_child('PRIMARY_ADDRESS_4');    #
  #    my $address5_1 = $EMPLOYEE->first_child('PRIMARY_ADDRESS_4');    #
  #    my $postcode_1 =
  #      $EMPLOYEE->first_child('PRIMARY_POSTCODE');    # borrowers ZIPCODE
  #    my $address1_2 =
  #      $EMPLOYEE->first_child('SECONDARY_ADDRESS_1');    # Other Address
  #    my $address2_2 = $EMPLOYEE->first_child('SECONDARY_ADDRESS_2');    #
  #    my $address3_2 = $EMPLOYEE->first_child('SECONDARY_ADDRESS_3');    #
  #    my $address4_2 = $EMPLOYEE->first_child('SECONDARY_ADDRESS_4');    #
  #    my $address5_2 = $EMPLOYEE->first_child('SECONDARY_POSTCODE');     #
  #    my $postcode_2 =
  #      $EMPLOYEE->first_child('SECONDARY_POSTCODE');    # borrowers B_ZIPCODE

    #    print REPORT " "
    #      . $forenames->text . " "
    #      . $surname->text
    #      . " has cardnumber: "
    #      . $barcode->text;                               # Testing Message

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

    #    my $cardnumber = substr( $barcode->text, 0, 13 );
    my @names = split( / /, $forenames->text );
    my $firstname = $names[0];
    shift(@names);
    my $othernames = "@names";
    my $values =
        "'" 
      . "MARKER" . "'" . "," . "'"
      . $surname->text . "'" . "," . "'"
      . $firstname . "'" . "," . "'" . "NULL" . "'" . "," . "'"
      . $othernames . "'" . "," . "'" . "NULL" . "'" . "," . "'" . "NULL" . "'"
      . "," . "'" . "NULL" . "'" . "," . "'" . "NULL" . "'" . "," . "'" . "NULL"
      . "'" . "," . "'" . "NULL" . "'" . "," . "'"
      . $email->text . "'" . "," . "'"
      . $phone->text . "'" . "," . "'" . "NULL" . "'" . "," . "'" . "NULL" . "'"
      . "," . "'" . "NULL" . "'" . "," . "'" . "NULL" . "'" . "," . "'" . "NULL"
      . "'" . "," . "'" . "NULL" . "'" . "," . "'" . "NULL" . "'" . "," . "'"
      . $location->text . "'" . "," . "'"
      . $btype->text . "'" . "," . "'"
      . $rtoday . "'" . "," . "'" . "NULL" . "'" . "," . "'" . "NULL" . "'";

    #
    # SQL Manipulation
    # DB Connection
    my $dbh = DBI->connect( "DBI:mysql:$db:$dbhost", $dbuser, $dbpass )
      or die "Unable to connect: $DBI::errstr\n";

    # Query for Borrower Existance
    $dbtable = "borrower_attributes";
    $fields  = "borrowernumber";
    $field   = "attribute";
    my $refnumber = $reference_number->text;
    my $query =
"SELECT $fields FROM $dbtable WHERE $field='$refnumber' AND code='REGISTRY';";
    $sqlQuery = $dbh->prepare($query)
      or die "Can't prepare $query: $dbh->errstr\n";
    $sqlQuery->execute() or die "Can't execute the query: $sqlQuery->errstr\n";
    my $count = $sqlQuery->fetchrow_arrayref();
    $sqlQuery->finish;

    # IF not present Insert Borrower.
    if ( !$count->[0] ) {
        push( @inserts, "$refnumber" );
        print REPORT "\n !!! User Not Found !!!\n";
        print REPORT " Inserting User Data into 'borrowers' \n";

        # Insert for 'borrowers'
        $dbtable = 'borrowers';
        $insert  = "INSERT INTO $dbtable($headers) VALUES ($values);";

    	$sqlInsert = $dbh->do($insert) or die "Can't do $insert: $dbh->errstr\n";
        print REPORT " User Data Inserted into 'borrowers' \n";

        # Query: Require 'borrowernumber' for 'borrower_attributes' insert
        print REPORT " Querying for borrowernumber; ";
        $fields   = "borrowernumber";
        $field    = "cardnumber";
        $query    = "SELECT $fields FROM $dbtable WHERE $field='MARKER';";
        $sqlQuery = $dbh->prepare($query)
          or die "Can't prepare $query: $dbh->errstr\n";
        $sqlQuery->execute()
          or die "Can't execute the query: $sqlQuery->errstr\n";
        my $borrowernumber;
        $sqlQuery->bind_columns( \$borrowernumber );

        while ( $sqlQuery->fetch() ) {
            print REPORT $borrowernumber . "\n";
        }

        # REMOVE MARKER
	my $cno = $mifare->text;
        my $update =
"UPDATE $dbtable SET $field='$cno' WHERE borrowernumber=$borrowernumber;";
        my $sqlUpdate = $dbh->prepare($update)
          or die "Can't prepare $update: $dbh->errstr\n";
        $sqlUpdate->execute()
          or die "Can't execute the update: $sqlUpdate->errstr\n";

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
        push( @fails, "$refnumber" );
        print REPORT "\n !!! User Found !!! \n";
        $fields   = "borrowernumber";
	$field    = "attribute";
        $dbtable  = "borrower_attributes";
        $query    = "SELECT $fields FROM $dbtable WHERE $field='$refnumber' AND code='REGISTRY';";
        $sqlQuery = $dbh->prepare($query)
          or die "Can't prepare $query: $dbh->errstr\n";
        $sqlQuery->execute()
          or die "Can't execute the query: $sqlQuery->errstr\n";

        # BIND TABLE COLUMNS TO VARIABLES
        my $bn;
        $sqlQuery->bind_columns( \$bn );

        # LOOP THROUGH RESULTS
        while ( $sqlQuery->fetch() ) {
            print REPORT " Staff No. " . $refnumber . " already has borrowernumber: " . $bn . "\n";
        }
    }

    #Close SQL Connection
    $dbh->disconnect;

    # Cleanup
    $EMPLOYEE->purge;
}
