package Dainamo;
use strict;
use warnings;
use Mouse;
use Parallel::Prefork::SpareWorkers qw/STATUS_IDLE/;
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
    default => 'info',
);

has 'profiles' => (
    is => 'ro',
    default => sub { [] },
);

sub run {
    my ($self, ) = @_;

    warn $self->max_workers;
    my $pm = Parallel::Prefork::SpareWorkers->new({
        max_workers => $self->max_workers,
        min_spare_workers => $self->max_workers,
        trap_signals => {
            TERM => 'TERM',
            HUP  => 'TERM',
            USR1 => undef,
        },
    });

    my @profiles = @{ $self->{profiles} };

    while ( $pm->signal_received ne 'TERM' ) {
        $pm->start and next;

        my $profile = $profiles[rand(@profiles)];
        $profile->run;

        $pm->finish;
    }
    $pm->wait_all_children();

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
