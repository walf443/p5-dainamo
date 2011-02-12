クイックスタート
================

dainamoを使ってできる例として、まずは簡単なGearmanのworkerを書いてみましょう。

まずは設定ファイルを用意します。

.. literalinclude:: 001-dainamo-conf.pl
    :language: perl

次のようにしてgearmandを起動します。 ::

    $ gearmand --daemon

次のようにしてdainamoを起動します。 ::

    $ dainamo -c 001-dainamo-conf.pl

終了するには、SIGINTあるいは、SIGTERMを親プロセスに対して送ってやればよいです。

daemonizeしていないので、基本的な端末であれば、<Ctrl+C>で終了できるでしょう。

次のようなスクリプトを作り、別端末から実行してやりましょう。

.. literalinclude:: 002-enqueue-dainamo-job.pl
    :language: perl

dainamoを起動している方の端末をみると、次のようなlogからworkerが動作したのが確認できるはずです。 ::

    [2011-02-11T16:59:14] [INFO] [30348] start HogeHoge::Worker::Gearman::Double at lib/Dainamo/Profile/Gearman.pm line 45
    [2011-02-11T16:59:14] [INFO] [30348] finish HogeHoge::Worker::Gearman::Double at lib/Dainamo/Profile/Gearman.pm line 51

せっかくなので、もっとたくさんのjobを実行させてみましょう。

.. literalinclude:: 003-enqueue-dainamo-job.pl
    :language: perl

ログをみていると、様々なjobが実行されていることがわかると思います。
dainamoの各プロセスの状態を見るにはdainamo-topコマンドが使えます。 ::

    $ dainamo-top
    pid     type    max_workers     status
    74220   master  10      waiting
    pid     type    profile_name    max_workers     status
    74222   manager Dainamo::Profile::Gearman[hogehoge]     10      waiting
    pid     type    profile_name    status
    76666   child   Dainamo::Profile::Gearman[hogehoge]     running
    76722   child   Dainamo::Profile::Gearman[hogehoge]     running
    76731   child   Dainamo::Profile::Gearman[hogehoge]     running
    76737   child   Dainamo::Profile::Gearman[hogehoge]     running
    76739   child   Dainamo::Profile::Gearman[hogehoge]     running
    76796   child   Dainamo::Profile::Gearman[hogehoge]     running
    76807   child   Dainamo::Profile::Gearman[hogehoge]     running
    76708   child   Dainamo::Profile::Gearman[hogehoge]     waiting
    76728   child   Dainamo::Profile::Gearman[hogehoge]     waiting
    76766   child   Dainamo::Profile::Gearman[hogehoge]     waiting


