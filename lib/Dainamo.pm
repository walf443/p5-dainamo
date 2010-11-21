package Dainamo;
use strict;
use warnings;
use Mouse;
use Try::Tiny;
use Parallel::Prefork::SpareWorkers qw/STATUS_IDLE/;
use Log::Minimal qw/infof warnf critf debugf/;;
use Proc::Daemon;
our $VERSION = '0.01';

has 'max_workers' => (
    is => 'ro',
);

has 'daemonize' => (
    default => 0,
    is => 'rw',
);

has 'log_path' => (
    is => 'ro',
);

has 'log_level' => (
    is => 'rw',
    default => 'debug',
);

has 'profiles' => (
    is => 'ro',
    default => sub { [] },
);

sub run {
    my ($self, ) = @_;

    Proc::Daemon::Init if $self->daemonize;

    local $ENV{LM_DEBUG} = 1 if $self->log_level eq 'debug';
    local $Log::Minimal::PRINT = sub {
        my ($time, $type, $message, $trace) = @_;
        my $format = "[$time] [$type] [$$] $message at $trace\n";
        if ( $self->log_path ) {
            open my $fh, $self->log_path
                or die qq|Can't open "@{[ $self->log_path ]}|;

            print $fh $format;
            close $fh;
        } else {
            print STDERR $format;
        }
    };

    infof("starting $0 [pid: $$]");

    my $child_pid_of = {};
    for my $profile ( @{ $self->{profiles} } ) {
        my $num_profiles = @{ $self->{profiles} };
        # TODO: consider weight.
        my $max_workers = int($self->max_workers / $num_profiles ) || 1; # at least over 1.
        my $pid = fork;
        if ( $pid ) {
            $child_pid_of->{$pid} = 1;
        } else {
            $0 .= ": $profile";
            infof("worker manager process: $profile [pid: $$] max_workers: $max_workers");
            my $pm = Parallel::Prefork::SpareWorkers->new({
                max_workers => $max_workers,
                min_spare_workers => $max_workers,
                trap_signals => {
                    INT  => 'TERM',
                    TERM => 'TERM',
                    HUP  => 'TERM',
                },
            });
            for my $sig ( qw/ TERM INT / ) {
                $SIG{$sig} = sub {
                    debugf("trap signal: $sig");
                    infof("start graceful shutdown $0 [pid: $$]");
                    $pm->signal_all_children('TERM');
                    $pm->wait_all_children;
                    infof("shutdown $0");
                    exit;
                };
            }
            while ( $pm->signal_received ne 'TERM' ) {
                $pm->start and next;
                srand; # It's trap to call rand in child process. so, initialized.

                debugf("child process: $profile [pid: $$]");

                my $requests_per_child = $profile->max_requests_per_child;
                local $SIG{TERM} = sub {
                    debugf("trap signal: TERM");
                    $requests_per_child = 0;
                };
                local $SIG{INT} = sub {
                    debugf("trap signal: INT");
                    exit;
                };
                while ( $requests_per_child ) {
                    try {
                        $requests_per_child--;
                        $profile->run;
                    } catch {
                        my $error = $_;
                        critf($error);
                    };
                }

                $pm->finish;
            }
            $pm->wait_all_children();
        }
    }
    for my $sig ( qw/TERM INT HUP/ ) {
        $SIG{$sig} = sub {
            debugf("trap signal: $sig");
            for my $pid ( keys %{ $child_pid_of } ) {
                kill $sig, $pid;
            }
        };
    }
    while ( keys %{ $child_pid_of } ) {
        my $pid = wait;
        delete $child_pid_of->{$pid};
    }
    infof("shutdown $0");

}

sub add_profile {
    my ($self, %args) = @_;

    push @{ $self->{profiles} }, $args{profile};
}

1;
__END__

=head1 NAME

Dainamo - manage worker processes.

=head1 SYNOPSIS

  use Dainamo;
  my $dainamo = Dainamo->new(
    max_workers => 10,
  );
  $dainamo->add_profile(
      profile => Dainamo::Profile::Gearman->new(
        name => 'Project1',
        config => {
            job_servers => '127.0.0.1:7003',
            workers => [qw( Project1::Worker::Job1 Project1::Worker::Job2 )],
        }
      ),
      weight  => 1.0,
  );
  if ( $ENV{DEVELOPMENT} ) {
  } else {
    $dainamo->daemonize(1);
  }
  $dainamo->run;

=head1 DESCRIPTION

Dainamo is

=head1 AUTHOR

Keiji Yoshimi E<lt>walf443 at gmail dot comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
