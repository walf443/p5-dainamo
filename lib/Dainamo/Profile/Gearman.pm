package  Dainamo::Profile::Gearman;
use strict;
use warnings;
use parent 'Dainamo::Profile';
use Gearman::Worker;
use UNIVERSAL::require;
use Log::Minimal qw/infof debugf/;
use Dainamo::Util;

sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(%args);

    $self->{gearman} = Gearman::Worker->new;
    $self->{gearman}->job_servers(@{ $self->{config}->{job_servers} });
    $self->{gearman}->prefix($self->{config}->{prefix}) if $self->{config}->{prefix};

    $self->register_workers;

    return $self;
}

sub context {
    return {};
}

sub register_workers {
    my ($self, %args) = @_;

    for my $worker ( @{ $self->{config}->{workers} } ) {
        $worker->use
            or die $@;

        $self->{gearman}->register_function($worker => sub {
            my $job = shift;
            
            my $original_sig_term = $SIG{TERM};
            local $SIG{TERM} = $args{on_sigterm} || $original_sig_term;

            infof("start $worker");
            Dainamo::Util::update_scoreboard($self->context->{scoreboard}, $self->context->{scoreboard_status}, {
                status => 'running',
            });
            my $return = $worker->work_job($job);
            Dainamo::Util::update_scoreboard($self->context->{scoreboard}, $self->context->{scoreboard_status}, {
                status => 'waiting',
            });
            infof("end $worker");
            return $return;
        });
    }

}

sub run {
    my ($self, %args) = @_;

    my $class = ref $self;
    
    debugf("start Dainamo::Profile::Gearman#run()");

    no strict 'refs'; ## no critic.
    no warnings 'redefine';
    my $original_code = *{"$class\::context"};
    local *{"$class\::context"} = sub {
        return \%args;
    }; # localでやるとgearmanのfunctionのところに参照させられないので。

    Dainamo::Util::update_scoreboard($self->context->{scoreboard}, $self->context->{scoreboard_status}, {
        status => 'waiting',
    });

    my $original_sig_term =  $SIG{TERM};
    $self->register_workers(on_sigterm => $original_sig_term);
    local $SIG{TERM} = 'DEFAULT'; # give up graceful shutdown.
    local $SIG{INT} = 'DEFAULT';
    $self->{gearman}->work(stop_if => sub {
        my ($is_idol, $last_job_time) = @_;
        return $is_idol;
    });
    debugf("finish Dainamo::Profile::Gearman#run()");
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




