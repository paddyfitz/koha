#!/usr/bin/perl -w
# Student Update
use warnings;
use strict;
use Data::Dumper;
use DBI;            # Connect to DB
use DBD::mysql;     # Manipulate MySQL
use XML::Twig;      # Process XML File
use C4::Members;    # Use Koha Members Routine to manipulate Borrower Records.
use Digest::MD5 qw(md5_base64);    # Encode Passwords

# MySQL Variables
#
my $db      = 'koha';                             # DB
my $dbuser  = "kohaadmin";                        # DB User
my $dbpass  = 'koha@staff';                       # DB User Password
my $dbhost  = "localhost";                        # DB Host
my $dbtable = 'borrowers borrower_attributes';    # Tables to Backup

my $dbh = DBI->connect( "DBI:mysql:$db:$dbhost", $dbuser, $dbpass )
  or die "Unable to connect: $DBI::errstr\n";

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

my $ucount  = 0;
my $errors  = 0;
my $success = 0;

# User Variables
#
my $borrowernumber;
my (
    $reference_number, $title,      $surname,     $forenames,
    $dob,              $pin,        $btype,       $barcode,
    $mifare,           $username,   $email,       $phone,
    $mobile,           $location,   $course_code, $level,
    $address1_1,       $address2_1, $address3_1,  $address4_1,
    $address5_1,       $postcode_1, $address1_2,  $address2_2,
    $address3_2,       $address4_2, $address5_2,  $postcode_2
);

# Reports
#
open( REPORT, ">$report_directory/Update_$today.log" );
print REPORT "Reporting results of Registry Import - Update Operation \n\n";

#
# Update Routine
# Process XML File one user at a time (to save on memory usage)
print REPORT "  Parsing XML File \n";
my $twig =
  XML::Twig->new( twig_handlers => { LEARNER => \&LEARNER }, )
  ;    # Create XML Twig Object
$twig->parsefile('/home/syncuser/imports/learner_update.xml');  # Parse XML File

#Close SQL Connection
$dbh->disconnect;

# Print Summary of Results to log file
if ( defined($ucount) ) {
    print REPORT "\n\n\n Update Complete \n";
    print REPORT " Records Found in file: " . "$ucount" . "\n";
    print REPORT " " . "$errors" . " Errors \n";
    print REPORT "\n\n\n";
}
else {
    print REPORT "\n\n\n Empty Update File, No Users To Update";
}
close REPORT;

# Email Report to Admin
my $adminemail   = 'martin.renvoize@ptfs-europe.com';
my $subject = "'" . "Student Registry Update Report " . "$today" . "'";
my $message = "$report_directory/Update_$today.log";
system "mutt -s $subject $adminemail < $message";
# Move file to backup
system(
    "sudo", "mv",
    "/home/syncuser/imports/learner_update.xml",
    "/home/syncuser/imports/past/learner_update_$today.xml"
);
print "Update Complete \n\n";

