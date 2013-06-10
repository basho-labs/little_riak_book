# Conceitos

Quando eu conheci o Riak pela primeira vez, achei alguns conceitos assustadores.
Mas entender essas teorias, fez-me apreciar as dificuldades na área de base de
dados distribuídas, e as soluções elegantes fornecidas pelo Riak.

Acredite-me, caro leitor, quando eu sugiro que pensar de forma distribuída é
estranho. Quando encontrei pela primeira vez o Riak, eu não estava preparado
para alguns de seus conceitos mais *estranhos*. Os nossos cérebros simplesmente
não foram feitos para pensar de uma forma distribuída e assíncrona. Richard
Dawkins criou o termo *Mundo Médio*---a terra que os seres humanos encontram
todos os dias, que existe entre os extremos do tamanho muito pequeno dos quarks,
até à imensidão do universo. Nós não consideramos estes extremos com clareza,
porque nós não os encontramos todos os dias, assim como computações e
armazenamentos distribuídos. Assim, nós criamos modelos e ferramentas para
trazer o ato físico de recursos paralelos espalhados, para os nossos termos mais
síncronos. O Riak esforça-se para simplificar as partes duras, mas não finge que
eles não existem. Assim como você nunca pode esperar ser um programador
excecional sem qualquer conhecimento de memória ou de gestão de CPU, também não
pode nunca desenvolver com segurança grupos de máquinas altamente disponíveis
sem um alto conhecimento de alguns conceitos subjacentes.

<!-- image: caveman confused by a bunch of atoms -->

## O Panorama

A existência de bases de dados como Riak é o culminar de duas coisas: tecnologia
acessível que estimulou diferentes requisitos para os dados, e as lacunas no
mercado de gestão de dados.

<!-- image: landscape -->

Primeiro, como temos visto melhorias tecnológicas constantes, juntamente com
reduções de custo, grandes quantidades de poder de computação e armazenamento
estão agora ao alcance de quase todos. Junto com o nosso mundo cada vez mais
interligado por causa da web e pelos computadores cada vez mais pequenos e
baratos (como os smartphones), isto causou um crescimento exponencial de dados,
e uma exigência de maior previsibilidade e velocidade pelos utilizadores mais
tecnológicos. Em suma, mais dados estão a ser criados pelos utilizadores,
enquanto mais dados estão a ser geridos nos servidores.

Em segundo lugar, os sistemas de gestão de base de dados relacionais (RDBMS)
especializaram-se ao longo dos anos num conjunto de cenários como *business
intelligence*. Eles também foram tecnicamente ajustados para tirar o maior
desempenho possível de grandes servidores individuais, como como otimização de
acessos a disco, mesmo enquanto servidores uso pessoal (ou virtualizado) a
custos acessíveis se tornavam cada vez mais atraentes para crescer e escalar
horizontalmente. Enquanto as falhas das base de dados relacionas se tornavam
aparentes, implementações personalizadas surgiram em resposta a problemas
específicos não originalmente previstos pela BDs relacionais.

Estas novas base de dados são informalmente chamadas de NoSQL, e o Riak faz
parte desse grupo.

<h3>Modelos das Base de Dados</h3>

As base de dados atuais podem de um modo geral ser categorizadas no modo em que
representam os dados. Embora eu esteja a apresentar 5 principais tipos (os
últimos 4 são considerados modelos NoSQL), estas linhas não são sempre claras
---pode-se usar algumas BD chave/valor como BD de documentos, ou pode-se usar
uma BD relacional para armazenar apenas dados do tipo chave/valor.

<aside id="joins" class="sidebar"><h3>Nota rápido sobre JOINs</h3>

Ao contrário de base de dados relacionais, mas semelhante BDs de documentos e
colunares, não se pode ser *JOIN* de objetos no Riak. O código do cliente é o
responsável por ler e resolver os valores. Isto também pode ser feito atrás do
MapReduce.

