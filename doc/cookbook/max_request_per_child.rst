どうもメモリがリークしているので、応急処置として一度実行したらworkerが死ぬようにしたい
-----------------------------------------------------------------------------------------

Profileを追加する際にオプションとしてmax_request_per_childを指定してやればよいです。

.. literalinclude:: ./max_request_per_child.pl
    :language: perl

max_request_per_child回実行したら、そのworkerはexitし、managerは次のworkerをforkします。

