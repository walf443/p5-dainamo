use strict;
use warnings;
use Gearman::Client;
use Log::Minimal;

my $client = Gearman::Client->new;
$client->job_servers('127.0.0.1');
my $ret = $client->do_task("HogeHoge::Worker::Gearman::Double", 3);
warnf $$ret;

