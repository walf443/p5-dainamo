package Dainamo::Profile;
use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    bless \%args, $class;
}

sub run {
    die "please implement";
}

1;
