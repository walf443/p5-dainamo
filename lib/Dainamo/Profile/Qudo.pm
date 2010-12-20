package  Dainamo::Profile::Qudo;
use strict;
use warnings;
use parent 'Dainamo::Profile';
use Qudo;
use Log::Minimal qw/debugf/;

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    $self->qudo; # for CoW.
    return $self;
}

sub qudo {
    my ($self, ) = @_;
    $self->{qudo} ||= Qudo->new(
        %{ $self->{config} },
    );
}

sub run {
    my ($self, ) = @_;

    debugf("start Dainamo::Profile::Qudo#run()");
    # copied from Qudo's work.
    my $work_delay = $self->qudo->{work_delay};
    unless ( $self->qudo->manager->work_once ) {
        $self->{qudo} = undef; # disconnect while sleep.
        debugf("sleep Dainamo::Profile::Qudo#run()");
        # exit if SIGTERM in sleep.
        local $SIG{TERM} = sub {
            exit;
        };
        sleep $work_delay;
    }
    $self->{qudo} = undef;
    debugf("finish Dainamo::Profile::Qudo#run()");
}

1;

__END__

=head1 NAME

Dainamo::Profile::Qudo


=head1 SYNOPSIS

    use Dainamo::Profile::Qudo;

    my $profile = Dainamo::Profile::Qudo->new(
        name => "Proj[Qudo]",
        weight => 1.0,
        config => {
            driver_class => 'Skinny',
            databases => [{
                dsn => 'dbi:mysql:proj1;
                username => 'root',
                password => '',
            }],
            default_hooks => [
                'Qudo::Hook::Serialize::JSON',
            ],
            # same as L<Qudo> constructor's argument.
        }
    );


=head2 SEE ALSO

L<Qudo>, L<Dainamo::Profile>

