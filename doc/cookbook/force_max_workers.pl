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
        force_max_workers => 2, # 外部サービスを叩くので同時接続数を制限する
        config => +{
            job_servers => ['127.0.0.1'],
            workers => [qw( HogeHoge::Worker::Gearman::Hoge )],
        },
    ),
);

sub {
    $dainamo;
}->();
