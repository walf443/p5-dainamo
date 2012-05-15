package Dainamo::Profile;
use strict;
use warnings;
use overload '""' => \&inspect;

use Dainamo::Client;

sub new {
    my ($class, %args) = @_;
    bless \%args, $class;
}

sub force_max_workers { $_[0]->{force_max_workers} || 0 }

sub max_requests_per_child {
    my ($self, ) = @_;
    $self->{max_requests_per_child} || 40;
}

sub weight {
    my ($self, ) = @_;
    $self->{weight} || 1.0;
}

sub inspect {
    my ($self, ) = @_;
    my $class = ref $self;
    return $self->{name} ? "$class\[@{[ $self->{name} ]}]" : $class;
}

sub client {
    my ($self, ) = @_;
    return unless $ENV{DAINAMO_ADMIN_PORT};
    $self->{dainamo} ||= Dainamo::Client->new(server => $ENV{DAINAMO_ADMIN_PORT});
}

sub run {
    die "please implement";
}

1;

__END__

=head1 NAME

Dainamo::Profile - base class of Profile.

=head1 SYNOPSIS

    use Dainamo;
    use Dainamo::Profile;

    my $dainamo = Dainamo->new(...);
    my $profile = Dainamo::Profile->new(
        name => "Proj1::Worker::XXX", # profile name. you can show with "ps | grep dainamo"
        max_requests_per_child => 10, # child is die  when it called over $max_requests_per_child times. It's prevent to leak memory seriously. default is 40.
        weight => 3,
        config => { 
            # ...,
        },
    );
    
    $dainamo->add_profile(profile => $profile);


    # implement your custom Profile.

    package Dainamo::Profile::HogeHoge;
    use parent(Dainamo::Profile);

    sub run {
        # do work a job. arguments are nothing.
    }


