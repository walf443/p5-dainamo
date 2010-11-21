package Dainamo;
use strict;
use warnings;
use Mouse;
use Try::Tiny;
use Parallel::Prefork::SpareWorkers qw/STATUS_IDLE/;
use Log::Minimal qw/infof warnf critf debugf/;;
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

    my @child_pids;
    for my $profile ( @{ $self->{profiles} } ) {
        my $num_profiles = @{ $self->{profiles} };
        # TODO: consider weight.
        my $max_workers = $self->max_workers / $num_profiles;
        my $pid = fork;
        if ( $pid ) {
            push @child_pids, $pid;
        } else {
            $0 .= ": $profile";
            my $pm = Parallel::Prefork::SpareWorkers->new({
                max_workers => $max_workers,
                min_spare_workers => $max_workers,
                trap_signals => {
                    TERM => 'TERM',
                    HUP  => 'TERM',
                    USR1 => undef,
                },
            });
            $SIG{INT} = sub {
                infof("start graceful shutdown $0 [pid: $$]");
                exit;
            };
            while ( $pm->signal_received ne 'TERM' ) {
                $pm->start and next;
                $SIG{INT} = sub {
                    exit; # reset SIG INT.
                };

                debugf("child process: $profile [pid: $$]");

                try {
                    $profile->run;
                } catch {
                    my $error = $_;
                    critf($error);
                };

                $pm->finish;
            }
            $pm->wait_all_children();
        }
    }
    wait;

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
      profile => Dainamo::Profile::Gearman->new(),
      weight  => 1.0,
  );
  if ( $ENV{DEVELOPMENT} ) {
    $dainamo->daemonize(1);
  } else {
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
