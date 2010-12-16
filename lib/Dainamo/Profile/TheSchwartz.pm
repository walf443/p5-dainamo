package Dainamo::Profile::TheSchwartz;
use strict;
use warnings;
use parent qw(Dainamo::Profile);
use TheSchwartz;

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    $self->schwartz; # for CoW.
    return $self;
}

sub schwartz {
    my ($self, ) = @_;
    my %config = %{ $self->{config} };
    delete $config{manager_abilities};
    delete $config{work_delay};
    $self->{schwartz} ||= TheSchwartz->new(%config);
    for my $ability ( @{ $self->{config}->{manager_abilities} } ) {
        $self->{schwartz}->can_do($ability);
    }
    return $self->{schwartz};
}

sub run {
    my ($self, ) = @_;

    debugf("start Dainamo::Profile::TheSchwartz#run()");
    # copied from TheSchwartz's work.
    my $work_delay = $self->{config}->{work_delay} || 5;
    unless ( $self->schwartz->work_once ) {
        $self->{schwartz} = undef; # disconnect while sleep.

        debugf("sleep Dainamo::Profile::TheSchwartz#run()");
        # exit if SIGTERM in sleep.
        local $SIG{TERM} = sub {
            exit;
        };
        sleep $work_delay;
    }
    $self->{schwartz} = undef;
    debugf("finish Dainamo::Profile::TheSchwartz#run()");
}

1;
