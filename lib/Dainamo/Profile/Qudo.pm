package  Dainamo::Profile::Qudo;
use strict;
use warnings;
use parent 'Dainamo::Profile';
use Qudo;
use Log::Minimal qw/debugf/;
use Dainamo::Util;
use Time::HiRes qw/gettimeofday/;

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    $self->{counter} = 0;
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
    my ($self, %args) = @_;

    my $scoreboard = $args{scoreboard};
    my $scoreboard_status = $args{scoreboard_status};

    my $start_time = gettimeofday;
    debugf("start Dainamo::Profile::Qudo#run()");
    # copied from Qudo's work.
    my $work_delay = $self->qudo->{work_delay} || $Qudo::WORK_DELAY;
    Dainamo::Util::update_scoreboard($scoreboard, $scoreboard_status, {
        status => 'running',
    });
    if ( $self->qudo->manager->work_once ) {
        $self->{counter}++;
        Dainamo::Util::update_scoreboard($scoreboard, $scoreboard_status, {
            status => 'waiting',
            counter => $self->{counter},
        });
        my $manager_pid = getppid();
        $self->client->get('update_counter', { manager_pid => $manager_pid });
    } else {
        $self->clear_qudo; # disconnect while sleep
        debugf("sleep Dainamo::Profile::Qudo#run()");
        # exit if SIGTERM in sleep.
        Dainamo::Util::update_scoreboard($scoreboard, $scoreboard_status, {
            status => 'waiting',
        });
        local $SIG{TERM} = sub {
            exit;
        };
        sleep $work_delay;
    }
    my $finish_time = gettimeofday;
    my $time = $finish_time - $finish_time;
    debugf("finish Dainamo::Profile::Qudo#run() ($time sec.)");
}

sub clear_qudo {
    my ($self, ) = @_;

    my $qudo = delete $self->{qudo};
    if ( $qudo ) {
        $qudo->{connections} = undef;
    }
}

1;

__END__

=head1 NAME

Dainamo::Profile::Qudo


=head1 SYNOPSIS

    use Dainamo::Profile::Qudo;

    my $profile = Dainamo::Profile::Qudo->new(
        name => "Proj[Qudo]",
        weight => 1.0,
        config => {
            driver_class => 'Skinny',
            databases => [{
                dsn => 'dbi:mysql:proj1;
                username => 'root',
                password => '',
            }],
            default_hooks => [
                'Qudo::Hook::Serialize::JSON',
            ],
            # same as L<Qudo> constructor's argument.
        }
    );


=head2 SEE ALSO

L<Qudo>, L<Dainamo::Profile>

