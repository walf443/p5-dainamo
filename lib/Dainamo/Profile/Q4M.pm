package  Dainamo::Profile::Q4M;
use strict;
use warnings;
use parent 'Dainamo::Profile';

use Log::Minimal qw/debugf warnf/;
use Dainamo::Util;
use Class::Load qw();
use Time::HiRes qw/gettimeofday/;
use Queue::Q4M;
use Try::Tiny;

our $DEFAULT_WORK_DELAY = 5;

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    $self->{counter} = 0;
    $self->table_list; # for CoW
    return $self;
}

sub create_q4m_client {
    my $self = shift;

    return Queue::Q4M->new(
        %{ $self->{config}->{q4m} },
    );
}

sub workers { shift->{config}->{workers} }

sub table_list {
    my $self = shift;

    return $self->{table_list} ||= $self->create_table_list;
}

sub create_table_list {
    my $self = shift;

    return [ keys %{ $self->table2worker } ];
}

sub table2worker {
    my $self = shift;

    return $self->{table2worker} ||= $self->create_table2worker;
}

sub create_table2worker {
    my $self = shift;

    my %table2worker;
    for my $worker (@{ $self->workers }) {
        Class::Load::load_class($worker);
        $table2worker{ $worker->table_name } = $worker;
    }

    return \%table2worker;
}

sub rotate_table_list {
    my ($self, $i) = @_;

    my $table = splice(@{ $self->table_list }, $i, 1);
    push(@{ $self->table_list } => $table);
}

sub run {
    my ($self, %args) = @_;

    my $scoreboard        = $args{scoreboard};
    my $scoreboard_status = $args{scoreboard_status};

    my $start_time = gettimeofday;
    debugf("start Dainamo::Profile::Q4M#run()");
    my $work_delay = $self->{config}->{work_delay} || $DEFAULT_WORK_DELAY;
    Dainamo::Util::update_scoreboard($scoreboard, $scoreboard_status, {
        status => 'running',
    });
    if ( $self->work_once ) {
        $self->{counter}++;
        Dainamo::Util::update_scoreboard($scoreboard, $scoreboard_status, {
            status => 'waiting',
            counter => $self->{counter},
        });
        my $manager_pid = getppid();
        $self->client->get('update_counter', { manager_pid => $manager_pid });
    }
    else {
        debugf("sleep Dainamo::Profile::Q4M#run()");
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
    debugf("finish Dainamo::Profile::Q4M#run() ($time sec.)");
}

sub work_once {
    my $self = shift;
    my $q4m  = $self->create_q4m_client;

    for my $i (0 .. $#{ $self->table_list }) {
        my $table = $self->table_list->[$i];
        if ( $q4m->next($table) ) {
            unless ($self->{config}->{disable_rotate_table_list}) {
                $self->rotate_table_list($i);
            }

            $self->try_work($q4m => $table);
            return 1;
        }
    }

    # job not found
    $q4m->disconnect;
    return 0;
}

sub try_work {
    my ($self, $q4m, $table) = @_;

    try {
        my $worker = $self->table2worker->{$table};
        my $arg = $q4m->fetch_hashref($table, ['*']);
        $worker->work($arg);
        $q4m->disconnect;
    }
    catch {
        warnf($_);
    };
}

1;

__END__

=head1 NAME

Dainamo::Profile::Q4M


=head1 SYNOPSIS

    use Dainamo::Profile::Q4M;

    my $profile = Dainamo::Profile::Q4M->new(
        name => "Proj[Q4M]",
        weight => 1.0,
        config => {
            q4m => +{
                # same as L<Queue::Q4M> constructor's argument.
                connect_info => [
                    'dbi:mysql:dbname=mydb',
                    $username,
                    $password
                ],
            },
            work_delay => 5,
            workers    => [ 'Proj1::Worker::Q4M::HogeHoge' ],
        }
    );

    # your worker class is called by followings:
    #   Proj1::Worker::Q4M::HogeHoge->work($arg);
    #   $arg is a HashRef.
    # so your worker implement is like that:

    package Proj1::Worker::Q4M::HogeHoge;

    sub work {
        my ($class, $arg) = @_;

        # do some work
    }


=head2 SEE ALSO

L<Queue::Q4M>, L<Dainamo::Profile>

