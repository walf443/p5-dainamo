package  Dainamo::Util;
use strict;
use warnings;

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

1;
