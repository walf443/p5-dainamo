ログをローテートさせたい
=========================

log_fileへパイプから始まる文字列を渡すと、外部コマンドへ投げることができるので、それとcronologを組みあわせるのが楽かもしれません。 ::

    use strict;
    use warnings;
    use Dainamo;

    my $dainamo = Dainamo->new(
        log_path => qq{| /usr/sbin/cronolog "/var/log/dainamo/%Y%m%d.log"},
    );

    # ...

