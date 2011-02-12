package  Dainamo::Runner;
use strict;
use warnings;
use Dainamo;
use Dainamo::Util;
use opts;

sub new {
    my ($class, %args) = @_;
    bless \%args, $class;
}

sub parse_option {
    my $self = shift;

    local @ARGV = @_;

    opts my $max_workers => { isa => 'Int', comment => 'total process number of workers.'},
        my $daemonize => { isa => 'Bool', default => 0, comment => 'do daemonize?' },
        my $reload => { isa => 'Bool' , comment => 'do reload if $watcher files is changed' },
        my $log_path => { isa => 'Str', comment => 'output path to log. you can also pipe with starting from "| ...".  and you can output $stderr when you specify STDERR.' },
        my $log_level => { isa => 'Str', comment => 'specify log level. (info|debug)' },
        my $watch_path => { isa => 'Str', comment => 'watching changing $watch_path and reload if $reload.' }, # FIXME: ほんとはPlack::Runnerにそろえたい(Reload)が、opts.pmの制限っぽい
        my $config => { isa => 'Str', required => 1, comment => "config filename to load" };

    $self->{max_workers} = $max_workers;
    $self->{log_path} = $log_path;
    $self->{log_level} = $log_level;
    if ( $watch_path ) {
        my @watch_paths = split(/,/, $watch_path);
        $self->{watch_path} = \@watch_paths;
    } else {
        $self->{watch_path} = ['.'];
    }

    $self->{daemonize} = $daemonize;
    $self->{reload} = $reload;
    $self->{config} = $config;

    return $self;
}

sub run {
    my ($self, ) = @_;

    my $reload = $self->{reload};

    if ( $reload ) {
        while ( 1 ) {
            my $pid = fork;
            die "Can't fork: $!" unless defined $pid;

            if ( $pid ) {
                $self->watcher(target_pid => $pid);
            } else {
                $self->starter();
                exit;
            }
        }
    } else {
        $self->starter();
    }
};

# watcher process.
sub watcher {
    my ($self, %args) = @_;

    my $pid = $args{target_pid};

    local $0 = "$0: [watcher]";
    local $SIG{TERM} = sub {
        kill 'TERM', $pid;
        wait;
        exit;
    };
    eval {
        require Filesys::Notify::Simple;
    };
    if ( $@ ) {
        warn "Can't find Filesys::Notify::Simple. please install.";
        $SIG{TERM}->();
    }
    eval {
        my $watcher = Filesys::Notify::Simple->new($self->{watch_path});
        $watcher->wait(sub {
            warn "file changed. restarting $0";
            kill 'INT', $pid;
        });
    };
    if ( $@ ) {
        warn "watcher catch error: $@";
        $SIG{TERM}->();
    }
    wait;
}

sub starter {
    my ($self, ) = @_;

    my $config = $self->{config};
    my $dainamo = Dainamo::Util::load($config);
    unless ( $dainamo && ref $dainamo && $dainamo->isa('Dainamo') ) {
        die "Can't load config: $config. you should evaluate Dainamo instance at the end of file"
    }
    if ( $self->{max_workers} ) {
        $dainamo->max_workers($self->{max_workers});
    }
    die "please set max_workers" if !$dainamo->max_workers;

    if ( defined $self->{log_path} ) {
        if ( $self->{log_path} eq "STDERR" ) {
            $dainamo->log_path(undef);
        } else {
            $dainamo->log_path($self->{log_path});
        }
    }
    if ( defined $self->{log_level} ) {
        $dainamo->{log_level} = $self->{log_level};
    }

    if ( defined $self->{daemonize} ) {
        $dainamo->daemonize($self->{daemonize});
    }

    $dainamo->run;
}

1;
