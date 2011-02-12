設定の一部を外部ファイルへ分離したい
---------------------------------------

Dainamo#load_profilesを使うと、一部のProfileを追加する処理を外部ファイルに分離できます。
例えば、開発では全てのworkerを同じサーバーで起動させたいが、本番ではIPによって読みこむworkerの種類を分離したい、といったときに便利でしょう。 ::

    use strict;
    use warnings;
    use Daianmo;

    my $dainamo = Daianmo->new();

    $dainamo->load_profiles("config/$ENV{APP_ENV}.pl");

    sub {
        $dainamo;
    }->();

読み込まれるファイル内では、以下のように記述し、必ずDainamo::ProfileGroupオブジェクトを評価してやってください。 ::

    use strict;
    use warnings;
    use Dainamo::ProfileGroup;

    my $group = Dainamo::ProfileGroup->new;
    $group->add_profile(
        profile => Dainamo::Profile::Gearman->new(
            name => 'hogehoge',
            weight => 1.0,
            config => +{
                job_servers => ['127.0.0.1'],
                workers => [qw( HogeHoge::Worker::Gearman::Hoge )],
            },
        ),
    );

    sub {
        $group;
    }->();



