package  Dainamo::Profile::Gearman;
use strict;
use warnings;
use parent 'Dainamo::Profile';
use Gearman::Worker;
use Class::Load qw();
use Log::Minimal qw/infof debugf/;
use Dainamo::Util;
use Time::HiRes qw/gettimeofday/;
use Dainamo::Client;

sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(%args);

    return $self;
}

sub gearman {
    my ($self, ) = @_;
    $self->{gearman} ||= sub {
        my $gearman = Gearman::Worker->new;
        $gearman->job_servers( @{ $self->{config}->{job_servers} } );
        $gearman->prefix($self->{config}->{prefix}) if $self->{config}->{prefix};

        $gearman;
    }->();
}

sub register_workers {
    my ($self, %args) = @_;

    for my $worker ( @{ $self->{config}->{workers} } ) {
        Class::Load::load_class($worker);

        $self->gearman->register_function($worker => sub {
            my $job = shift;
            
            infof("start $worker");
            my $start_time = gettimeofday;
            my $original_sig_term = $SIG{TERM};
            local $SIG{TERM} = $args{on_sigterm} || $original_sig_term;

            my $return = $worker->work_job($job);

            my $finish_time = gettimeofday;
            my $time = $finish_time - $start_time;
            infof(sprintf("finish $worker (%.6f sec.)", $time));
            return $return;
        });
    }

}

sub run {
    my ($self, %args) = @_;

    my $class = ref $self;

    # max_requests_per_childを越えてforkした場合にソケットが共有されてしまうことがあるっぽい
    $self->{gearman} = undef; 
    
    debugf("start Dainamo::Profile::Gearman#run()");

    Dainamo::Util::update_scoreboard($args{scoreboard}, $args{scoreboard_status}, {
        status => 'waiting',
    });

    my $manager_pid = getppid();
    my $original_sig_term =  $SIG{TERM};
    $self->register_workers(on_sigterm => $original_sig_term);
    local $SIG{TERM} = 'DEFAULT'; # give up graceful shutdown.
    local $SIG{INT} = 'DEFAULT';
    my $counter = 0;
    $self->gearman->work(
        on_start => sub {
            my ($job_handle, ) = @_;
            $counter++;
            Dainamo::Util::update_scoreboard($args{scoreboard}, $args{scoreboard_status}, {
                status => 'running',
                counter => $counter,
            });
            $self->client->get('update_counter', { manager_pid => $manager_pid });
        },
        on_complete => sub {
            my ($job_handle, ) = @_;
            Dainamo::Util::update_scoreboard($args{scoreboard}, $args{scoreboard_status}, {
                status => 'waiting',
                counter => $counter,
            });
        },
        on_fail => sub {
            my ($job_handle, ) = @_;
            Dainamo::Util::update_scoreboard($args{scoreboard}, $args{scoreboard_status}, {
                status => 'waiting',
                counter => $counter,
            });
        },
        stop_if => sub {
            my ($is_idol, $last_job_time) = @_;
            return $counter > $self->max_requests_per_child;
        }
    );
    debugf("finish Dainamo::Profile::Gearman#run()");
    exit; # gearma->work is work over $max_requests_per_child times. so exit.
}

1;

__END__

=head2 NAME

Dainamo::Profile::Gearman


=head2 SYNOPSIS

    use Dainamo::Profile::Gearman;
    my $dainamo = Dainamo::Profile::Gearman->new(
        job_servers => [ '127.0.0.1:7003' ],
        prefix => "Proj1",
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




