package  Dainamo::Profile::Gearman;
use strict;
use warnings;
use parent 'Dainamo::Profile';
use Gearman::Worker;
use UNIVERSAL::require;
use Log::Minimal qw/infof/;

sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(%args);

    $self->{gearman} = Gearman::Worker->new;
    $self->{gearman}->job_servers($self->{config}->{job_servers});
    for my $worker ( @{ $self->{config}->{workers} } ) {
        $worker->use;

        $self->{gearman}->register_function($worker => sub {
            infof("start $worker");
            my $job = shift;
            my $return = $worker->work($job);
            infof("end $worker");
            return $return;
        });
    }

    return $self;
}

sub run {
    my ($self, ) = @_;
    $self->{gearman}->work(stop_if => sub {
        my ($idol, $last_job_time) = @_;
        return $idol ? 1 : 0;
    });
}

1;
