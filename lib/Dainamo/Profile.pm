package Dainamo::Profile;
use strict;
use warnings;
use overload '""' => \&inspect;

sub new {
    my ($class, %args) = @_;
    bless \%args, $class;
}

sub inspect {
    my ($self, ) = @_;
    my $class = ref $self;
    return $self->{name} ? "$class\[@{[ $self->{name} ]}]" : $class;
}

sub run {
    die "please implement";
}

1;
