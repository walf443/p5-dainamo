親プロセスのプロセスIDを知りたい
---------------------------------

dainamo-topを使うのがてっとり早いでしょう ::

    $ dainamo-top
    pid     type    max_workers     status
    11166   master  10      waiting

typeがmasterとなっているプロセスのpid列にある数字がpidです。

親プロセスに対してSIGNALを送ってやることでdainamoの管理している全プロセスを終了したりできます。 ::

    $ kill -TERM 11166 # 今やっているジョブをおわったら終了
    $ kill -INT  11166 # なるべくすぐ終了

