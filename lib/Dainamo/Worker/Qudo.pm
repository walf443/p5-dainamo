package  Dainamo::Worker::Qudo;
use strict;
use warnings;
use base qw(Qudo::Worker);
use Log::Minimal qw/infof critf warnff/;
use Data::Dumper;
use Time::HiRes qw/gettimeofday/;

sub work_safely {
    my $class = shift;
    my $job = shift;
    
    infof("start $class");
    my $start_time = gettimeofday;
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
    my $finish_time = gettimeofday;
    my $time = $finish_time - $start_time;
    infof(sprintf("finish $class (%.6f sec.)", $time));
    return $ret;

}

1;

