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
        max_requests_per_child => 1, # メモリリークが深刻なので応急処置としてなおるまで毎回終了させる
        weight => 1.0,
        config => +{
            job_servers => ['127.0.0.1'],
            workers => [qw( HogeHoge::Worker::Gearman::Hoge )],
        },
    ),
);

sub {
    $dainamo;
}->();