# Subroutines
#
sub LEARNER {
    $ucount++;
    print REPORT "\n Processing Update: " . $ucount . "\n";
    my ( $twig, $LEARNER ) = @_;

    # User Attributes
    #
    $reference_number =
      $LEARNER->first_child('REFERENCE');    # borrower_attributes REGISTRY
    $title     = $LEARNER->first_child('TITLE');      # borrowers TITLE
    $surname   = $LEARNER->first_child('SURNAME');    # borrowers SURNAME
    $forenames = $LEARNER->first_child('FORENAMES')
      ;    # borrowers FIRSTNAME OTHERNAMES (XML Concatenated by spaces)
    $dob   = $LEARNER->first_child('DOB');     # borrowers DOB
    $pin   = $LEARNER->first_child('PIN');     # borrowers PASSWORD (MD5 of PIN)
    $btype = $LEARNER->first_child('BTYPE');   # borrowers CATEGORYCODE
    $barcode  = $LEARNER->first_child('BARCODE');    # borrowers CARDNUMBER
    $mifare   = $LEARNER->first_child('MIFARE');     # borrower_attributes SMART
    $username = $LEARNER->first_child('USERNAME');   # borrowers USERID
    $email    = $LEARNER->first_child('EMAIL');      # borrowers EMAIL
    $phone    = $LEARNER->first_child('TELEPHONE');  # borrowers PHONE
    $mobile = $LEARNER->first_child('MOBILE_TELEPHONE');    # borrowers MOBILE
    $location = $LEARNER->first_child('LOCATION');    # borrowers BRANCHCODE
    $course_code = $LEARNER->first_child('COURSE'); # borrower_attributes COURSE
    $level      = $LEARNER->first_child('STUDY_LEVEL');          # UNUSED
    $address1_1 = $LEARNER->first_child('PRIMARY_ADDRESS_1');    #
    $address2_1 = $LEARNER->first_child('PRIMARY_ADDRESS_2');    #
    $address3_1 = $LEARNER->first_child('PRIMARY_ADDRESS_3');    #
    $address4_1 = $LEARNER->first_child('PRIMARY_ADDRESS_4');    #
    $address5_1 = $LEARNER->first_child('PRIMARY_ADDRESS_4');    #
    $postcode_1 = $LEARNER->first_child('PRIMARY_POSTCODE'); # borrowers ZIPCODE
    $address1_2 = $LEARNER->first_child('SECONDARY_ADDRESS_1');  # Other Address
    $address2_2 = $LEARNER->first_child('SECONDARY_ADDRESS_2');  #
    $address3_2 = $LEARNER->first_child('SECONDARY_ADDRESS_3');  #
    $address4_2 = $LEARNER->first_child('SECONDARY_ADDRESS_4');  #
    $address5_2 = $LEARNER->first_child('SECONDARY_POSTCODE');   #
    $postcode_2 =
      $LEARNER->first_child('SECONDARY_POSTCODE');    # borrowers B_ZIPCODE

    # SQL Veriables
    #
    my $fields;
    my $dbtable;
    my $field;

    my $query;
    my $sqlQuery;

    #
    # SQL Manipulation

    # Query for Borrower Existance
    my $cardnumber;
    my $refnumber;
    if ( defined $barcode ) {    # Cardnumber Present in XML
        print REPORT " Unique Identifier = Barcode: " . $barcode->text . "\n";
        $cardnumber = substr( $barcode->text, 0, 13 );
        $fields     = "cardnumber";
        $dbtable    = "borrowers";
        $field      = "cardnumber";
        $query = "SELECT $fields FROM $dbtable WHERE $field='$cardnumber';";
    }
    elsif ( defined $reference_number ) {    # Registry Present in XML
        print REPORT " Unique Identifier = Registry Number: "
          . $reference_number->text . "\n";
        $fields    = "borrowernumber";
        $dbtable   = "borrower_attributes";
        $field     = "attribute";
        $refnumber = $reference_number->text;
        $query =
"SELECT $fields FROM $dbtable WHERE code='REGISTRY' AND $field=$refnumber;";
    }
    else {    # Error: No Unique Identifier in XML
        print REPORT " Unique Identifier NOT found, Skipping UPDATE \n";
        &report();
        return;
    }
    $sqlQuery = $dbh->prepare($query)
      or die "Can't prepare $query: $dbh->errstr\n";
    $sqlQuery->execute() or die "Can't execute the query: $sqlQuery->errstr\n";
    my $count = $sqlQuery->fetchrow_arrayref();
    $sqlQuery->finish;

    # IF not present, report error.
    if ( !$count->[0] ) {
        $errors++;
        print REPORT "  UPDATE FAILED: USER NOT FOUND \n";
        print REPORT "  Skipping User \n";
        &report();
        return;
    }

    # IF present, do update operation.
    else {

        # Fetch borrowernumber
        if ( defined $barcode ) {    # Cardnumber Present in XML
            $fields  = "borrowernumber";
            $dbtable = "borrowers";
            $field   = "cardnumber";
            $query = "SELECT $fields FROM $dbtable WHERE $field='$cardnumber';";
        }
        elsif ( defined $reference_number ) {    # Registry Present in XML
            $fields  = "borrowernumber";
            $dbtable = "borrower_attributes";
            $field   = "attribute";
            $query =
"SELECT $fields FROM $dbtable WHERE code='REGISTRY' AND $field=$refnumber;";
        }
        $sqlQuery = $dbh->prepare($query)
          or die "Can't prepare $query: $dbh->errstr\n";
        $sqlQuery->execute()
          or die "Can't execute the query: $sqlQuery->errstr\n";
        $sqlQuery->bind_columns( \$borrowernumber );
        while ( $sqlQuery->fetch() ) {
            print REPORT " User has borrowernumber: " . $borrowernumber . "\n";
        }

        # Update user with borrowernumber
        print REPORT " Attempting to UPDATE User with borrowernumber: "
          . $borrowernumber . "\n";
        my $newvalue;
        if ( defined $reference_number ) {
            $dbtable  = 'borrower_attributes';
            $field    = 'attribute';
            $newvalue = $reference_number->text;
            my $update =
"UPDATE $dbtable SET $field=$newvalue WHERE borrowernumber=$borrowernumber AND code='REGISTRY';";
            my $sqlUpdate = $dbh->prepare($update)
              or die "Can't prepare $update: $dbh->errstr\n";
            $sqlUpdate->execute()
              or die "Can't execute the update: $sqlUpdate->errstr\n";
        }
        if ( defined $title ) {
            $newvalue = $title->text;
            &update( 'borrowers', 'title', $newvalue, $borrowernumber );
        }
        if ( defined $surname ) {
            $newvalue = $surname->text;
            &update( 'borrowers', 'surname', $newvalue, $borrowernumber );
        }
        if ( defined $forenames ) {
            my @names = split( / /, $forenames->text );
            my $fname = $names[0];
            shift(@names);
            my $othernames = "@names";
            &update( 'borrowers', 'firstname',  $fname,      $borrowernumber );
            &update( 'borrowers', 'othernames', $othernames, $borrowernumber );
        }
        if ( defined $dob ) {
            $newvalue = $dob->text;
            &update( 'borrowers', 'dateofbirth', $newvalue, $borrowernumber );
        }
        if ( defined $pin ) {
            my $password = md5_base64( $pin->text );
            $newvalue = $pin->text;
            &update( 'borrowers', 'password', $password, $borrowernumber );
        }
        if ( defined $btype ) {
            $newvalue = $btype->text;
            &update( 'borrowers', 'btype', $newvalue, $borrowernumber );
        }
        if ( defined $barcode ) {
            $newvalue = $barcode->text;
            &update( 'borrowers', 'cardnumber', $newvalue, $borrowernumber );
        }
        if ( defined $mifare ) {
            $dbtable  = 'borrower_attributes';
            $field    = 'attribute';
            $newvalue = $mifare->text;
            my $update =
"UPDATE $dbtable SET $field=$newvalue WHERE borrowernumber=$borrowernumber AND code='SMART'";
            my $sqlUpdate = $dbh->prepare($update)
              or die "Can't prepare $update: $dbh->errstr\n";
            $sqlUpdate->execute()
              or die "Can't execute the update: $sqlUpdate->errstr\n";
        }
        if ( defined $username ) {
            $newvalue = $username->text;
            &update( 'borrowers', 'userid', $newvalue, $borrowernumber );
        }
        if ( defined $email ) {
            $newvalue = $email->text;
            &update( 'borrowers', 'email', $newvalue, $borrowernumber );
        }
        if ( defined $phone ) {
            $newvalue = $phone->text;
            &update( 'borrowers', 'phone', $newvalue, $borrowernumber );
        }
        if ( defined $mobile ) {
            $newvalue = $mobile->text;
            &update( 'borrowers', 'mobile', $newvalue, $borrowernumber );
        }
        if ( defined $location ) {
            $newvalue = $location->text;
            &update( 'borrowers', 'branchcode', $newvalue, $borrowernumber );
        }
        if ( defined $course_code ) {
            $dbtable  = 'borrower_attributes';
            $field    = 'attribute';
            $newvalue = $course_code->text;
            my $update =
"UPDATE $dbtable SET $field='$newvalue' WHERE borrowernumber=$borrowernumber AND code='COURSE'";

            #            print REPORT "Doing Update: " . $update . "\n";
            my $sqlUpdate = $dbh->prepare($update)
              or die "Can't prepare $update: $dbh->errstr\n";
            $sqlUpdate->execute()
              or die "Can't execute the update: $sqlUpdate->errstr\n";
        }
        if ( defined $address1_1 ) {
            $newvalue = $address1_1->text;
            &update( 'borrowers', 'streetnumber', $newvalue, $borrowernumber );
        }
        if ( defined $address2_1 ) {
            $newvalue = $address2_1->text;
            &update( 'borrowers', 'address', $newvalue, $borrowernumber );
        }
        if ( defined $address3_1 ) {
            $newvalue = $address3_1->text;
            &update( 'borrowers', 'address2', $newvalue, $borrowernumber );
        }
        if ( defined $address4_1 ) {
            $newvalue = $address4_1->text;
            &update( 'borrowers', 'city', $newvalue, $borrowernumber );
        }
        if ( defined $address5_1 ) {
            $newvalue = $address5_1->text;
            &update( 'borrowers', 'state', $newvalue, $borrowernumber );
        }
        if ( defined $postcode_1 ) {
            $newvalue = $postcode_1->text;
            &update( 'borrowers', 'zipcode', $newvalue, $borrowernumber );
        }
        if ( defined $address1_2 ) {
            $newvalue = $address1_2->text;
            &update( 'borrowers', 'B_streetnumber', $newvalue,
                $borrowernumber );
        }
        if ( defined $address2_2 ) {
            $newvalue = $address2_2->text;
            &update( 'borrowers', 'B_address', $newvalue, $borrowernumber );
        }
        if ( defined $address3_2 ) {
            $newvalue = $address3_2->text;
            &update( 'borrowers', 'B_address2', $newvalue, $borrowernumber );
        }
        if ( defined $address4_2 ) {
            $newvalue = $address4_2->text;
            &update( 'borrowers', 'B_city', $newvalue, $borrowernumber );
        }
        if ( defined $address5_2 ) {
            $newvalue = $address5_2->text;
            &update( 'borrowers', 'B_state', $newvalue, $borrowernumber );
        }
        if ( defined $postcode_2 ) {
            $newvalue = $postcode_2->text;
            &update( 'borrowers', 'B_zipcode', $newvalue, $borrowernumber );
        }
    }

    # Cleanup
    $LEARNER->purge;

    print REPORT "\n User with borrowernumber: "
      . $borrowernumber
      . " has been succesfully updated\n";

    # Reset User Variables to Undefined
    undef $borrowernumber;
    undef $reference_number;
    undef $title;
    undef $surname;
    undef $forenames;
    undef $dob;
    undef $pin;
    undef $btype;
    undef $barcode;
    undef $mifare;
    undef $username;
    undef $email;
    undef $phone;
    undef $mobile;
    undef $location;
    undef $course_code;
    undef $level;
    undef $address1_1;
    undef $address2_1;
    undef $address3_1;
    undef $address4_1;
    undef $address5_1;
    undef $postcode_1;
    undef $address1_2;
    undef $address2_2;
    undef $address3_2;
    undef $address4_2;
    undef $address5_2;
    undef $postcode_2;
}

