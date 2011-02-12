package HogeHoge::Worker::Gearman::Double;

use strict;
use warnings;

sub work_job {
    my ($class, $job) = @_;
    my $ret = $job->arg * $job->arg;
    # sleep 1;
    return "$ret (pid $$)";
}

package HogeHoge::Worker::Gearman::Sqrt;
use strict;
use warnings;

sub work_job {
    my ($class, $job) = @_;
    my $ret = sqrt($job->arg);
    sleep 1;
    return $ret;
}

package main;
use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use lib 'lib';
use Dainamo;
use Dainamo::Profile::Gearman;

my $dainamo = Dainamo->new(
    max_workers => 10,
    log_level => 'info',
);

$dainamo->add_profile(
    profile => Dainamo::Profile::Gearman->new(
        name => 'hogehoge',
        max_requests_per_child => 10,
        weight => 1.0,
        config => +{
            job_servers => ['127.0.0.1'],
            workers => [qw( HogeHoge::Worker::Gearman::Double HogeHoge::Worker::Gearman::Sqrt )],
        },
    ),
);

sub {
    $dainamo;
}->();
