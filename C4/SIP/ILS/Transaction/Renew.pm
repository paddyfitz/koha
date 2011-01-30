#
# Status of a Renew Transaction
#

package ILS::Transaction::Renew;

use warnings;
use strict;

use ILS;

use C4::Circulation;
use C4::Members;

use base qw(ILS::Transaction);

my %fields = (
    renewal_ok => 0,
);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new();

    foreach my $element (keys %fields) {
        $self->{_permitted}->{$element} = $fields{$element};
    }

    @{$self}{keys %fields} = values %fields;	# overkill?
    return bless $self, $class;
}

sub do_renew_for ($$) {
    my $self = shift;
    my $borrower = shift;
    my ($renewokay,$renewerror) = CanBookBeRenewed($borrower->{borrowernumber},$self->{item}->{itemnumber});
    if ($renewokay){
        $self->{due} = undef;
        my $due_date = AddIssue( $borrower, $self->{item}->id, undef, 0 );
        if ($due_date) {
            $self->{due} = $due_date;
        }
        $self->renewal_ok(1);
        my ($charge, undef) = GetIssuingCharges($self->{item}->{itemnumber}, $self->{patron}->{borrowernumber});
        if ($charge) {
            #$self->{sip_fee_type} = $charge;
            $self->{fee_amount} = sprintf '%.2f',$charge;
        }
    } else {
        $renewerror=~s/on_reserve/Item unavailable due to outstanding holds/;
        $renewerror=~s/too_many/Item has reached maximum renewals/
        $self->screen_msg($renewerror);
        $self->renewal_ok(0);
    }
    $! and warn "do_renew_for error: $!";
    $self->ok(1) unless $!;
    return $self;
}

sub do_renew {
    my $self = shift;
    my $borrower = GetMember( cardnumber => $self->{patron}->id );
    return $self->do_renew_for($borrower);
}

1;
