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
        $worker->use
            or die $@;

        $self->{gearman}->register_function($worker => sub {
            infof("start $worker");
            my $job = shift;
            my $return = $worker->work_job($job);
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
        return 1;
    });
}

1;

__END__

=head2 NAME

Dainamo::Profile::Gearman


=head2 SYNOPSIS

    use Dainamo::Profile::Gearman;
    my $dainamo = Dainamo::Profile::Gearman->new(
        job_servers => [ '127.0.0.1:7003' ],
        workers => [ 'Proj1::Worker::Gearman::HogeHoge' ],
    );

    # your worker class is called by followings:
    #   Proj1::Worker::Gearman::HogeHoge->work_job($job);
    #   $job is a Gearman::Job.
    # so your worker implement is like that:
    
    package Proj1::Worker::Gearman::HogeHoge;
    use Storable;

    sub work_job {
        my ($class, $job) = @_;
        my $args = Storable::thaw($job->arg);
        my $result = $class->work($job);
        return Storable::nfreeze($result);
    }




