package Dainamo;
use strict;
use warnings;
use Mouse;
use Try::Tiny;
use Parallel::Prefork;
use Parallel::Scoreboard;
use Log::Minimal qw/infof warnf critf debugf/;;
use Proc::Daemon;
use Plack::Handler::HTTP::Server::PSGI;
use Plack::Builder;
use Dainamo::Util;
use Encode;
our $VERSION = '0.01';
use 5.00800;

has 'max_workers' => (
    is => 'rw',
);

has 'daemonize' => (
    default => 0,
    is => 'rw',
);

has 'log_path' => (
    is => 'rw',
);

has 'log_level' => (
    is => 'rw',
    default => 'debug',
);

has 'profiles' => (
    is => 'ro',
    default => sub { [] },
);

has 'scoreboard_path' => (
    is => 'ro',
    default => sub {
        "/tmp/dainamo/$$/",
    },
);

my $PROGNAME = $0;

sub scoreboard {
    my ($self, ) = @_;

    $self->{__scoreboard} ||= sub {
        system(sprintf("mkdir -p %s", $self->scoreboard_path)); # FIXME: support win32
        Parallel::Scoreboard->new(base_dir => $self->scoreboard_path);
    }->();
}

sub update_scoreboard {
    my ($self, $hashref) = @_;

    $self->{__scoreboard_status} ||= {};
    return Dainamo::Util::update_scoreboard($self->scoreboard, $self->{__scoreboard_status}, $hashref);
}

sub run {
    my ($self, ) = @_;

    Proc::Daemon::Init if $self->daemonize;

    $self->scoreboard; # create scoreboard instance.
    $self->update_scoreboard({
        type => 'master',
        status => 'init',
        max_workers => $self->max_workers,
    });

    local $ENV{LM_DEBUG} = 1 if $self->log_level eq 'debug';
    local $Log::Minimal::PRINT = sub {
        $self->output_log(@_);
    };

    infof("starting $0 [pid: $$]");

    my $child_pid_of = {};

    my $admin_port_pid = fork();
    die "Can't fork: $!" unless defined $admin_port_pid;
    if ( $admin_port_pid ) {
        $child_pid_of->{$admin_port_pid}++;
    } else {
        $self->_start_admin_server;
    }

    my $total_weight = 0;
    my $num_profiles = 0;
    for my $profile ( @{ $self->{profiles} } ) {
        $total_weight += $profile->weight;
        $num_profiles++;
    }
    # 100
    #   hoge: 1.0: 33
    #   fuga: 2.0: 66 ( 100 / 3.0 ) * 2.0 = 33.33 * 2 
    for my $profile ( @{ $self->{profiles} } ) {
        my $max_workers = int($self->max_workers * $profile->weight / $total_weight ) || 1; # at least over 1.
        my $pid = fork;
        die "Can't fork: $!" unless defined $pid;
        if ( $pid ) {
            $child_pid_of->{$pid} = 1;
        } else {
            $self->_start_manager($profile, $max_workers);
        }
    }
    for my $sig ( qw/TERM INT HUP/ ) {
        $SIG{$sig} = sub {
            debugf("trap signal: $sig");
            if ( $sig ne 'HUP' ) {
                $self->update_scoreboard({ status => 'finish' });
            }
            for my $pid ( keys %{ $child_pid_of } ) {
                kill $sig, $pid;
            }
        };
    }
    $self->update_scoreboard({ status => 'running' });
    while ( keys %{ $child_pid_of } ) {
        my $pid = wait;
        delete $child_pid_of->{$pid};
    }
    infof("shutdown $0");

}

sub _start_child {
    my ($self, $profile) = @_;

    $self->update_scoreboard({
        type => 'child',
        profile_name => $profile->inspect,
        status => 'init',
    });
    $0 = "$PROGNAME: [child] $profile";
    srand; # It's trap to call rand in child process. so, initialized.

    debugf("child process: $profile [pid: $$]");

    my $requests_per_child = $profile->max_requests_per_child;
    local $SIG{TERM} = sub {
        debugf("trap signal: TERM");
        $requests_per_child = 0;
        $self->update_scoreboard({
            status => 'finish',
        });
    };
    local $SIG{INT} = sub {
        debugf("trap signal: INT");
        $self->update_scoreboard({
            status => 'finish',
        });
        exit;
    };
    local $SIG{__WARN__} = sub {
        warnf(@_);
    };
    while ( $requests_per_child ) {
        try {
            $requests_per_child--;
            $profile->run;
        } catch {
            my $error = $_;
            critf($error);
        };
    }

    $self->update_scoreboard({
        status => 'finish',
    });
}

