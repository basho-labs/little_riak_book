# Administradores

<!-- What Riak is famous for is its simplicity to operate and stability at increasing scales. -->

De certa forma, o Riak é absolutamente banal no seu papel como a mais fácil base
de dados NoSQL para administrar. Quer mais servidores? É só adicioná-los. Um
cabo de rede é cortado às duas da manhã? Lide com isso apenas quando acordar. No
entanto, compreender esta parte integrante de sua stack de serviços é ainda
importante, apesar da confiabilidade do Riak.

Já falamos dos principais conceitos do Riak e como o usar. Mas há mais do que
isso numa base de dados. Há detalhes que deve saber se pretende administrar um
cluster a correr o Riak.

## Clusters

Até agora falamos apenas conceptualmente em "clusters" e no "anel". O que eles
na verdade significam e quais são as suas implicações na prática para os
administradores e programadores do Riak?

Um *cluster* do Riak é um conjunto de servidores que partilham um Anel em comum.

<h3>O Anel</h3>

O *Anel* no Riak representa duas coisas na verdade.

Primeiro, o Anel representa as partições de hash consistente (cada partição é um
vnode). A série de partições é tratada como um círculo, de 0 a 2^160-1 até 0
novamente. (Se está com dúvidas, sim, isto significa que estamos limitados a
2^160-1 vnodes, que é um limite de `1.46 x 10^48` nós. Para referência, existem
`1.92 x 10^49` [átomos de silício na Terra](http://education.jlab.org/qa/mathatom_05.html).)

Quando falamos de replicação, o valor de N define para quantos nós um objeto é
replicado. O Riak espalha o objeto por nós adjacentes no anel, começando com o
nó primário e seguindo os seus vizinhos no anel (sempre no mesmo sentido).
Se atingir o último vnode do anel, dá a volta e começa no vnode na posição 0.

Em segundo lugar, o Anel é também usado como um atalho para descrever o estado
do anel de hashes circular que falamos agora. Este Anel (*Anel de Estado*) é uma
estrutura de dados que é transferida entre nós, para que cada um saiba o estado
do Anel. Que nós gerem quais vnodes? Esse é a pergunta que um nó tem que saber
quando recebe um pedido de leitura ou escrita para uma chave que não tem
localmente, e portanto consulta o estado do Anel para saber qual o nó para onde
reencaminhar o pedido.

Obviamente, este estado do anel tem que ser sincronizado entre todos os nós. Se
um nó for removido ou adicionado, os outros nós precisam de ajustar o Anel, de
maneira a balancear novamente os vnodes entre todos eles. O estado do Anel é
passado pela rede através de um protocolo de *gossip*.

<h3>Gossip</h3>

O protocolo de *gossip* é a maneira do Riak manter todos os nós sincronizados
com o estado atual do anel. Se houver mudanças de nós que pertencem ao anel,
isto é propagado pela rede. Periodicamente, os nós comunicam o seu estado para
um nó vizinho ao acaso.

A propagação de mudanças no anel é uma operação assíncrona e portanto pode levar
alguns minutos, dependendo do tamanho do anel.

<!-- Transferências não começam enquanto a fase de gossip não acabar. -->

Atualmente, não é possível mudar o número de vnodes num cluster. Isto significa
que se deve ter um vaga ideia de quanto o cluster pode crescer em tamanho.
Embora uma instalação básica começa por defeito com 64 vnodes, se planeia no
futuro ter mais que 6 servidores (nós) , então deve aumentar esse número para
256 ou 1024.

O número de vnodes deve ser uma potência de 2 (ex. 64, 256, 1024).

<aside class="sidebar"><h3>Redimensionamento Dinâmico do Anel</h3>

Foi feito um grande esforço para ser possível mudar o número de vnodes,
portanto, quando estiver a ler isto é possível que o Riak já suporte esta
funcionalidade por defeito.

</aside>

<h3>Como a Replicação usa o Anel</h3>

Mesmo que não seja um programador, é recomendado prestar atenção a este exemplo
de um Anel. Também é importante lembrar que as partições são geridas por vnodes,
e por vezes trocamos os nomes, mas vamos tentar ser mais precisos daqui para a
frente.

Vamos começar com o Riak configurado para 8 partições, configurado a partir da
propriedade `ring_creation_size` no ficheiro `etc/app.config` (veremos isto
melhor mais tarde).

```bash
 %% Riak Core config
 {riak_core, [
               ...
               {ring_creation_size, 8},
```

Neste exemplo, temos um total de 4 nós do Riak a correr em `A@10.0.1.1`,
`B@10.0.1.2`, `C@10.0.1.3`, e `D@10.0.1.4`, cada uma com 2 partições (e portanto
vnodes).

O Riak tem o incrível e perigoso comando `attach`, que abre uma consola Erlang
com ligação direta a um nó do Riak, com acesso a todos os seus módulos.

A função `riak_core_ring:chash(Ring) extraí o número total de partições (8), com
um número representando o começo da partição (uma fração do número `2^160`) e o
nome que representa essa partição.

```bash
$ bin/riak attach
(A@10.0.1.1)1> {ok,Ring} = riak_core_ring_manager:get_my_ring().
(A@10.0.1.1)2> riak_core_ring:chash(Ring).
{8,
 [{0,'A@10.0.1.1'},
  {182687704666362864775460604089535377456991567872, 'B@10.0.1.2'},
  {365375409332725729550921208179070754913983135744, 'C@10.0.1.3'},
  {548063113999088594326381812268606132370974703616, 'D@10.0.1.4'},
  {730750818665451459101842416358141509827966271488, 'A@10.0.1.1'},
  {913438523331814323877303020447676887284957839360, 'B@10.0.1.2'},
  {1096126227998177188652763624537212264741949407232, 'C@10.0.1.3'},
  {1278813932664540053428224228626747642198940975104, 'D@10.0.1.4'}]}
```

Para descobrir qual a partição o objeto bucket/chave `comida/favorita` está
guardado, por exemplo, executamos `riak_core_util:chash_key({<<"comida">>,
<<"favorita">>})` e obtemos um array de números estranhos de 160 bits do Erlang,
a que nós chamamos de `DocIdx` (índice do documento).

Só para ilustrar que o valor binário do Erlang é um número real, a próxima linha
transforma-o num formato mais legível, semelhante aos números das partições do
Anel.

```bash
(A@10.0.1.1)3> DocIdx = riak_core_util:chash_key({<<"comida">>,<<"favorita">>}).
<<80,250,1,193,88,87,95,235,103,144,152,2,21,102,201,9,156,102,128,3>>

(A@10.0.1.1)4> <<I:160/integer>> = DocIdx.
462294600869748304160752958594990128818752487427
```

Com este número `DocIdx`, podemos ordenar as partições, começando com o primeiro
número maior que o `DocIdx`. As restantes partições estão ordenadas por ordem
numérica, até chegar a zero; aí damos a volta e continuamos a lista até acabar.

```bash
(A@10.0.1.1)5> Preflist = riak_core_ring:preflist(DocIdx, Ring).
[{548063113999088594326381812268606132370974703616, 'D@10.0.1.4'},
 {730750818665451459101842416358141509827966271488, 'A@10.0.1.1'},
 {913438523331814323877303020447676887284957839360, 'B@10.0.1.2'},
 {1096126227998177188652763624537212264741949407232, 'C@10.0.1.3'},
 {1278813932664540053428224228626747642198940975104, 'D@10.0.1.4'},
 {0,'A@10.0.1.1'},
 {182687704666362864775460604089535377456991567872, 'B@10.0.1.2'},
 {365375409332725729550921208179070754913983135744, 'C@10.0.1.3'}]
```

Mas o que tem isto a ver com replicação? Com a lista acima, nós simplesmente
replicámos uma escrita pela lista N vezes. Se tivermos o N=3, então o objeto
`comida/favorita` vai ser escrito para a partição `5480631...` (o número está
reduzido) do nó `D@10.0.1.1`, para a partição `7307508...` do nó `A@10.0.1.1` e
para a partição `9134385...` do nó `B@10.0.1.2`.

Se alguma coisa acontecer a algum nó, como uma separação da rede (a chamada
partição "P" no teorema de CAP), os restantes nós ativos na lista tornam-se
candidatos a guardar esses dados.

Então, se o nó coordenador da escrita não conseguir contactar o nó `A@10.0.1.1`
para escrever na partição `7307508...`, vai tentar escrever na partição
`7307508...` do nó `C@10.0.1.3` como recurso (é o próximo nó na lista *preflist*
a seguir às 3 partições primárias).

A maneira como o Anel está estruturado permite ao Riak garantir que os dados
serão sempre escritos para o número apropriado de nós, mesmo em casos onde um ou
mais nós físicos estão indisponíveis. Ele faz isto simplesmente tentando o
próximo nó disponível na lista.

<h3>Hinted Handoff</h3>

Quando um nó vai abaixo, os dados são replicados para um nó de backup. Isto não
é permanente; o Riak vai periodicamente examinar se cada vnode reside no nó
físico correto e devolve esse vnode para a partição correta quando possível.

Enquanto o nó temporário não se conseguir ligar ao nó primário, ele vai aceitar
pedidos de leituras e escritas em lugar dos outros nós indisponíveis.

O *Hinted handoff* não só ajuda o Riak a ter alta disponibilidade, mas também
facilita a migração de nós físicos que são adicionados e removidos do Anel.

## Gerindo um Cluster

Agora que temos uma ideia geral do que é o Riak, os seus conceitos, como os
utilizadores podem fazer pedidos e como funciona a replicação, está na hora de
montar um cluster. É tão fácil que nem me dei ao trabalho de o explicar até
agora.

<h3>Instalação</h3>

A documentação do Riak tem toda a informação necessária para a
[instalação](http://docs.basho.com/riak/latest/tutorials/installation/) por
sistema operativo.

1. Instalar o Erlang;
2. Arranjar o Riak atráves de um gestor de pacotes (`apt-get, homebrew, etc.), ou compile o código fonte;
3. Executar `riak start`

Instale o Riak em quatro ou cinco nós---sendo cinco o mínimo recomendado em
produção. Menos que cinco nós serve para testes ou se estiver a desenvolver
código.

<h3>Linha de comandos</h3>

A maioria das operações do Riak podem ser feitas através da linha de comandos.
Vamos-nos focar em dois comandos: `riak` e `riak-admin`.

<h4>riak</h4>

Ao escrever simplesmente o comando `riak`, dará uma lista de uso, embora não
muito descritiva.

```bash
Usage: riak {start|stop|restart|reboot|ping|console|\
             attach|chkconfig|escript|version|getpid}
```

A maioria destes comandos são auto descritivos, a partir do momento que se sabe
o seu significado. `start` e `stop` são simples. `restart` significa parar o nó
que está a correr e reiniciá-lo dentro da mesma VM (máquina virtual) do Erlang,
enquanto que `reboot` vai deitar a VM do Erlang toda a baixo e reiniciar tudo.

Pode imprimir a versão atual usando `version`. `ping` vai devolver `pong` se o
servidor estiver em bom estado, senão receber `pang` ou um simples `Node *X* not
responding to pings` se o nó nem estiver a correr.

`chkconfig` é útil se quiser ter a certeza que o seu `etc/app.config` não está
estragado. Eu mencionei o `attach` brevemente acima, quando olhamos com detalhe
para o Anel; ele liga uma consola a um nó Riak onde consegue executar código
Erlang do Riak. `escript` é parecido com o `attach`, exceto que se passa um
ficheiro de script com comandos que deseja correr automaticamente.

<!--
If you want to build this on a single dev machine, here is a truncated guide.
Download the Riak source code, then run the following:
make deps
make devrel
for i in {1..5}; do dev/dev$i/bin/riak start; done
for i in {1..5}; do dev/dev$i/bin/riak ping; done
for i in {2..5}; do dev/dev$i/bin/riak-admin cluster join A@10.0.1.1; done
dev/dev1/bin/riak-admin cluster plan
dev/dev1/bin/riak-admin cluster commit
You should now have a 5 node cluster running locally.
-->

<h4>riak-admin</h4>

O comando `riak-admin` é o comando que irá usar mais vezes. É aqui que irá
juntar nós ao Anel, diagnosticar problemas, verificar estados e fazer backups.

```bash
Usage: riak-admin { cluster | join | leave | backup | restore | test |
                    reip | js-reload | erl-reload | wait-for-service |
                    ringready | transfers | force-remove | down |
                    cluster-info | member-status | ring-status | 
                    vnode-status | diag | status | transfer-limit |
                    top [-interval N] [-sort reductions|memory|msg_q]
                    [-lines N] }
```

Muitos destes comandos estão desatualizados, e muitos não fazem sentido sem um
cluster; mas podemos olhar agora para alguns.

`status` devolve uma lista de informações sobre o cluster. É em grande parte a
mesma informação que se obtém através de `/stats` via HTTP, embora não sejam
exatamente iguais.

```bash
$ riak-admin status
1-minute stats for 'A@10.0.1.1'
-------------------------------------------
vnode_gets : 0
vnode_gets_total : 2
vnode_puts : 0
vnode_puts_total : 1
vnode_index_reads : 0
vnode_index_reads_total : 0
vnode_index_writes : 0
vnode_index_writes_total : 0
vnode_index_writes_postings : 0
vnode_index_writes_postings_total : 0
vnode_index_deletes : 0
...
```

Ficheiros de Javascript ou Erlang adicionados ao Riak (como fizemos no capítulo
anterior) não são imediatamente usáveis pelos nós até que estes recebam o
comando `js-reload` ou `erl-reload`.


O `riak-admin` também providencia o comando `test` para executar ciclos de
escritas e leituras para o nó, que é útil para testar a capacidade de uma
biblioteca cliente de ligar e do nó escrever.

Finalmente, o `top` verifica em tempo real os detalhes de um nó Erlang.
Diferentes processos têm ids de processo diferentes (Pids), usam memória de
forma variável, guardam mensagens até certo ponto (MsgQ), e por aí em diante.
Isto é útil para diferentes diagnósticos, e especialmente útil se conhecer
Erlang ou precisar de ajuda de membros do Riak ou da Basho.

![Top](../assets/top.png)

<h3>Criar um Cluster</h3>

Com vários nós solitários a correr---assumindo que eles estão ligados e
conseguem comunicar---criar um cluster é a parte mais fácil.

Executar o comando `cluster` vai devolver uma lista descritiva de comandos:

```bash
$ riak-admin cluster
The following commands stage changes to cluster membership. These commands
do not take effect immediately. After staging a set of changes, the staged
plan must be committed to take effect:

   join <node>                    Join node to the cluster containing <node>
   leave                          Have this node leave the cluster and shutdown
   leave <node>                   Have <node> leave the cluster and shutdown

   force-remove <node>            Remove <node> from the cluster without
                                  first handing off data. Designed for
                                  crashed, unrecoverable nodes

   replace <node1> <node2>        Have <node1> transfer all data to <node2>,
                                  and then leave the cluster and shutdown

   force-replace <node1> <node2>  Reassign all partitions owned by <node1> to
                                  <node2> without first handing off data, and
                                  remove <node1> from the cluster.

Staging commands:
   plan                           Display the staged changes to the cluster
   commit                         Commit the staged changes
   clear                          Clear the staged changes
```

Para criar um cluster, tem que se executar o comando `join` para juntar o nó
atual a outro nó (qualquer um serve). Para retirar um nó, executa-se `leave` ou
`force-remove`, enquanto que trocar um nó antigo por um novo executa-se `replace`
ou `force-replace`.

O comando `leave` é uma boa maneira de retirar um nó. No entanto, não temos
sempre essa escolha;  Se um nó explodir, não é preciso a sua autorização parar o
retirar do cluster, basta marcá-lo como `down` (em baixo).

Mas antes de nos preocupar-mos com a remoção de nós, vamos primeiro adicioná-los.

```bash
$ riak-admin cluster join A@10.0.1.1
Success: staged join request for 'B@10.0.1.2' to 'A@10.0.1.1'
$ riak-admin cluster join A@10.0.1.1
Success: staged join request for 'C@10.0.1.3' to 'A@10.0.1.1'
```

Quando todas as mudanças estiverem preparadas, deve então rever o plano
(`plan`). Irá ver todos os detalhes dos nós que se irão juntar ao cluster, e
como irá ficar o cluster no fim de cada transição, incluindo o `member-status`,
e como se precederá a transferência entre nós.

Abaixo encontra-se um simples plano, mas há casos onde o Riak requer multiplas
transições para satisfazer todos os pedidos, como adicionar e remover nós numa
transição.

```bash
$ riak-admin cluster plan
=============================== Staged Changes ==============
Action         Nodes(s)
-------------------------------------------------------------
join           'B@10.0.1.2'
join           'C@10.0.1.3'
-------------------------------------------------------------


NOTE: Applying these changes will result in 1 cluster transition

#############################################################
                         After cluster transition 1/1
#############################################################

================================= Membership ================
Status     Ring    Pending    Node
-------------------------------------------------------------
valid     100.0%     34.4%    'A@10.0.1.1'
valid       0.0%     32.8%    'B@10.0.1.2'
valid       0.0%     32.8%    'C@10.0.1.3'
-------------------------------------------------------------
Valid:3 / Leaving:0 / Exiting:0 / Joining:0 / Down:0

WARNING: Not all replicas will be on distinct nodes

Transfers resulting from cluster changes: 42
  21 transfers from 'A@10.0.1.1' to 'C@10.0.1.3'
  21 transfers from 'A@10.0.1.1' to 'B@10.0.1.2'
```

Fazer alterações nos membros do cluster pode ser bastante intensivos nos
recursos do sistema, portanto o Riak por defeito apenas faz 2 transferências de
cada vez. Pode-se alterar este valor na propriedade `transfer-limit` usando o
comando `riak-admin`, mas tenha a atenção que quanto maior este valor, maior é o
seu impacto nas operações desse nó.

Neste ponto, se encontrar algum erro no plano, tem a hipótese de usar o comando
`clear` para limpar tudo e tentar novamente. Quando estiver pronto, use o
`commit` para o cluster executar o plano.

```bash
$ dev1/bin/riak-admin cluster commit
Cluster changes committed
```

Sem dados, adicionar um nó ao cluster é extremamente rápido. No entanto, se
tiver muitos dados para transferir para o novo nó, pode levar algum tempo até
esse novo nó estar disponível.

<h3>Opções de estado</h3>

Para ver o estado de um nó que está a ser adicionado, pode-se usar o comando
`wait-for-service`. Vai imprimir o estado do serviço e pára quando o nó estiver
online. Neste exemplo, vamos ver o estado do serviço `riak_kv`:

```bash
$ riak-admin wait-for-service riak_kv C@10.0.1.3
riak_kv is not up: []
riak_kv is not up: []
riak_kv is up
```

Pode obter a lista de serviços disponíveis com o comando `services`.

Pode também ver se todo o anel está pronto com `ringready`. Se os nós não
concordarem com o estado do anel, vai imprimir `FALSE`, ou caso contrário
`TRUE`.

```bash
$ riak-admin ringready
TRUE All nodes agree on the ring ['A@10.0.1.1','B@10.0.1.2',
                                  'C@10.0.1.3']
```

Para uma vista completa do estado dos nós no anel, pode usar o `member-status`.

```bash
$ riak-admin member-status
================================= Membership ================
Status     Ring    Pending    Node
-------------------------------------------------------------
valid      34.4%      --      'A@10.0.1.1'
valid      32.8%      --      'B@10.0.1.2'
valid      32.8%      --      'C@10.0.1.3'
-------------------------------------------------------------
Valid:3 / Leaving:0 / Exiting:0 / Joining:0 / Down:0
```

E para mais detalhes de nós inacessíveis, tente `ring-status`. Também devolve
informação sobre o `ringready` e o `transfers`. Abaixo desliguei o nó C para
mostrar como se parece.

```bash
$ riak-admin ring-status
================================== Claimant =================
Claimant:  'A@10.0.1.1'
Status:     up
Ring Ready: true

============================== Ownership Handoff ============
Owner:      dev1 at 127.0.0.1
Next Owner: dev2 at 127.0.0.1

Index: 182687704666362864775460604089535377456991567872
  Waiting on: []
  Complete:   [riak_kv_vnode,riak_pipe_vnode]
...

============================== Unreachable Nodes ============
The following nodes are unreachable: ['C@10.0.1.3']

WARNING: The cluster state will not converge until all nodes
are up. Once the above nodes come back online, convergence
will continue. If the outages are long-term or permanent, you
can either mark the nodes as down (riak-admin down NODE) or
forcibly remove the nodes from the cluster (riak-admin
force-remove NODE) to allow the remaining nodes to settle.
```

Se a informação acima sobre os vnodes não chega, pode listar o estado de cada
vnode por nó com `vnode-status`. Vai mostrar cada vnode pelo seu número de
partição, dar qualquer detalhe do seu estado, e número de chaves de cada vnode.
Finalmente, verá qual o tipo de servidor de cada vnode---algo que veremos na
próxima secção.


```bash
$ riak-admin vnode-status
Vnode status information
-------------------------------------------

VNode: 0
Backend: riak_kv_bitcask_backend
Status:
[{key_count,0},{status,[]}]

VNode: 91343852333181432387730302044767688728495783936
Backend: riak_kv_bitcask_backend
Status:
[{key_count,0},{status,[]}]

VNode: 182687704666362864775460604089535377456991567872
Backend: riak_kv_bitcask_backend
Status:
[{key_count,0},{status,[]}]

VNode: 274031556999544297163190906134303066185487351808
Backend: riak_kv_bitcask_backend
Status:
[{key_count,0},{status,[]}]

VNode: 365375409332725729550921208179070754913983135744
Backend: riak_kv_bitcask_backend
Status:
[{key_count,0},{status,[]}]
...
```

Alguns comandos não foram abordados estão desatualizados em favor do seu
equivalente com `cluster` (`join`, `leave`, etc), ou estão marcados para futura
remoção.

O último comando é o comando `diag`, que tira partido da instalação do
[Riaknostic](http://riaknostic.basho.com/) para lhe dar mais ferramentas de
diagnóstico.

Eu sei que isto foi muita informação para digerir de uma vez. Mas explicar
comando normalmente é assim mesmo. Há imensos detalhes por de trás do comando
`riak-admin`, demais para os cobrir a todos neste livro. Mas aconselho a brincar
com os comandos na instalação.


## How Riak is Built

It's difficult to label Riak as a single project. It's probably more correct to think of
Riak as the center of gravity for a whole system of projects. As we've covered
before, Riak is built on Erlang, but that's not the whole story. It's more correct
to say Riak is fundamentally Erlang, with some pluggable native C code components
(like leveldb), Java (Yokozuna), and even JavaScript (for MapReduce or commit hooks).

![Tech Stack](../assets/riak-stack.svg)

The way Riak stacks technologies is a good thing to keep in mind, in order to make
sense of how to configure it properly.

<h3>Erlang</h3>

![Tech Stack Erlang](../assets/riak-stack-erlang.svg)

When you fire up a Riak node, it also starts up an Erlang VM (virtual machine) to run
and manage Riak's processes. These include vnodes, process messages, gossips, resource
management and more. The Erlang operating system process is found as a `beam.smp`
command with many, many arguments.

These arguments are configured through the `etc/vm.args` file. There are a few
settings you should pay special attention to.

```bash
$ ps -o command | grep beam
/riak/erts-5.9.1/bin/beam.smp \
-K true \
-A 64 \
-W w -- \
-root /riak \
-progname riak -- \
-home /Users/ericredmond -- \
-boot /riak/releases/1.2.1/riak \
-embedded \
-config /riak/etc/app.config \
-pa ./lib/basho-patches \
-name A@10.0.1.1 \
-setcookie testing123 -- \
console
```

The `name` setting is the name of the current Riak node. Every node in your cluster
needs a different name. It should have the IP address or dns name of the server
this node runs on, and optionally a different prefix---though some people just like
to name it *riak* for simplicity (eg: `riak@node15.myhost`).

The `setcookie` parameter is a setting for Erlang to perform inter-process
communication (IPC) across nodes. Every node in the cluster must have the same
cookie name. I recommend you change the name from `riak` to something a little
less likely to accidentally conflict, like `hihohihoitsofftoworkwego`.

My `vm.args` starts with this:

```bash
## Name of the riak node
-name A@10.0.1.1

## Cookie for distributed erlang.  All nodes in the
## same cluster should use the same cookie or they
## will not be able to communicate.
-setcookie testing123
```

Continuing down the `vm.args` file are more Erlang settings, some environment
variables that are set up for the process (prefixed by `-env`), followed by
some optional SSL encryption settings.

<h3>riak_core</h3>

![Tech Stack Core](../assets/riak-stack-core.svg)

If any single component deserves the title of "Riak proper", it would
be *Riak Core*. Core shares responsibility with projects built atop it
for managing the partitioned keyspace, launching and supervising
vnodes, preference list building, hinted handoff, and things that
aren't related specifically to client interfaces, handling requests,
or storage.

Riak Core, like any project, has some hard-coded values (for example, how
protocol buffer messages are encoded in binary). However, many values
can be modified to fit your use case. The majority of this configuration
occurs under `app.config`. This file is Erlang code, so commented lines
begin with a `%` character.

The `riak_core` configuration section allows you to change the options in
this project. This handles basic settings, like files/directories where
values are stored or to be written to, the number of partitions/vnodes
in the cluster (`ring_creation_size`), and several port options.

```bash
%% Riak Core config
{riak_core, [
    %% Default location of ringstate
    {ring_state_dir, "./data/ring"},

    %% Default ring creation size.  Make sure it is a power of 2,
    %% e.g. 16, 32, 64, 128, 256, 512 etc
    %{ring_creation_size, 64},

    %% http is a list of IP addresses and TCP ports that
    %% the Riak HTTP interface will bind.
    {http, [ {"127.0.0.1", 8098 } ]},

    %% https is a list of IP addresses and TCP ports that
    %% the Riak HTTPS interface will bind.
    %{https, [{ "127.0.0.1", 8098 }]},

    %% Default cert and key locations for https can be
    %% overridden with the ssl config variable, for example:
    %{ssl, [
    %       {certfile, "./etc/cert.pem"},
    %       {keyfile, "./etc/key.pem"}
    %      ]},

    %% riak handoff_port is the TCP port that Riak uses for
    %% intra-cluster data handoff.
    {handoff_port, 8099 },

    %% To encrypt riak_core intra-cluster data handoff traffic,
    %% uncomment the following line and edit its path to an
    %% appropriate certfile and keyfile.  (This example uses a
    %% single file with both items concatenated together.)
    {handoff_ssl_options, [{certfile, "/tmp/erlserver.pem"}]},

    %% Platform-specific installation paths
    {platform_bin_dir, "./bin"},
    {platform_data_dir, "./data"},
    {platform_etc_dir, "./etc"},
    {platform_lib_dir, "./lib"},
    {platform_log_dir, "./log"}
]},
```

<h3>riak_kv</h3>

![Tech Stack KV](../assets/riak-stack-kv.svg)

Riak KV is a key/value implementation of Riak Core. This is where the
magic happens, such as handling requests and coordinating them for
redundancy and read repair. It's what makes Riak a KV store rather
than something else like a Cassandra-style columnar data store.

<!-- When configuring KV, you may scratch your head about about when a setting belongs
under `riak_kv` versus `riak_core`. For example, if `http` is under core, why
is raw_name under riak. -->

HTTP access to KV defaults to the `/riak` path as we've seen in examples
throughout the book. This prefix is editable via `raw_name`. Many of the
other KV settings are concerned with backward compatibility  modes,
backend settings, MapReduce, and JavaScript integration.

```bash
%% Riak KV config
{riak_kv, [
  %% raw_name is the first part of all URLS used by the
  %% Riak raw HTTP interface. See riak_web.erl and
  %% raw_http_resource.erl for details.
  {raw_name, "riak"},

  %% http_url_encoding determines how Riak treats URL
  %% encoded buckets, keys, and links over the REST API.
  %% When set to 'on'. Riak always decodes encoded values
  %% sent as URLs and Headers.
  %% Otherwise, Riak defaults to compatibility mode where
  %% links are decoded, but buckets and keys are not. The
  %% compatibility mode will be removed in a future release.
  {http_url_encoding, on},

  %% Switch to vnode-based vclocks rather than client ids.
  %% This significantly reduces the number of vclock entries.
  {vnode_vclocks, true},

  %% This option toggles compatibility of keylisting with
  %% 1.0 and earlier versions.  Once a rolling upgrade to
  %% a version > 1.0 is completed for a cluster, this
  %% should be set to true for better control of memory
  %% usage during key listing operations
  {listkeys_backpressure, true},
  ...
]},
```

<h3>riak_pipe</h3>

![Tech Stack Pipe](../assets/riak-stack-pipe.svg)

Riak Pipe is an input/output messaging system that forms the basis of Riak's
MapReduce. This was not always the case, and MR used to be a dedicated
implementation, hence some legacy options. Like the ability to alter the KV
path, you can also change HTTP from `/mapred` to a custom path.

```bash
%% Riak KV config
{riak_kv, [
  %% mapred_name is URL used to submit map/reduce requests
  %% to Riak.
  {mapred_name, "mapred"},

  %% mapred_system indicates which version of the MapReduce
  %% system should be used: 'pipe' means riak_pipe will
  %% power MapReduce queries, while 'legacy' means that luke
  %% will be used
  {mapred_system, pipe},

  %% mapred_2i_pipe indicates whether secondary-index
  %% MapReduce inputs are queued in parallel via their
  %% own pipe ('true'), or serially via a helper process
  %% ('false' or undefined).  Set to 'false' or leave
  %% undefined during a rolling upgrade from 1.0.
  {mapred_2i_pipe, true},

  %% directory used to store a transient queue for pending
  %% map tasks
  %% Only valid when mapred_system == legacy
  %% {mapred_queue_dir, "./data/mr_queue" },

  %% Number of items the mapper will fetch in one request.
  %% Larger values can impact read/write performance for
  %% non-MapReduce requests.
  %% Only valid when mapred_system == legacy
  %% {mapper_batch_size, 5},

  %% Number of objects held in the MapReduce cache. These
  %% will be ejected when the cache runs out of room or the
  %% bucket/key pair for that entry changes
  %% Only valid when mapred_system == legacy
  %% {map_cache_size, 10000},
  ...
]}
```

<h4>JavaScript</h4>

Riak KV's MapReduce implementation (under riak_kv, though implemented in Pipe) is the
primary user of the Spidermonkey JavaScript engine---the second user is
precommit hooks.

```bash
%% Riak KV config
{riak_kv, [
  ...
  %% Each of the following entries control how many
  %% Javascript virtual machines are available for
  %% executing map, reduce, pre- and post-commit
  %% hook functions.
  {map_js_vm_count, 8 },
  {reduce_js_vm_count, 6 },
  {hook_js_vm_count, 2 },

  %% js_max_vm_mem is the maximum amount of memory,
  %% in megabytes, allocated to the Javascript VMs.
  %% If unset, the default is 8MB.
  {js_max_vm_mem, 8},

  %% js_thread_stack is the maximum amount of thread
  %% stack, in megabyes, allocate to the Javascript VMs.
  %% If unset, the default is 16MB. NOTE: This is not
  %% the same as the C thread stack.
  {js_thread_stack, 16},

  %% js_source_dir should point to a directory containing Javascript
  %% source files which will be loaded by Riak when it initializes
  %% Javascript VMs.
  %{js_source_dir, "/tmp/js_source"},
  ...
]}
```

<h3>yokozuna</h3>

![Tech Stack Yokozuna](../assets/riak-stack-yokozuna.svg)

Yokozuna is the newest addition to the Riak ecosystem. It's an integration of
the distributed Solr search engine into Riak, and provides some extensions
for extracting, indexing, and tagging documents. The Solr server runs its
own HTTP interface, and though your Riak users should never have to access
it, you can choose which `solr_port` will be used.

```bash
%% Yokozuna Search
{yokozuna, [
  {solr_port, "8093"},
  {yz_dir, "./data/yz"}
]}
```

<h3>bitcask, eleveldb, memory, multi</h3>

![Tech Stack Backend](../assets/riak-stack-backend.svg)

Several modern databases have swappable backends, and Riak is no different in that
respect. Riak currently supports three different storage engines: *Bitcask*,
*eLevelDB*, and *Memory* --- and one hybrid called *Multi*.

Using a backend is simply a matter of setting the `storage_backend` with one of the following values.

- `riak_kv_bitcask_backend` - The catchall Riak backend. If you don't have
  a compelling reason to *not* use it, this is my suggestion.
- `riak_kv_eleveldb_backend` - A Riak-friendly backend which uses Google's
  leveldb. This is necessary if you have too many keys to fit into memory, or
  wish to use 2i.
- `riak_kv_memory_backend` - A main-memory backend, with time-to-live (TTL). Meant
  for transient data.
- `riak_kv_multi_backend` - Any of the above backends, chosen on a per-bucket
  basis.


```bash
%% Riak KV config
{riak_kv, [
  %% Storage_backend specifies the Erlang module defining
  %% the storage mechanism that will be used on this node.
  {storage_backend, riak_kv_memory_backend}
]},
```

Then, with the exception of Multi, each memory configuration is under one of
the following options.

```bash
%% Memory Config
{memory_backend, [
  {max_memory, 4096}, %% 4GB in megabytes
  {ttl, 86400}  %% 1 Day in seconds
]}

%% Bitcask Config
{bitcask, [
  {data_root, "./data/bitcask"},
  {open_timeout, 4}, %% Wait time to open a keydir (in seconds)
  {sync_strategy, {seconds, 60}}  %% Sync every 60 seconds
]},

%% eLevelDB Config
{eleveldb, [
  {data_root, "./data/leveldb"},
  {write_buffer_size_min, 31457280 }, %% 30 MB in bytes
  {write_buffer_size_max, 62914560}, %% 60 MB in bytes
  %% Maximum number of files open at once per partition
  {max_open_files, 20},
  %% 8MB default cache size per-partition
  {cache_size, 8388608}
]},
```

With the Multi backend, you can even choose different backends
for different buckets. This can make sense, as one bucket may hold
user information that you wish to index (use eleveldb), while another
bucket holds volatile session information that you may prefer to simply
remain resident (use memory).

```bash
%% Riak KV config
{riak_kv, [
  ...
  %% Storage_backend specifies the Erlang module defining
  %% the storage mechanism that will be used on this node.
  {storage_backend, riak_kv_multi_backend},

  %% Choose one of the names you defined below
  {multi_backend_default, <<"bitcask_multi">>},

  {multi_backend, [
    %% Heres where you set the individual backends
    {<<"bitcask_multi">>,  riak_kv_bitcask_backend, [
      %% bitcask configuration
      {config1, ConfigValue1},
      {config2, ConfigValue2}
    ]},
    {<<"memory_multi">>,   riak_kv_memory_backend, [
      %% memory configuration
      {max_memory, 8192}   %% 8GB
    ]}
  ]},
]},
```

You can put the `memory_multi` configured above to the `session_data` bucket
by just setting its `backend` property.

```bash
$ curl -XPUT http://riaknode:8098/riak/session_data \
  -H "Content-Type: application/json" \
  -d '{"props":{"backend":"memory_multi"}}'
```

<h3>riak_api</h3>

![Tech Stack API](../assets/riak-stack-api.svg)

So far, all of the components we've seen have been inside the Riak
house. The API is the front door. *In a perfect world*, the API would
manage two implementations: HTTP and Protocol buffers (PB), an
efficient binary protocol framework designed by Google.

But because they are not yet separated, only PB is configured under `riak_api`,
while HTTP still remains under KV.

In any case, Riak API represents the client facing aspect of Riak. Implementations
handle how data is encoded and transferred, and this project handles the services
for presenting those interfaces, managing connections, providing entry points.


```bash
%% Riak Client APIs config
{riak_api, [
  %% pb_backlog is the maximum length to which the queue
  %% of pending connections may grow. If set, it must be
  %% an integer >= 0. By default the value is 5. If you
  %% anticipate a huge number of connections being
  %% initialised *simultaneously*, set this number higher.
  %% {pb_backlog, 64},

  %% pb_ip is the IP address that the Riak Protocol
  %% Buffers interface will bind to.  If this is undefined,
  %% the interface will not run.
  {pb_ip,   "127.0.0.1" },

  %% pb_port is the TCP port that the Riak Protocol
  %% Buffers interface will bind to
  {pb_port, 8087 }
]},
```

<h3>Other projects</h3>

Other projects add depth to Riak but aren't strictly necessary. Two of
these projects are lager, for logging, and riak_sysmon, for
monitoring. Both have reasonable defaults and well-documented
settings.

* [https://github.com/basho/lager](https://github.com/basho/lager)
* [https://github.com/basho/riak_sysmon](https://github.com/basho/riak_sysmon)

```bash
%% Lager Config
{lager, [
  %% What handlers to install with what arguments
  %% If you wish to disable rotation, you can either set
  %% the size to 0 and the rotation time to "", or instead
  %% specify 2-tuple that only consists of {Logfile, Level}.
  {handlers, [
    {lager_file_backend, [
      {"./log/error.log", error, 10485760, "$D0", 5},
      {"./log/console.log", info, 10485760, "$D0", 5}
    ]}
  ]},

  %% Whether to write a crash log, and where.
  %% Commented/omitted/undefined means no crash logger.
  {crash_log, "./log/crash.log"},

  ...

  %% Whether to redirect error_logger messages into lager -
  %% defaults to true
  {error_logger_redirect, true}
]},
```

```bash
%% riak_sysmon config
{riak_sysmon, [
  %% To disable forwarding events of a particular type, set 0
  {process_limit, 30},
  {port_limit, 2},

  %% Finding reasonable limits for a given workload is a matter
  %% of experimentation.
  {gc_ms_limit, 100},
  {heap_word_limit, 40111000},

  %% Configure the following items to 'false' to disable logging
  %% of that event type.
  {busy_port, true},
  {busy_dist_port, true}
]},
```

<h3>Backward Incompatibility</h3>

Riak is a project in evolution. And as such, it has a lot of projects that have
been created, but over time are being replaced with newer versions. Obviously
this baggage can be confounding if you are just learning Riak---especially as
you run across deprecated configuration, or documentation.

- InnoDB - The MySQL engine once supported by Riak, but now deprecated.
- Luke - The legacy MapReduce implementation replaced by Riak Pipe.
- Search - The search implementation replaced by Yokozuna.
- Merge Index - The backend created for the legacy Riak Search.
- SASL - A logging engine improved by Lager.


## Tools

<h3>Riaknostic</h3>

You may recall that we skipped the `diag` command while looking through
`riak-admin`, but it's time to circle back around.

[Riaknostic](http://http://riaknostic.basho.com/) is a diagnostic tool
for Riak, meant to run a suite of checks against an installation to
discover potential problems. If it finds any, it also recommends
potential resolutions.

Riaknostic exists separately from the core project but as of Riak 1.3
is included and installed with the standard database packages.

```bash
$ riak-admin diag --list
Available diagnostic checks:

  disk                 Data directory permissions and atime
  dumps                Find crash dumps
  memory_use           Measure memory usage
  nodes_connected      Cluster node liveness
  ring_membership      Cluster membership validity
  ring_preflists       Check ring satisfies n_val
  ring_size            Ring size valid
  search               Check whether search is enabled on all nodes
```

I'm a bit concerned that my disk might be slow, so I ran the `disk` diagnostic.

```bash
$ riak-admin diag disk
21:52:47.353 [notice] Data directory /riak/data/bitcask is\
not mounted with 'noatime'. Please remount its disk with the\
'noatime' flag to improve performance.
```

Riaknostic returns an analysis and suggestion for improvement. Had my disk
configuration been ok, the command would have returned nothing.


<h3>Riak Control</h3>

The last tool we'll look at is the aptly named
[Riak Control](http://docs.basho.com/riak/latest/references/appendices/Riak-Control/).
It's a web application for managing Riak clusters, watching, and drilling down
into the details of your nodes to get a comprehensive view of the system. That's the
idea, anyway. It's forever a work in progress, and it does not yet have parity with
all of the command-line tools we've looked at. However, it's great for quick
checkups and routing configuration changes.

Riak Control is shipped with Riak as of version 1.1, but turned off by
default. You can enable it on one of your servers by editing
`app.config` and restarting the node.

If you're going to turn it on in production, do so carefully: you're
opening up your cluster to remote administration using a password that
sadly must be stored in plain text in the configuration file.

The first step is to enable SSL and HTTPS in the `riak_core` section
of `app.config`.  You can just uncomment these lines, set the `https`
port to a reasonable value like `8069`, and point the `certfile` and
`keyfile` to your SSL certificate. If you have an intermediate
authority, add the `cacertfile` too.

```bash
%% Riak Core config
{riak_core, [
    %% https is a list of IP addresses and TCP ports that
    %% the Riak HTTPS interface will bind.
    {https, [{ "127.0.0.1", 8069 }]},

    %% Default cert and key locations for https can be
    %% overridden with the ssl config variable, for example:
    {ssl, [
           {certfile, "./etc/cert.pem"},
           {keyfile, "./etc/key.pem"},
           {cacertfile, "./etc/cacert.pem"}
          ]},
```

Then, you'll have to `enable` Riak Control in your `app.config`, and add a user.
Note that the user password is plain text. Yeah it sucks, so be careful to not
open your Control web access to the rest of the world, or you risk giving away
the keys to the kingdom.

```bash
%% riak_control config
{riak_control, [
  %% Set to false to disable the admin panel.
  {enabled, true},

  %% Authentication style used for access to the admin
  %% panel. Valid styles are 'userlist' <TODO>.
  {auth, userlist},

  %% If auth is set to 'userlist' then this is the
  %% list of usernames and passwords for access to the
  %% admin panel.
  {userlist, [{"admin", "lovesecretsexgod"}
             ]},

  %% The admin panel is broken up into multiple
  %% components, each of which is enabled or disabled
  %% by one of these settings.
  {admin, true}
]}
```

With Control in place, restart your node and connect via a browser (note you're using
`https`) `https://localhost:8069/admin`. After you log in using the user you set, you
should see a snapshot page, which communicates the health of your cluster.

![Snapshot View](../assets/control-snapshot.png)

If something is wrong, you'll see a huge red "X" instead of the green check mark, along
with a list of what the trouble is.

From here you can drill down into a view the cluster's nodes, with details on memory usage,
partition distribution, and other status. You can also add and configure and these nodes.

![Cluster View](../assets/control-cluster.png)

There is more in line for Riak Control, like performing MapReduce queries, stats views,
graphs, and more coming down the pipe. It's not a universal toolkit quite yet,
but it has a phenomenal start.

<!-- ## Scaling Riak
Vertically (by adding bigger hardware), and Horizontally (by adding more nodes).
 -->

## Wrapup

Once you comprehend the basics of Riak, it's a simple thing to manage. If this seems like
a lot to swallow, take it from a long-time relational database guy (me), Riak is a
comparatively simple construct, especially when you factor in the complexity of
distributed systems in general. Riak manages much of the daily tasks an operator might
do themselves manually, such as sharding by keys, adding/removing nodes, rebalancing data,
supporting multiple backends, and allowing growth with unbalanced nodes.
And due to Riak's architecture, the best part of all is when a server goes down at night,
you can sleep (do you remember what that was?), and fix it in the morning.
