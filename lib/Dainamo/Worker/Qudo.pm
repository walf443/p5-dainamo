package  Dainamo::Worker::Qudo;
use strict;
use warnings;
use base qw(Qudo::Worker);
use Log::Minimal qw/infof critf warnff/;
use Data::Dumper;

sub work_safely {
    my $class = shift;
    my $job = shift;
    
    infof("start $class");
    my $ret;
    # FIXME: 
    {
        local $SIG{__DIE__} = sub {
            my $caller = caller(1);
            critf(@_) if $caller eq 'Qudo::Worker';
            die @_;
        };
        $ret = $class->SUPER::work_safely($job, @_);
    }
    critf('Job did not explicitly complete or fail') unless $job->is_completed;
    infof("finish $class");
    return $ret;

}

1;

