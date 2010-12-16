package  Dainamo::Profile::Qudo;
use strict;
use warnings;
use parent 'Dainamo::Profile';
use Qudo;
use Log::Minimal qw/debugf/;

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    $self->qudo; # for CoW.
    return $self;
}

sub qudo {
    my ($self, ) = @_;
    $self->{qudo} ||= Qudo->new(
        %{ $self->{config} },
    );
}

sub run {
    my ($self, ) = @_;

    debugf("start Dainamo::Profile::Qudo#run()");
    # copied from Qudo's work.
    my $work_delay = $self->qudo->{work_delay};
    unless ( $self->qudo->manager->work_once ) {
        $self->{qudo} = undef; # disconnect while sleep.
        debugf("sleep Dainamo::Profile::Qudo#run()");
        sleep $work_delay;
    }
    $self->{qudo} = undef;
    debugf("finish Dainamo::Profile::Qudo#run()");
}

1;
