package Dainamo;
use strict;
use warnings;
use Mouse;
use Try::Tiny;
use Parallel::Prefork::SpareWorkers qw/STATUS_IDLE/;
use Log::Minimal qw/infof warnf critf debugf/;;
use Proc::Daemon;
use Dainamo::Util;
our $VERSION = '0.01';
use 5.00800;

has 'max_workers' => (
    is => 'rw',
);

has 'daemonize' => (
    default => 0,
    is => 'rw',
);

has 'log_path' => (
    is => 'rw',
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
            my $fh;
            # you can specify log_path like followings:
            #   log_path => qq{| /usr/sbin/cronolog "/var/log/dainamo/%Y%m%d.log"}
            if ( $self->log_path =~ /^\|\s+/ ) {
                open $fh, $self->log_path ## no critic
                    or die qq|Can't open "@{[ $self->log_path ]}"|;
            } else {
                open $fh, '>>', $self->log_path
                    or die qq|Can't open "@{[ $self->log_path ]}"|;
            }

            print $fh $format;
            close $fh;
        } else {
            print STDERR $format;
        }
    };

    infof("starting $0 [pid: $$]");

    my $child_pid_of = {};
    my $prog_name = $0;
    for my $profile ( @{ $self->{profiles} } ) {
        my $num_profiles = @{ $self->{profiles} };
        # TODO: consider weight.
        my $max_workers = int($self->max_workers / $num_profiles ) || 1; # at least over 1.
        my $pid = fork;
        die "Can't fork: $!" unless defined $pid;
        if ( $pid ) {
            $child_pid_of->{$pid} = 1;
        } else {
            $0 = "$prog_name: [manager] $profile";
            infof("worker manager process: $profile [pid: $$] max_workers: $max_workers");
            my $pm = Parallel::Prefork::SpareWorkers->new({
                max_workers => $max_workers,
                min_spare_workers => $max_workers,
                trap_signals => {
                    INT  => 'INT',
                    TERM => 'TERM',
                    HUP  => 'TERM',
                },
            });

            local $SIG{TERM} = sub {
                debugf("trap signal: TERM");
                infof("start graceful shutdown $0 [pid: $$]");
                $pm->signal_all_children('TERM');
                $pm->wait_all_children;
                infof("shutdown $0");
                exit;
            };

            local $SIG{INT} = sub {
                debugf("trap signal: INT");
                infof("start graceful shutdown $0 [pid: $$]");
                $pm->signal_all_children('INT');
                infof("shutdown $0");
                exit;
            };

            while ( $pm->signal_received ne 'TERM' ) {
                $pm->start and next;

                $0 = "$prog_name: [child] $profile";
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
            exit;
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


sub add_profile_group {
    my ($self, %args) = @_;

    for my $profile ( $args{group}->profiles ) {
        $self->add_profile(
            profile => $profile,
            weight => 1.0
        );
    }
}

sub load_profiles {
    my ($self, $file) = @_;

    my $group = Dainamo::Util::load($file);
    unless ( $group && ref $group && $group->isa('Dainamo::ProfileGroup') ) {
        die "Can't load config: $file and take $group. you should evaluate Dainamo::ProfileGroup instance at the end of file."
    }
    $self->add_profile_group(group => $group);
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

Dainamo is an apllication that manage worker process.

THIS SOFTWARE IS ALPHA QUALITIY. API MAY CHANGE IN FUTURE.

Api is in discussion at <irc://irc.freenode.org/#dainamo>

=head1 AUTHOR

Keiji Yoshimi E<lt>walf443 at gmail dot comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
