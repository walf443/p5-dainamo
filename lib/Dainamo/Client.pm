package  Dainamo::Client;
use strict;
use warnings;
use Furl;
use URI;
use Dainamo::Util;

sub new {
    my ($class, %args) = @_;

    my $furl = Furl->new(
        agent => 'Dainamo::Client/0.01',
        timeout => $args{timeout} || 10,
    );

    $args{server} ||= "$Dainamo::Util::DAINAMO_ADMIN_HOST_DEFAULT:$Dainamo::Util::DAINAMO_ADMIN_PORT_DEFAULT";
    $args{furl} = $furl;
    my $self = \%args;
    bless $self, $class;
}

sub get {
    my ($self, $action, $query, $options) = @_;

    my $uri = URI->new(sprintf("http://%s/rpc/%s", $self->{server}, $action));
    $uri->query_form($query);
    my $res = $self->{furl}->get($uri->as_string);
    if ( $res->code != 200 ) {
        die sprintf("Can't get URL: %s, status: %s", $uri->as_string, $res->status_line);
    }

    my @data;
    for my $line ( split /\n/, $res->body ) {
        chomp $line;
        my %args = split /\t/, $line;
        push @data, \%args;
    }

    return \@data;
}

1;
__END__

=head2 NAME

=head2 SYNOPSIS

    use Try::Tiny;
    my $client = Dainamo::Client->new(
        server => '127.0.0.1:5176'
    );

    try {
        my $data = $client->get('scoreboard' => {
            type => 'manager',
        }); # access /rpc/scoreboard?type=manager

        # data is arrayref
        # an item of data is hashref
    } catch {
        my $error = $_;
        # handle with errer.
    };

