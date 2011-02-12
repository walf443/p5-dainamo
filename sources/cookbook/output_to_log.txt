デバッグに有用な情報をWorkerからログへ出力したい
-------------------------------------------------

本番環境等でも、ログにある程度情報を出力しておくと、何かトラブルが起きたときに有用なことがあります。

DainamoではLogの出力は全てLog::Minimalのデフォルトの出力方法を置きかえることで実現しているので、単にLog::Minimalを使って出力してやればよいです。 ::

    package YourApp::Worker::Gearman::Foo;
    use strict;
    use warnings;
    use Log::Minimal qw(debugf ddf);

    sub work_job {
        my ($class, $job) = @_;

        debugf("$class " . ddf($job));
        # do worker ...
    }

    1;

debugfの出力は、log_levelがinfo以上だと出力されないため、オプションで指定してやるとよいです。 ::

    $ dainamo -c /etc/dainamo.pl --log_level=DEBUG --log_path=STDERR

なお、warnによる出力は、warnfを経由するように置きかえられているため、特に意識する必要はないです。