sub update {
    my $dbtable        = $_[0];
    my $field          = $_[1];
    my $newvalue       = $_[2];
    my $borrowernumber = $_[3];
    my $update =
"UPDATE $dbtable SET $field='$newvalue' WHERE borrowernumber=$borrowernumber";

    #    print REPORT "Doing Update: " . $update . "\n";
    my $sqlUpdate = $dbh->prepare($update)
      or die "Can't prepare $update: $dbh->errstr\n";
    $sqlUpdate->execute()
      or die "Can't execute the update: $sqlUpdate->errstr\n";
}

sub report {
    print REPORT "Details for Failed Update \n";
    if ( defined $reference_number ) {
        print REPORT "Registry: " . $reference_number->text . "\n";
    }
    if ( defined $title ) {
        print REPORT "Title: " . $title->text . "\n";
    }
    if ( defined $surname ) {
        print REPORT "Surname: " . $surname->text . "\n";
    }
    if ( defined $forenames ) {
        print REPORT "Fornames: " . $forenames->text . "\n";
    }
    if ( defined $dob ) {
        print REPORT "DOB: " . $dob->text . "\n";
    }
    if ( defined $pin ) {
        print REPORT "PIN: " . $pin->text . "\n";
    }
    if ( defined $btype ) {
        print REPORT "BType: " . $btype->text . "\n";
    }
    if ( defined $barcode ) {
        print REPORT "Barcode: " . $barcode->text . "\n";
    }
    if ( defined $mifare ) {
        print REPORT "Mifare: " . $mifare->text . "\n";
    }
    if ( defined $username ) {
        print REPORT "Username: " . $username->text . "\n";
    }
    if ( defined $email ) {
        print REPORT "Email: " . $email->text . "\n";
    }
    if ( defined $phone ) {
        print REPORT "Phone: " . $phone->text . "\n";
    }
    if ( defined $mobile ) {
        print REPORT "Mobile: " . $mobile->text . "\n";
    }
    if ( defined $location ) {
        print REPORT "Location: " . $location->text . "\n";
    }
    if ( defined $course_code ) {
        print REPORT "Course: " . $course_code->text . "\n";
    }
    if ( defined $address1_1 ) {
        print REPORT "Address1_1: " . $address1_1->text . "\n";
    }
    if ( defined $address2_1 ) {
        print REPORT "Address2_1: " . $address2_1->text . "\n";
    }
    if ( defined $address3_1 ) {
        print REPORT "Address3_1: " . $address3_1->text . "\n";
    }
    if ( defined $address4_1 ) {
        print REPORT "Address4_1: " . $address4_1->text . "\n";
    }
    if ( defined $address5_1 ) {
        print REPORT "Address5_1: " . $address5_1->text . "\n";
    }
    if ( defined $postcode_1 ) {
        print REPORT "Postcode_1: " . $postcode_1->text . "\n";
    }
    if ( defined $address1_2 ) {
        print REPORT "Address1_2: " . $address1_2->text . "\n";
    }
    if ( defined $address2_2 ) {
        print REPORT "Address2_2: " . $address2_2->text . "\n";
    }
    if ( defined $address3_2 ) {
        print REPORT "Address3_2: " . $address3_2->text . "\n";
    }
    if ( defined $address4_2 ) {
        print REPORT "Address4_2: " . $address4_2->text . "\n";
    }
    if ( defined $address5_2 ) {
        print REPORT "Address5_2: " . $address5_2->text . "\n";
    }
    if ( defined $postcode_2 ) {
        print REPORT "Postcode_2: " . $postcode_2->text . "\n";
    }
}
