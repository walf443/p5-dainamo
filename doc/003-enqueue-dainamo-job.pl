use strict;
use warnings;
use Gearman::Client;
use Log::Minimal;
use Parallel::ForkManager;

my $client = Gearman::Client->new;
$client->job_servers('127.0.0.1');

my @jobs = qw(HogeHoge::Worker::Gearman::Double HogeHoge::Worker::Gearman::Sqrt);

my $pm = Parallel::ForkManager->new(10);

for (0..10000) {
    my $pid = $pm->start and next;
    my $job = $jobs[rand(@jobs)];
    my $ret = $client->do_task($job, rand(1000));
    warnf $$ret;
    $pm->finish;
}

$pm->wait_all_children;

