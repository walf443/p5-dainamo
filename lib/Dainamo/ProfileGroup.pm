package  Dainamo::ProfileGroup;
use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    my $self = bless \%args, $class;
    $self->{profiles} ||= [];
    return $self;
}

sub profiles {
    my $self = shift;

    return wantarray ? @{ $self->{profiles} } : $self->{profiles};
}

sub add_profile {
    my ($self, %args) = @_;

    push @{ $self->{profiles} }, $args{profile};
}

1;

__END__

=head2 NAME

Dainamo::ProfileGroup

=head2 SYNOPSIS

    use strict;
    use warnings;
    use Dainamo::ProfileGroup;

    my $group = Dainamo::ProfileGroup->new;
    $group->add_profile(profile => Dainamo::Profile->new(
        name => 'hoge',
        config => { #...
        },
    ));