A capacidade de facilmente realizar *JOINs* em servidores físicos diferentes, é
um compromisso que separa as base de dados de um só nó como as BDs relacionais e
de grafos, de sistemas *naturalmente particionáveis* como as BDs de documentos,
colunares e de chave/valor.

Esta limitação muda a forma como se modela os dados. A normalização relacional
(organização de dados para reduzir a redundância) existe para sistemas que podem
facilmente realizar *JOINs* por cada pedido. No entanto, a capacidade de se
espalhar os dados em diversos nós requer uma abordagem desnormalizada, onde
alguns dados são duplicados, e os valores calculados podem ser armazenados por
razões de desempenho. </aside>

<!-- image: icons for each of these types -->

  1. **Relacional**. Base de dados tradicionais normalmente usam SQL para
  modelar e consultar os dados. Eles são úteis para os dados que podem ser
  armazenados num esquema altamente estruturado, mas ainda assim requerem uma
  alta flexibilidade na sua consulta. Crescer uma base de dados relacional
  (RDBMS), tradicionalmente ocorre pela compra de hardware mais poderoso
  (crescimento vertical).

    Exemplos: *PostgreSQL*, *MySQL*, *Oracle*

  2. **Grafo**. Estas BDs existem para dados altamente interligados. Eles
  notabilizam-se na modelação de relações complexas entre nós, e muitas
  implementações conseguem lidar com biliões de nós e relacionamentos (ou
  arestas e vértices). Eu tendo a incluir *triplestores* (triplos) e * BDs de
  objetos* como variantes especializadas.

    Exemplos: *Neo4j*, *Graphbase*, *InfiniteGraph*

  3. **Documento**. BDs de documentos modelam valores hierárquicos chamados
  documentos, representados em formatos como JSON ou XML, e não impõem um
  esquema no documento. Eles normalmente suportam a distribuição por vários
  servidores (crescimento horizontal).

    Exemplos: *CouchDB*, *MongoDB*, *Couchbase*

  4. **Colunar**. Popularizado pelo 
  [BigTable da Google](http://research.google.com/archive/bigtable.html), esta
  forma de base   de dados existe para escalar para vários servidores, e agrupa os
  dados em   famílias de colunas. Valores de uma coluna podem ser individualmente
  modificados e geridos, apesar das famílias serem definidas com antecedência,
  ao contrário de esquemas em RDBMS.

    Exemplos: *HBase*, *Cassandra*, *BigTable*

  5. **Chave/Valor**. BDs de Chave/Valor, ou CV, são conceptualmente como
  tabelas de hash, onde os valores são armazenados e acedidos por uma chave
  imutável. Elas variam desde um único servidor como o *Memcached* usado para
  caches de alta velocidade, até sistemas de múltiplos datacenters distribuídos
  como o *Riak Enterprise*.

    Exemplos: *Riak*, *Redis*, *Voldemort*

## Componentes do Riak

Riak é uma BD chave/valor(CV), construído a partir do zero para distribuir com
segurança os dados num cluster de servidores físicos, chamados de nós. Um
cluster do Riak também é conhecido como um anel (vamos falar sobre o porquê mais
tarde).

<!--Por agora, vamos apenas considerar os conceitos necessários para ser um
utilizador do Riak, e mais tarde a sua operação e manutenção.-->

O Riak funciona de forma semelhante a uma tabela de hash muito grande.
Dependendo do seu conhecimento, pode também chamá-lo de mapa, ou dicionário, ou
objeto. Mas a ideia é a mesma: você armazena um valor com uma chave imutável, e
recupera-o mais tarde.

<h3>Chave e o Valor</h3>

![Uma Chave é um Endereço](../assets/decor/addresses.png)

Chave/valor é a construção mais básica de todas na informática. Você pode pensar
numa chave como um endereço de uma casa, como por exemplo, a casa do Bob com a
chave única de 5124, enquanto o valor seria talvez Bob (e o seu material).

```javascript
hashtable["5124"] = "Bob"
```
E recuparar o Bob é tão fácil como ir à sua casa.

```javascript
bob = hashtable["5124"]
```

Vamos dizer que o pobre do Bob morre, e a Claire se move para esta casa. O
endereço permanece o mesmo, mas o conteúdo mudou.

```javascript
hashtable["5124"] = "Claire"
```
Pedidos subsequentes por `5124` vão devolver agora `Claire`.

<h3>Buckets (Baldes)</h3>

<!-- image: address streets metaphore -->

Os endereços em "Riakville" são mais do que o número de casa, são também o
endereço de uma rua. Podia haver outro 5124 noutra rua, então a forma de podemos
garantir a exclusividade de um endereço é exigindo ambos, como por exemplo
*5124, Rua Principal*.

Buckets* (ou baldes) são análogos a nomes de ruas: eles fornecem 
[espaço de nomes](http://pt.wikipedia.org/wiki/Espa%C3%A7o_de_nomes) para que 
chaves com nomes iguais possam coexistir em buckets diferentes.

Por exemplo, enquanto Alice pode viver na *5122, Rua Principal*, pode haver um
posto de gasolina na *5122, Rua Boavista*.

```javascript
principal["5122"] = "Alice"
boavista["5122"] = "Gas"
```

Claro que você podia ter chamado as chaves de `principal_5122` e
`boavista_5122`, mas os *buckets* permitem a nomeação de chaves mais limpa, e
tem outros benefícios adicionais que vão ser descritos mais tarde.

Os *buckets* são tão úteis no Riak que todas as chaves têm que pertencer a um,
ou seja, não há um espaço de chaves global. A verdadeira definição de uma chave
única no Riak é na verdade `bucket/chave`.

Por conveniência, nós chamamos um par *bucket/chave + valor* de *objeto*,
poupando-nos a verbosidade de "chave X no balde Y e seu valor".

## Replicação e Partições

A distribuição de dados entre diversos nós é como Riak é capaz de permanecer
altamente disponível, enquanto também é tolerante a interrupções e partições de
rede. O Riak combina dois estilos de distribuição para atingir isto:
[replicação](http://pt.wikipedia.org/wiki/Replica%C3%A7%C3%A3o_de_dados) e
[partições](http://pt.wikipedia.org/wiki/Parti%C3%A7%C3%A3o).

<h3>Replicação</h3>

**Replicação** é o ato de duplicar os dados em vários servidores. O Riak replica
 os dados por defeito.

A vantagem óbvia da replicação é que se um nó falhar, os nós que contêm os dados
replicados permanecem disponíveis para atender os pedidos. Em outras palavras, o
sistema permanece *disponível*.

Por exemplo, imagine que tem uma lista de chaves de países, cujos valores são as
capitais dos mesmos. Se tudo o que você fizer for replicar os dados para dois
servidores, você teria duas base de dados duplicadas.

![Replicação](../assets/replication.svg)

A desvantagem com a replicação é que está-se a multiplicar a quantidade de
armazenamento necessário para cada réplica. Há também alguma sobrecarga da rede
com esta abordagem, já que os valores também devem ser encaminhados para todos
os nós replicados, nas escritas. Mas há um problema mais insidioso com esta
abordagem, que será coberto em breve.

<h3>Partições</h3>

Uma **partição** é como dividimos um conjunto de chaves em servidores físicos
separados. Ao invés de valores duplicados, nós escolhemos um servidor para
hospedar exclusivamente um intervalo de chaves, e os outros servidores para
hospedar os restantes intervalos não sobrepostos.

Com o particionamento, a nossa capacidade total pode aumentar sem qualquer
hardware grande e caro, apenas muitos pequenos servidores genéricos. Se
decidirmos particionar a nossa base de dados em 1000 partes em 1000 nós,
reduzimos (hipoteticamente) a quantidade de trabalho que qualquer servidor deve
fazer para um milésimo (1/1000).

Por exemplo, se nós particionarmos os nossos países em dois servidores, podemos
colocar todos os países que começam com letras A-N no nó A, e O-Z no nó B.

![Partições](../assets/partitions.svg)

Há um pouco de sobrecarga usando esta abordagem. Tem que haver um serviço que
saiba a correspondência entre os intervalos de chaves e os respetivos nós. Uma
aplicação que solicite o valor da chave `Portugal` deverá ser encaminhado para o
nó A e não para o nó B.

Há também outro aspeto negativo. Ao contrário de replicação, o simples
particionamento dos dados realmente *diminui* o uptime. Se um nó falhar, essa
partição de dados inteira ficará indisponível. É por isso que o Riak usa tanto a
replicação como o particionamento.


<h3>Replicação + Partições</h3>

Já que as partições nos permitem aumentar a capacidade, e a replicação melhora a
disponibilidade, o Riak combina-os. Particiona e replica os dados em vários nós.

Onde no nosso exemplo anterior particionamos os dados em 2 nós, podemos agora
replicar cada uma dessas partições em mais 2 nós, para um total de 4.

O nosso número de servidores aumentou, mas também a nossa capacidade e
confiabilidade. Se estiver a projetar um sistema horizontalmente escalável
usando particionamento de dados, deve lidar com a replicação dessas partições.

A equipa do Riak sugere um mínimo de 5 nós para um cluster do Riak, a replicar
para 3 nós (esta configuração é chamada de `n_val`, para o número de *nós* na
qual deve replicar cada objeto).

![Replicação Partições](../assets/replpart.svg)

<!-- If the odds of a node going down on any day is 1%, then the odds of any
server going down each day when you have 100 of them is about (1-(0.99^100))
63%. For sufficiently large systems, servers going down are no longer edge-
cases. They become regular cases that must be planned for, and designed into
your system. -->


<h3>O Anel</h3>

O Riak usa a técnica de *hash consistente*, para mapear objetos num círculo (o
anel).

As partições do Riak não são mapeadas alfabeticamente (como usamos nos exemplos
acima), mas, em vez disso, uma partição mapeia uma gama de hashes de chaves
(função SHA-1 aplicada a uma chave). O valor máximo da hash é de 2^160, e é
dividido num número específico de partições---64 partições por defeito (a
configuração no Riak é feita com `ring_creation_size`).

Vamos ver o que tudo isto significa. Se você tem a chave `favorite`, aplicar o
algoritmo SHA-1 daria `7501 7a36 ec07 fd4c 377a 0d2a 0114 00ab 193e 61db` em
hexadecimal. Com 64 partições, cada uma tem 1/64 dos `2^160` valores possíveis,
sendo a gama da primeira partição de 0 a `2^154-1`, o segundo intervalo é de
`2^154` a `2*2^154-1`, e assim por diante, até à última partição de `63*2^154-1`
a `2^160-1`.

<!-- V=lists:sum([lists:nth(X, H)*math:pow(16, X-1) || X <- lists:seq(1,string:len(H))]) / 64. -->
<!-- V / 2.28359630832954E46. // 2.2.. is 2^154 -->

Não vamos fazer agora as contas, mas confie em mim quando eu digo que `favorite`
cai dentro da partição 3.

Se visualizarmos as nossas 64 partições como um anel, `favorite` recai aqui:

![Anel do Riak](../assets/ring0.svg)

"Ele não acabou de dizer que o Riak sugere um mínimo de 5 nós? Como podemos
"colocar 64 partições em 5 nós?. Na verdade, cada nó tem mais que uma partição,
"cada uma gerida por um *vnode*, ou *nó virtual*.

Contamos à volta do anel de vnodes por ordem, atribuindo a cada nó o próximo
vnode disponível, até que todos os vnodes sejam contabilizados. Logo a
partição/vnode 1 seria do Nó A, o vnode 2 seria do Nó B, até ao vnode 5 que
seria do Nó E. De seguida continuamos a dar ao Nó A o vnode 6, ao Nó B o vnode
7, e assim por diante, até que os vnodes estejam esgotados, resultando nesta
lista:

* A = [1,6,11,16,21,26,31,36,41,46,51,56,61]
* B = [2,7,12,17,22,27,32,37,42,47,52,57,62]
* C = [3,8,13,18,23,28,33,38,43,48,53,58,63]
* D = [4,9,14,19,24,29,34,39,44,49,54,59,64]
* E = [5,10,15,20,25,30,35,40,45,50,55,60]

Até agora temos particionado o anel, mas e a replicação? Quando escrevemos um
novo valor no Riak, o resultado vai ser replicado num determinado número de nós,
definidos pela configuração chamada `n_val. No nosso cluster de 5 nós, por
defeito este valor é 3.

Então, quando nós escrevemos o nosso objeto `favorite` para o vnode 3, este será
replicado para os vnodes 4 e 5. Isto coloca o objeto nos nós físicos C, D e E.
Quando a escrita estiver completa, mesmo que o nó C falhe, o valor ainda está
disponível nos outros 2 nós. Este é o segredo da alta disponibilidade do Riak.

Podemos visualizar o anel com seus vnodes, nós, e onde o `favorite` vai ficar:

![Anel do Riak](../assets/ring1.svg)

O anel não é mais do que um array circular de partições de hash. É também um
sistema de metadados que é copiado para cada nó. Cada nó está ciente de todos os
outros nós do cluster, que nós contêm que vnodes, e outros dados do sistema.

Com esta informação, os acessos a dados podem contactar qualquer nó. Ele vai
horizontalmente ler os dados aos nós certos, retornando o resultado.

## Compromissos na prática

Até agora cobrimos as partes boas do particionamento e da replicação: altamente
disponível para responder a pedidos e capacidade de escalar em hardware
genérico. Com os claros benefícios de escalar horizontalmente, então porque não
é mais comum?

<h3>Teorema de CAP</h3>

As bases de dados RDBMS clássicas têm *escritas coerentes*. Quando uma escrita
está confirmada, leituras subsequentes têm a garantia de devolver o valor mais
recente. Se eu guardar o valor `pizza fria` para a minha chave `favorito`, cada
leitura no futuro devolverá consistentemente `pizza fria` até que esse valor
mude.

<!-- The very act of placing our data in multiple servers carries some inherent risk. -->

Mas quando os valores são distribuídos, a *coerência* não pode ser garantida. A
meio da replicação de um objeto, dois servidores podem ter resultados
diferentes. Quando atualizamos a chave `favorito` para `pizza fria` num nó,
outro nó pode ter o valor mais antigo `pizza`, por causa de um problema de
conectividade de rede. Se pedir o valor da chave `favorito` em cada lado da
divisão da rede, dois resultados diferentes poderão ser devolvidos---a base de
dados está incoerente.

Se a coerência não deve ser comprometida, podemos então sacrificar alguma
disponibilidade. Podemos, por exemplo, decidir bloquear a inteira base de dados
durante uma escrita, e simplesmente rejeitar todos os pedidos até que o valor
seja replicado para todos os nós relevantes. Os clientes têm de esperar enquanto
os seus resultados obtêm um estado coerente (garantia que todas as réplicas
retornam o mesmo valor) ou a escrita falha se os nós tiverem problemas de
comunicação. Para muitos cenários de alto tráfego de leituras/escritas, como um
carrinho de compras online, onde até mesmo pequenos atrasos fará com que as
pessoas comprarem noutro lugar, isso não é um compromisso aceitável.

Este compromisso é conhecido como o teorema de CAP, de Eric Brewer. O teorema
afirma informalmente que você pode ter um sistema com C (coerência), A
(disponibilidade), ou P (tolerante a partições), mas só pode escolher dois dos
três. Assumindo que o seu sistema é distribuído, você vai ser tolerante a
partições, o que significa que a sua rede pode tolerar a perda de pacotes. Se
uma partição de rede ocorre entre nós, os servidores continuam a correr.

<!-- A fourth concept not covered by the CAP theorem, latency, is especially important here. -->

<aside class="sidebar"><h3>Não exatamente C</h3>

Estritamente falando, o Riak tem um compromisso ajustável entre latência e
disponibilidade, em vez de coerência e disponibilidade. Acelerando o Riak ao
manter os valores e R e W baixos, vai aumentar a probabilidade de haver dados
temporariamente incoerentes (alta disponibilidade). Pelo contrário, manter esses
valores de R e W altos, vai melhorar a probabilidade de encontrar leituras mais
recentes (mas ainda não é bem coerência forte); no entanto, vai atrasar um pouco
o Riak e fazer com que seja mais provável um pedido (leitura ou escrita) falhe
(em casos de partições).

Atualmente, nenhuma configuração pode fazer do Riak verdadeiramente CP no caso
geral, mas opções para alguns casos especiais estão a ser pesquisados.

</aside>

<h3>N/R/W</h3>

Uma pergunta o teorema de CAP exige reposta num sistema distribuído é: desisto
de coerência forte, ou desisto de disponibilidade máxima? Se um pedido chega,
posso rejeitar outros pedidos até que se possa garantir a coerência entre os
nós? Ou aceitar todos os pedidos a todo o custo, com a ressalva de que a base de
dados pode-se tornar incoerente?

A solução do Riak é baseada abordagem original do Dynamo da Amazon: um sistema
AP *ajustável*. Ele tira vantagem do fato de que, embora o teorema de CAP seja
verdade, você pode escolher que tipo de compromissos está disposto a fazer. O
Riak é altamente disponível para aceitar pedidos, com a capacidade de ajustar o
seu nível de disponibilidade (aproximando-se, mas nunca alcançando, coerência
forte).

O Riak permite que você escolha quantos nós devem replicar um objeto, e em
quantos nós devem ser escritos ou lidos por pedido. Estes valores são
configurações com o nome de `n_val` (o número de nós para replicar), `r` (o
número de nós lidos antes de responder), e `w` (o número de nós escritos antes
do pedido ser considerado bem sucedido).

Um exercício mental pode ajudar a esclarecer as coisas.

![NRW](../assets/nrw.svg)


<h4>N</h4>

Com o nosso cluster de 5 nós, ter um `n_val=3` significa que os valores
inevitavelmente serão replicados para 3 nós, como já discutimos anteriormente.
Este é o *valor N*. Você pode definir outras configurações com o valor do
`n_val`, usando o atalho `all`.

<h4>W</h4>

Mas você pode não querer esperar para que todos os nós sejam escritos antes de
retornar. Você pode optar por escrever para todos os 3 (`w=3` ou `w=all`), o que
significa que esses valores são mais propensos a ficarem coerentes, ou optar por
escrever apenas para 1 nó (`w=1`), e permitir que o restantes 2 nós escrevam de
forma assíncrona, mas ao mesmo tempo retornam uma resposta mais rápida. Este é o
*valor W*.

Em outras palavras, definindo `w=all` ajudaria a garantir que seu sistema seria
mais provável de ser coerente, à custa de esperar mais tempo, e com
possibilidade das escritas falharem se menos de 3 nós estiverem disponíveis (ou
seja, mais de metade dos seus servidores estão em baixo).

No entanto, uma escrita que falhe não é necessariamente uma falha. O cliente
pode receber uma mensagem de erro, mas a escrita tipicamente terá sucedido num
número de nós menor que *W*. Inevitavelmente, esta escrita vai ser propagada
para todas os nós que guardam essa chave.

<h4>R</h4>

As leituras têm os mesmo compromissos . Para garantir que tem o valor mais
recente, você pode ler todos os 3 nós que contêm o objeto (`r=all`). Mesmo que
apenas 1 dos 3 nós tenha o valor mais recente, podemos comparar os valores de
todos os nós uns com os outros e escolher o mais recente, garantindo assim
alguma coerência. Lembre-se de quando mencionei que as bases de dados RDBMS têm
*escritas coerentes*? Isto é quase como *leituras coerentes*. No entanto, assim
como no caso do `w=all`, uma leitura irá falhar se menos de 3 nós estejam
disponíveis para serem lidos. Finalmente, se você só quer ler rapidamente
qualquer valor, a configuração `r=1` tem baixa latência, e provavelmente é
coerente se `w=all`.

Em termos gerais, os valores N/R/W são a maneira do Riak permitir que você
troque menor coerência para mais disponibilidade.


<h3>Vetores Versão</h3>

Se acompanhou até agora, eu só tenho mais um conceito novo para lhe explicar.
Escrevi anteriormente que com `r=all`, nós podemos "comparar os valores de todos
os nós uns com os outros e escolher o mais recente." Mas como realmente sabemos
qual é o último valor, ou valor correto? É aqui que os *vetores versão* (ou
*vclocks*) entram em jogo.

Os vetores versão medem uma sequência de eventos, assim como um relógio normal.
Mas uma vez que não se pode razoavelmente manter os relógios de dezenas,
centenas, ou milhares de servidores em sincronia (sem hardware realmente
exótico, como relógios atómicos geo-sincronizados, ou capacidades quânticas), em
vez disso, mantemos uma atualizada história de eventos.

Vamos usar o nosso exemplo `favorito` novamente, mas desta vez temos 3 pessoas a
tentar chegar a um consenso sobre a sua comida favorita: Aaron, Britney, e
Carrie. Vamos acompanhar o valor que cada um escolheu e o seu respetivo vclock.

(Para ilustrar os vetores versão, vamos fazer um pouco de batota. Por defeito, o
(Riak já não usa informação dos clientes nos vetores versão. Em troca, usa
(informação do servidor que coordenou essa escrita. No entanto, o conceito é o
(mesmo. Vamos também ignorar os tempos reais que estão também guardados em cada
(vetor versão.)

Quando o Aaron define o objeto `favorito` para `pizza`, um vetor versão poderia
conter o seu nome e o número de atualizações por ele realizadas.

```yaml
vclock: {Aaron: 1}
value:  pizza
```

Entretanto a Britney chega e lê o objeto `favorito`, mas decide atualizar de
`pizza` para `pizza fria`. Ao utilizar vclocks, ela deve fornecer o vclock
devolvido na leitura que fez anteriormente e que quer atualizar. É assim que o
Riak pode ajudar a garantir que você está a atualizar um valor que já existia, e
que não está apenas a inserir o seu próprio valor (sem ler o que já existia).

```yaml
vclock: {Aaron: 1, Britney: 1}
value:  pizza fria
```

Ao mesmo tempo que a Britney, a Carrie decide que a pizza foi uma escolha
terrível, e tentou alterar o valor para `lasanha`.

```yaml
vclock: {Aaron: 1, Carrie: 1}
value:  lasanha
```

Isto representa um problema, porque agora existem dois vetores versão em jogo
que divergem do original `{Aaron: 1}`. Se configurado assim, o Riak vai
armazenar os dois valores e os dois vclocks.

Mais tarde no dia, a Britney verifica novamente, mas desta vez ela vê os dois
valores conflituosos (os chamados *siblings*, que vamos discutir no próximo
capítulo), com dois vclocks.

```yaml
vclock: {Aaron: 1, Britney: 1}
value:  pizza fria
---
vclock: {Aaron: 1, Carrie: 1}
value:  lasanha
```

Fica claro que uma decisão deve ser tomada. Talvez a Britney saiba que o pedido
original do Aaron foi `pizza` e portanto duas pessoas concordaram com pizza,
então ela resolve o conflito ao escolher novamente pizza e atualizando o vetor
versão.

```yaml
vclock: {Aaron: 1, Britney: 2}
value:  pizza
```

Agora estamos de volta ao caso simples, onde pedindo o valor do `favorito` só
vai devolver o valor acordado `pizza`.

Se você é um programador, pode perceber que isso não é muito diferente de um
sistema de controle de versões, como o **git**, onde ramos conflituosos podem
exigir resolução manual.

<!--Como foi mencionado antes, nós ignoramos os tempos reais para este exemplo,
mas eles têm o seu propósito se o Riak não estiver configurado para guardar
valores em conflito. Neste caso, é apenas guardado o valor mais recente,
determinado pelo tempo real que cada um dos vclocks guarda internamente. -->

<h3>O Riak e o ACID</h3>

<aside id="acid" class="sidebar"><h3>O Relacional Distribuído não está Isento</h3>

Então porque não instalar uma comum base de dados relacional. Afinal, o MySQL
tem a capacidade de formar clusters, e é ACID (<em>Atómico</em>, *Coerente*,
*Isolável* e *Durável*), certo? Sim e não.

Um nó por si só é ACID, mas o cluster inteiro não consegue ser, a não ser que
haja perda de disponibilidade, e muitas vezes ainda pior, um aumento na
latência. Quando se escreve para um nó primário e existe replicação para um nó
secundário, pode ocorrer uma partição de rede. Para continuar disponível, o nó
secundário vai deixar de estar sincronizado (mas será inevitavelmente coerente).

Ou toda a transação pode falhar, fazendo com que todo o cluster fique
indisponível. Mesmo as base de dados ACID não podem escapar ao teorema de CAP.
</aside>

Ao contrário de base de dados de um único nó como o Neo4j ou o PostgreSQL, o
Riak não suporta transações *ACID*. O bloqueio de vários servidores ia matar a
disponibilidade das escritas, e igualmente preocupante, ia aumentar a latência.
Enquanto as transações ACID prometem *Atomicidade*, *Coerência*, *Isolamento* e
*Durabilidade*---o Riak e as outras base de dados NoSQL seguem o *BASE*, ou
*Basicamente Disponível*, *Estado Transiente* e *Inevitavelmente Coerente*.

A sigla BASE foi concebida como um sinónimo para as metas das bases de dados não
transacionais/ACID como o Riak. É dado como aceite que a disponibilidade nunca é
perfeita (basicamente disponível), todos os dados estão em mudança (estado
transiente), e que a coerência é geralmente inatingível (inevitavelmente
coerente).

Esteja com atenção se alguém promete transações ACID distribuídas e altamente
disponíveis---é normalmente acompanhado por algum adjetivo diminutivo ou
ressalva como *só em operações por linha*, ou *só em transações no nó*, o que
basicamente significa *não transacional* nos termos que normalmente usamos para
defini-lo. Não estou a dizer que é impossível, mas é certamente assunto para
estudar com atenção.

À medida que o número dos seus servidores cresce---especialmente quando se
À começa a introduzir vários datacenters---a possibilidade de partições e falhas
À de nós aumenta drasticamente. O meu melhor conselho é planear antecipadamente.

## Conclusão

O Riak é projetado para conferir uma série de benefícios no mundo real, mas
igualmente, para lidar com as consequências de deter tal poder. Hashes
consistentes e vnodes são uma solução elegante para escalar horizontalmente
entre servidores. N/R/W permite ao utilizador brincar com o teorema CAP e
ajustá-lo de acordo com o seu caso. E os vetores versão permitem dar mais um
passo para atingir a verdadeira coerência, permitindo gerir os conflitos que
ocorrerem quando existe elevada carga nos servidores.

Nós vamos cobrir outros conceitos técnicos, conforme necessário, como o
protocolo de *gossip*, o *hinted handoff* e o *read-repair* (leitura-reparação).

De seguida, vamos ver o Riak do ponto de vista do utilizador. Vamos ver
pesquisas, tirar proveito de *hooks* de escritas e examinar as opções
alternativas de consulta como indexação secundária, pesquisa e MapReduce.