sub _start_manager {
    my ($self, $profile, $max_workers) = @_;

    $self->update_scoreboard({
        type => 'manager',
        profile_name => $profile->inspect,
        max_workers => $max_workers,
        status => 'init',
    });
    $0 = "$PROGNAME: [manager] $profile";
    infof("worker manager process: $profile [pid: $$] max_workers: $max_workers");
    my $pm = Parallel::Prefork->new({
        max_workers => $max_workers,
        trap_signals => {
            INT  => 'INT',
            TERM => 'TERM',
            HUP  => 'TERM',
        },
    });

    local $SIG{TERM} = sub {
        debugf("trap signal: TERM");
        infof("start graceful shutdown $0 [pid: $$]");
        $pm->signal_all_children('TERM');
        $self->update_scoreboard({ status => 'finish' });
        $pm->wait_all_children;
        infof("shutdown $0");
        exit;
    };

    local $SIG{INT} = sub {
        debugf("trap signal: INT");
        infof("start shutdown $0 [pid: $$]");
        $pm->signal_all_children('INT');
        $self->update_scoreboard({ status => 'finish' });
        infof("shutdown $0");
        exit;
    };

    $self->update_scoreboard({ status => 'waiting' });
    while ( $pm->signal_received ne 'TERM' ) {
        $pm->start and next;
        $self->_start_child($profile);
        $pm->finish;
    }
    $self->update_scoreboard({ status => 'finish' });
    $pm->wait_all_children();
    exit;
}

sub _start_admin_server {
    my ($self, ) = @_;

    $0 = "$PROGNAME: [admin]";
    my $server = Plack::Handler::HTTP::Server::PSGI->new(
        host => '127.0.0.1', # TODO can handle local network.
        port => '10076', # dai na mo
    );

    my $app = sub {
        my $env = shift;

        return $self->_admin_server_app($env);
    };
    use Plack::Middleware::ContentLength;
    $app = Plack::Middleware::ContentLength->wrap($app);
    $server->run($app);
}

sub _admin_server_app {
    my ($self, $env) = @_;
    my $class = ref $self;

    if ( $env->{PATH_INFO} =~ qr{^/rcp/([^/]+)} ) {
        my $action = $1;
        my $method_name = "_admin_action_$1";
        if ( $self->can($method_name) ) {
            return $self->$method_name($env);
        }
    }

    return [404, [], ["not found"]];
}

sub _admin_action_scoreboard {
    my ($self, $env) = @_;
    my $result = "";

    my $stats = $self->scoreboard->read_all();
    for my $pid ( sort { $a <=> $b } keys %$stats ) {
        my $message = $stats->{$pid};
        next unless $env->{QUERY_STRING} =~ /type=([^&]+)/ && $message =~ /\btype\t$1\b/;
        $result .= sprintf("pid\t%s\t%s\n", $pid, $message);
    }
    return [200, ['Content-Type', 'text/tab-separacetd-values; encoding=UTF-8'], [$result]];
}

sub output_log {
    my ($self, $time, $type, $message, $trace) = @_;

    my $format = "[$time] [$type] [$$] $message at $trace\n";
    if ( $self->log_path ) {
        my $fh;
        # you can specify log_path like followings:
        #   log_path => qq{| /usr/sbin/cronolog "/var/log/dainamo/%Y%m%d.log"}
        if ( $self->log_path =~ /^\|\s+/ ) {
            open $fh, $self->log_path ## no critic
                or die qq|Can't open "@{[ $self->log_path ]}"|;
        } else {
            open $fh, '>>', $self->log_path
                or die qq|Can't open "@{[ $self->log_path ]}"|;
        }

        print $fh $format;
        close $fh;
    } else {
        print STDERR $format;
    }
}

sub add_profile {
    my ($self, %args) = @_;

    push @{ $self->{profiles} }, $args{profile};
}

sub add_profile_group {
    my ($self, %args) = @_;

    for my $profile ( $args{group}->profiles ) {
        $self->add_profile(
            profile => $profile,
        );
    }
}

sub load_profiles {
    my ($self, $file) = @_;

    my $group = Dainamo::Util::load($file);
    unless ( $group && ref $group && $group->isa('Dainamo::ProfileGroup') ) {
        die "Can't load config: $file and take $group. you should evaluate Dainamo::ProfileGroup instance at the end of file."
    }
    $self->add_profile_group(group => $group);
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
      profile => Dainamo::Profile::Gearman->new(
        name => 'Project1',
        config => {
            job_servers => '127.0.0.1:7003',
            workers => [qw( Project1::Worker::Job1 Project1::Worker::Job2 )],
        }
      ),
  );
  if ( $ENV{DEVELOPMENT} ) {
  } else {
    $dainamo->daemonize(1);
  }
  $dainamo->run;

=head1 DESCRIPTION

Dainamo is an apllication that manage worker process.

THIS SOFTWARE IS ALPHA QUALITIY. API MAY CHANGE IN FUTURE.

Api is in discussion at <irc://irc.freenode.org/#dainamo>

=head1 AUTHOR

Keiji Yoshimi E<lt>walf443 at gmail dot comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
