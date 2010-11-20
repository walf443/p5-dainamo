package  Dainamo::Profile::Gearman;
use strict;
use warnings;
use parent 'Dainamo::Profile';
use Gearman::Worker;
use UNIVERSAL::require;

sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(%args);

    $self->{gearman} = Gearman::Worker->new;
    $self->{gearman}->job_servers($self->{job_servers});
    for my $worker ( @{ $self->{workers} } ) {
        $worker->use;

        $self->{gearman}->register_function($worker => sub {
            my $job = shift;
            $worker->work($job);
        });
    }

    return $self;
}

sub run {
    my ($self, ) = @_;
    $self->{gearman}->work;
}

1;
