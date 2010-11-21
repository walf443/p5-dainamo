package  Dainamo::Profile::Qudo;
use strict;
use warnings;
use parent 'Dainamo::Profile';
use Qudo;

sub new {
    my ($class, %args) = @_;
    bless \%args, $class;
}

sub qudo {
    my ($self, ) = @_;
    $self->{qudo} ||= Qudo->new(
        %{ $self->{config} },
    );
}

sub run {
    my ($self, ) = @_;

    # copied from Qudo's work.
    my $work_delay = $self->qudo->{work_delay};
    unless ( $self->qudo->manager->work_once ) {
        $self->{qudo} = undef;
        sleep $work_delay;
    }
    $self->{qudo} = undef;
}

1;
