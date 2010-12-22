package  Dainamo::Util;
use strict;
use warnings;

our $DAINAMO_ADMIN_PORT_DEFAULT = 5176; # da i(1) na(7) mo(6)
our $DAINAMO_ADMIN_HOST_DEFAULT = '127.0.0.1';

# this code copied from Plack::Util::_load_sandbox.
sub _load_sandbox {
    my $_file = shift;

    my $_package = $_file;
    $_package =~ s/([^A-Za-z0-9_])/sprintf("_%2x", unpack("C", $1))/eg;

    return eval sprintf <<'END_EVAL', $_package; ## no critic
package Dainamo::Sandbox::%s;
{
    my $app = do $_file;
    if ( !$app && ( my $error = $@ || $! )) { die $error; }
    $app;
}
END_EVAL
}

sub load {
    my $file = shift;
    my $dainamo = _load_sandbox($file);
    die "Error while loading $file: $@" if $@;

    return $dainamo;
}

sub update_scoreboard {
    my ($scoreboard, $cache_hashref, $value_hashref) = @_;

    $cache_hashref->{$$} ||= {};
    for my $key ( keys %{ $value_hashref } ) {
        $cache_hashref->{$$}->{$key} = $value_hashref->{$key};
    }

    my @data;
    for my $key ( sort { $a cmp $b } keys %{ $cache_hashref->{$$} } ) {
        my $escaped_key = $key;
        $escaped_key =~ s/\t/ /g;
        my $escaped_value = $cache_hashref->{$$}->{$key};
        $escaped_value =~ s/\t/ /g;
        push @data, $escaped_key, $escaped_value;
    }
    my $message = join "\t", @data; # data is TSV format.
    $scoreboard->update($message);
}

1;
