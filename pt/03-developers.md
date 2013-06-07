# Programadores

<aside class="sidebar"><h3>Uma nota sobre o "Nó"</h3>
Vale a pena mencionar que eu uso a palavra "nó" muitas vezes. Realisticamente, isso significa um servidor físico/virtual, mas realmente, o Riak interessa-se por vnodes.

Quando se escreve para múltiplos vnodes , o Riak vai tentar difundir os valores para o maior número de servidores físicos possível. No entanto, isto não é garantido (por exemplo, se só tiver 4 nós físicos com o `n_val` por defeito igual a 3, vai haver alguns casos onde os dados serão copiados duas vezes para o mesmo servidor). É mais fácil pensar nos vnodes como instâncias do Riak, e é mais simples do que estar sempre qualificar "vnode". Se alguma coisa se aplicar especificamente a um vnode, eu dizê-lo-ei explicitamente.

</aside>

_Vamos adiar os detalhes da instalação do Riak para já. Se quiser acompanhar, é fácil começar ao seguir a [documentação de instalação](http://docs.basho.com/riak/latest/) no site (http://docs.basho.com). Se não, esta é uma secção perfeita para ler enquanto você está sentado no comboio sem Internet._

Configurar o Riak é muito fácil de fazer, uma vez entendidos alguns dos seus pormenores. É um BD chave/valor no sentido técnico (você associa valores com chaves, e recupera-os usando as mesmas chaves), mas oferece muito mais. Você pode escrever funções para executar antes ou depois de uma escrita, ou indexar dados para uma leitura rápida. O Riak uma pesquisa idêntica ao [SOLR](http://lucene.apache.org/solr/), que permite executar funções MapReduce para extrair e agregar dados num cluster enorme, num período de tempo relativamente curto. Vamos mostrar algumas das configurações específicas para buckets, que os administradores podem configurar.

## Pesquisa

<aside class="sidebar"><h3>Linguagens Suportadas</h3>

O Riak tem drivers oficiais para as seguintes linguagens:
Erlang, Java, PHP, Python, Ruby

Incluindo os drivers fornecidos pela comunidade, as linguagens suportadas são ainda mais numerosas: C/C++, Clojure, Common Lisp, Dart, Go, Groovy, Haskell, JavaScript (jquery and nodejs), Lisp Flavored Erlang, .NET, Perl, PHP, Play, Racket, Scala, Smalltalk

Há ainda dezenas de [funcionalidades específicas de variados projetos](http://docs.basho.com/riak/latest/references/Community-Developed-Libraries-and-Projects/).
</aside>

Já que o Riak é uma base de dados chave/valor, os comandos mais básicos são escrever e ler valores. Nós vamos usar a interface HTTP, através do *curl*, mas poderíamos facilmente usar Erlang, Ruby, Java ou qualquer outra linguagem suportada.

Os tipos básicos de pedidos sobre o Riak são: ler, escrever e eliminar valores. Estas ações estão relacionadas com métodos HTTP (PUT, GET, POST, DELETE).

```bash
PUT    /riak/bucket/chave
GET    /riak/bucket/chave
DELETE /riak/bucket/chave
```

<h4>PUT (Escrita)</h4>

O comando mais simples de escrita no Riak é fazer *PUT* de um valor. Isto exige uma chave, um valor e um bucket. Usando o *curl*, todos os métodos HTTP têm o prefixo `-X`. Colocar o valor `pizza` na chave `favorito` sobre o bucket `alimento` é feito assim:

```bash
curl -XPUT "http://localhost:8098/riak/alimento/favorito" \
  -H "Content-Type:text/plain" \
  -d "pizza"
```

Eu escrevi algumas coisas estranhas aqui. A flag `-d` denota que a próxima *string* vai ser o valor. Mantivemos as coisas simples com a string `pizza`, declarando-a como texto com o comando `-H 'Content-Type:text/plain'`. Isto define o tipo HTTP MIME deste valor como texto simples. Nós podíamos ter definido qualquer valor, seja XML ou JSON---até mesmo uma imagem ou um vídeo. O Riak não se interessa pelo tipo de dados que armazena, desde que o tamanho de cada objeto não seja muito maior que 4MB (um limite teórico, mas recomendável que não se ultrapasse).

<h4>GET (Leitura)</h4>

O próximo comando lê o valor `pizza` que está no par bucket/chave `alimento`/`favorito`.

```bash
curl -XGET "http://localhost:8098/riak/alimento/favorito"
pizza
```
Esta é a forma mais simples de leitura, devolvendo apenas o valor. O Riak contém muito mais informação, que você pode aceder se ler a resposta completa, incluindo o cabeçalho HTTP.

No `curl` você pode aceder a uma resposta completa usando a flag `-i`. Vamos executar novamente a leitura acima, acrescentando esta flag.

```bash
curl -i -XGET "http://localhost:8098/riak/alimento/favorito"
HTTP/1.1 200 OK
X-Riak-Vclock: a85hYGBgzGDKBVIcypz/fgaUHjmdwZTImMfKcN3h1Um+LAA=
Vary: Accept-Encoding
Server: MochiWeb/1.1 WebMachine/1.9.0 (someone had painted...
Link: </riak/food>; rel="up"
Last-Modified: Wed, 10 Oct 2012 18:56:23 GMT
ETag: "1yHn7L0XMEoMVXRGp4gOom"
Date: Thu, 11 Oct 2012 23:57:29 GMT
Content-Type: text/plain
Content-Length: 5

pizza
```
As caraterísticas do HTTP estão um pouco fora propósito deste pequeno livro, mas vamos olhar para alguns pormenores dignos de nota.

<h5>Códigos de Status HTTP</h5>

A primeira linha dá o código de resposta `200 OK` do HTTP versão 1.1. Você pode estar familiarizado com o código `404 Not Found` (não encontrado) em websites. Existem muitos tipos de [códigos de status HTTP](http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html), e a interface HTTP do Riak permanece fiel à sua intenção: **1xx Informativo**, **2xx Sucesso**, **3xx Requer nova ação**, **4xx Erro do Cliente**, **5xx Erro do Servidor**.

Diferentes ações podem devolver diferentes códigos de resposta/erro. A lista completa pode ser encontrada na [documentação oficial da API](http://docs.basho.com/riak/latest/references/apis/).

<h5>Tempos</h5>

Um bloco de cabeçalhos representa diferentes tempos sobre o objeto ou o pedido.

* **Last-Modified** - A última vez que o objeto foi modificado (criado ou atualizado).
* **ETag** - Uma *[tag de entidade](http://en.wikipedia.org/wiki/HTTP_ETag)* que pode ser usado para validação da cache por um cliente.
* **Data** - A data do pedido.
* **X-Riak-Vclock** - Um relógio lógico que vamos abordar detalhadamente mais à frente.

<h5>Conteúdo</h5>

Estes campos descrevem o corpo da mensagem HTTP (em termos Riak, é o *valor*).

* **Content-Type** - O tipo de valor, como `text/xml`.
* **Content-Length** - O tamanho, em bytes, do corpo da mensagem.

Outros cabeçalhos como `Link` serão cobertos mais tarde neste capítulo.

<h4>POST (Escrita)</h4>

Semelhante ao PUT, o POST vai escrever um valor. Mas com o POST a chave é opcional. Tudo que precisa é do nome do bucket, e a irá ser gerada uma chave por si.

Vamos adicionar um valor JSON para representar uma pessoa no bucket `pessoas`. O cabeçalho da resposta é o lugar onde um POST devolve a chave gerada para si.

```bash
curl -i -XPOST "http://localhost:8098/riak/pessoas" \
  -H "Content-Type:application/json" \
  -d "{"name":"aaron"}""
HTTP/1.1 201 Created
Vary: Accept-Encoding
Server: MochiWeb/1.1 WebMachine/1.9.2 (someone had painted...
Location: /riak/pessoas/DNQGJY0KtcHMirkidasA066yj5V
Date: Wed, 10 Oct 2012 17:55:22 GMT
Content-Type: application/json
Content-Length: 0
```

Você pode extrair essa chave do valor do `Location`. Tirando o facto de não ser bonita, esta chave é tratada exatamente como se tivesse definido a sua própria chave via PUT.

<h5>Body (Corpo da mensagem)</h5>

Você pode observar que nenhum corpo foi devolvido com a resposta. Para qualquer tipo de escrita, você pode adicionar o parâmetro `returnbody=true` para forçar devolução de um valor, juntamente com outros cabeçalhos relacionados com o valor, como o `X-Riak-Vclock` e `ETag`.

```bash
curl -i -XPOST "http://localhost:8098/riak/pessoas?returnbody=true" \
  -H "Content-Type:application/json" \
  -d '{"name":"billy"}'
HTTP/1.1 201 Created
X-Riak-Vclock: a85hYGBgzGDKBVIcypz/fgaUHjmdwZTImMfKkD3z10m+LAA=
Vary: Accept-Encoding
Server: MochiWeb/1.1 WebMachine/1.9.0 (someone had painted...
Location: /riak/pessoas/DnetI8GHiBK2yBFOEcj1EhHprss
Link: </riak/pessoas>; rel="up"
Last-Modified: Tue, 23 Oct 2012 04:30:35 GMT
ETag: "7DsE7SEqAtY12d8T1HMkWZ"
Date: Tue, 23 Oct 2012 04:30:35 GMT
Content-Type: application/json
Content-Length: 16

{"nome":"billy"}
```
Isto é verdade para PUTs e POSTs.

<h4>DELETE (Remoção)</h4>

A operação básica final é remoção de chaves, que é semelhante a obter um valor, mas usa-se o método DELETE em vez do GET para o `url`/`bucket`/`chave`.

```bash
curl -XDELETE "http://localhost:8098/riak/pessoas/DNQGJY0KtcHMirkidasA066yj5V"
```
Um objeto removido é marcado internamente no Riak como removido, ao escrever um marcador conhecido como *tombstone* (lápide). Por defeito, outro processo chamado de *reaper* (ceifador) mais tarde irá eliminar os objetos marcados no servidor.

Este detalhe normalmente não é importante, a não ser para entender duas coisas:

1. No Riak, uma  *remoção* é na verdade, uma *leitura* e uma *escrita*, e deve ser considerado como tal para calcular o rácio de leituras/escritas na sua aplicação.
2. Verificar a existência de uma chave não é suficiente para saber se um objeto existe. Pode-se estar a ler uma chave que já foi marcada como removida, e portanto, deve verificar se o objeto é um *tombstone*.

<h4>Listagens</h4>

Riak fornece dois tipos de listagens. A primeira listagem fornece uma lista de todos os *buckets* no cluster, enquanto que a segunda devolve uma lista de todas as *chaves* dentro de um bucket em específico. Ambas as ações são chamados da mesma forma, e vêm em duas variedades.

O seguinte código vai-nos dar todos os nossos buckets como um objeto JSON.

```bash
curl "http://localhost:8098/riak?buckets=true"
{"buckets":["alimentos"]}
```

E isso vai-nos dar todas as chaves dentro do bucket `alimentos`.

```bash
curl "http://localhost:8098/riak/alimentos?keys=true"
{
  ...
  "keys": [
    "favorito"
  ]
}
```

Se tivéssemos muitas chaves, isto pode claramente demorar muito tempo. Então, o Riak também oferece a capacidade de transmitir a sua lista de chaves. `keys=stream` irá manter a conexão aberta, devolvendo os resultados em blocos de arrays. Quando a lista acaba, ele vai fechar a conexão. Você pode ver os detalhes através do *curl* em modo verboso (`-v`) (grande parte dessa resposta foi simplificada a seguir).

```bash
curl -v "http://localhost:8098/riak/alimentos?list=stream"
...

* Connection #0 to host localhost left intact
...
{"keys":["favorito"]}
{"keys":[]}
* Closing connection #0
```

<!-- Transfer-Encoding -->

Deve constatar que estes comandos de listagem *não* devem ser utilizado em ambientes de produção (são operações demasiado dispendiosas). Mas são úteis para desenvolvimento, em investigações, ou para a execução de análises ocasionais em horários com carga leve.

## Buckets

Até aqui só usamos os buckets como namespaces (espaços de nome), eles são capazes de mais.

Diferentes cenários irão ditar se um bucket é maioritariamente para escritas ou leituras. Você pode usar um bucket para armazenar os logs, um bucket para armazenar os dados da sessão, enquanto outro pode armazenar os dados do carrinho de compras. Às vezes, ter baixa latência é importante, enquanto outras vezes é mais importante alta durabilidade. E às vezes nós só queremos buckets para reagir de maneira diferente quando ocorre uma escrita.

<h3>Quorum</h3>

A base da disponibilidade e da tolerância do Riak é o facto de se poder ler de, ou escrever para, vários nós. O Riak permite ajustar esses valores N/R/W (que nós já vimos em [Conceitos](#Compromissos-na-prática)) individualmente por bucket.

<h4>N/R/W</h4>

N é o número total de nós que um valor deve ser replicado, sendo 3 por defeito. Mas podemos definir este `n_val` para um qualquer número menor do que o número total de nós.

Qualquer propriedade de um bucket, incluindo o `n_val`, pode ser definido através do envio dessa propriedade atrás do valor `props`, como um objeto JSON para o URL do bucket. Vamos definir o `n_val` como 5 nós, o que significa que os objetos escritos para `carrinho` serão replicada por 5 nós.

```bash
curl -i -XPUT "http://localhost:8098/riak/carrinho" \
  -H "Content-Type: application/json" \
  -d '{"props":{"n_val":5}}'
```
Você pode ver as propriedades de um bucket através de um GET para esse bucket.

*Nota: O Riak devolve JSON não formatado. Se você tem uma ferramenta na linha de comandos como o jsonpp (ou json_pp) instalado, você pode direcionar a saída para lá, para facilitar a leitura. Os resultados abaixo são um subconjunto de todas as propriedades `props` suportadas.*


```bash
curl "http://localhost:8098/riak/carrinho" | jsonpp
{
  "props": {
    ...
    "dw": "quorum",
    "n_val": 5,
    "name": "carrinho",
    "postcommit": [],
    "pr": 0,
    "precommit": [],
    "pw": 0,
    "r": "quorum",
    "rw": "quorum",
    "w": "quorum",
    ...
  }
}
```
Como pode ver, o `n_val` é 5. É o esperado. Mas também pode ter notado que as propriedades do carrinho devolveram `quorum` tanto para o `r` como para o `w`, em vez de um número. Então, o que é um *quorum*?

<h5>Valores Simbólicos</h5>

Um *quorum* é um valor que seja mais de metade que todos os nós replicados (`floor(N/2) + 1`). Este é um número importante, pois, se escrever em mais de metade de todos os nós, e ler de mais de metade de todos os nós, então você vai ter sempre o valor mais recente (em circunstâncias normais).

Aqui está um exemplo com o `n_val` de 5 ({A,B,C,D,E}). Se o seu `w` é um quorum (que é `3`, ou `floor(5/2)+1`), então um PUT pode responder com êxito depois de escrever, por exemplo, para {A,B,C} ({D,E} serão eventualmente replicados). Imediatamente depois, um quorum de leitura pode obter os valores de {C,D,E}. Mesmo D e E tenham valores mais antigos, você leu um valor a partir do nó C, ou seja, receberá o valor mais recente.

O que é importante é que as suas leituras e escritas se *sobreponham*. Desde que `r+w > n`, na ausência de *quorum desleixado* (ver em baixo), você vai ser capaz de obter os valores mais recentes. Ou, em outras palavras, você terá uma razoável coerência de dados.

O `quorum` é um excelente valor por defeito, já que se está a ler a escrever para de um conjunto alargado de nós. Mas se tem exigências específicas, como um *log* que é muitas vezes escrito, mas raramente lido, você pode achar que faz mais sentido escrever para um único nó, mas ler a partir de todos. Isto proporciona-lhe a tal sobreposição.

```bash
curl -i -XPUT http://localhost:8098/riak/logs \
  -H "Content-Type: application/json" \
  -d '{"props":{"w":"one","r":"all"}}'
```

* `all` - Todas as réplicas devem responder, que é o mesmo que definir o `w` ou o `r` igual ao `n_val`.
* `one` - Definir o `r` ou o `w` igual a `1`.
* `quorum` - A maioria das réplicas devem responder, ou seja, "metade mais 1".

<h4>Quorum Desleixado (Sloppy Quorum)</h4>

Num mundo perfeito, um quorum rigoroso (*strict quorum*) seria suficiente para a maioria dos pedidos de escrita. No entanto, a qualquer momento, um nó pode ir abaixo, ou a rede pode sofrer uma partição ou esquilos podem ficar presos nos tubos, provocando a indisponibilidade de nós necessários. Isto é conhecido como um quorum rigoroso. O Riak usa por defeito o que é conhecido como um *quorum desleixado*, o que significa que se qualquer nó primário não estiver disponível, o próximo nó disponível no anel vai aceitar pedidos.

Pense nisso assim: digamos que está fora de casa a beber com um amigo; você encomenda duas bebidas (W=2), mas antes de chegarem, ele sai temporariamente. Se você fosse um quorum rigoroso, você poderia simplesmente recusar ambas as bebidas, já que as pessoas necessárias (N=2) não estão disponíveis. Mas você prefere ser um bêbado desleixado ... hum, quero dizer *quorum* desleixado. Ao invés de negar a bebida, você aceita as duas bebidas, uma *em nome do seu* amigo (você também terá de pagar).

![Um Quorum Desleixado](../assets/decor/drinks.png)

Quando ele volta, você dá-lhe a bebida. Isto é conhecido como *hinted handoff* ("oferta sugerida"), que veremos novamente no próximo capítulo. Por agora é suficiente notar que há uma diferença entre o quorum padrão desleixado (W), e exigir um quorum rigoroso de nós primários (PW).

<h5>Mais do que R's e W's</h5>

Outros valores que você deve ter notado nas propriedades `props` do bucket são: `pw`, `pr`, and `dw`.

O `pr` e o `pw` garantem que determinado número de nós *primários* estejam disponíveis antes de ler ou escrever. O Riak lê ou escrever para nós de backup se um destes nós primários não estiver disponível, por causa de uma partição de rede ou alguma falha de outro servidor. Mas este prefixo `p` irá assegurar que apenas os nós primários serão utilizados, onde *primário* significa um dos N primeiros vnodes que guardam este bucket.

(Nós mencionamos acima que `r+w > n` nos dá um nível razoável de coerência, menos quando temos quoruns desleixados. `pr+pw > n` fornece uma garantia bem mais forte de coerência, embora hajam sempre casos de escritas conflituosas ou de graves falhas no disco que prejudiquem a coerência.)

Finalmente, o `dw` representa o número *mínimo* de escritas duráveis necessárias para o sucesso. Para um escrita com `w` ser bem sucedida, um vnode precisa apenas de prometer que a escrita já começou, sem garantias de que essa escrita foi mesmo efetuada em disco, ou seja, foi tornada durável. O `dw` significa que o serviço de back-end (o serviço que trata da interface com o disco, como por exemplo, o Bitcask) concordou em escrever o valor em disco. Apesar de um alto valor `dw` penalizar o desempenho, há casos em que essa garantia extra é valiosa, como no caso de dados financeiros.


<h5>Por Pedido</h5>

É importante notar que estes valores (exceto o`n_val`) podem ser alterados *por pedido*.

Imagine um cenário onde você tem dados muito valiosos (por exemplo, o cartão de crédito numa compra online), e quer ajudar a garantir que vai ser gravado em disco nos nós relevantes, antes de ser considerado bem sucedido. Você podia adicionar `?dw=all` no fim da sua operação de escrita.

```bash
curl -i -XPUT http://localhost:8098/riak/carrinho/carrinho1?dw=all \
  -H "Content-Type: application/json" \
  -d '{"pago":true}'
```

Se qualquer um dos nós atualmente responsáveis pelos dados não conseguir concluir o pedido (i.e., não conseguiu armazenar os dados), o cliente receberá uma mensagem de falha. Isso não significa que a gravação falhou, necessariamente: se dois dos três principais vnodes escreveram com sucesso o valor, ele deve estar disponível para futuros pedidos. Portanto, aumentar a coerência em favor de menos disponibilidade ao aumentar os valores `dw` ou `pw`, pode levar a comportamentos inesperados.

<h3>Hooks</h3>

Outra utilidade dos buckets são sua capacidade de impor comportamentos nas escritas, por meio de *hooks*. Você pode anexar funções para executar tanto antes, como depois, de um valor ser realmente escrito num bucket.

Funções que são executadas antes de uma escrita são chamadas de *pré-commit*, e tem a possibilidade de cancelar uma escrita completamente se os dados de entrada foram considerados maus de alguma forma. Um simples hook *pré-commit* é verificar se um valor existe de todo.

Eu coloco os meus próprios ficheiros dentro da instalação do Riak `./custom/my_validators.erl`.

```java
-module(my_validators).
-export([value_exists/1]).

%% O tamanho do objecto deve ser maior que 0 bytes
value_exists(RiakObject) ->
  case erlang:byte_size(riak_object:get_value(RiakObject)) of
    Size when Size == 0 ->
      {fail, "É necessário um valor com tamanho maior que 0 bytes."};
    _ -> RiakObject
  end.
```

De seguida, compile o ficheiro.

```bash
erlc my_validators.erl
```

Instale o ficheiro, informando a instalação do Riak do seu novo código em `app.config` (reinicie o Riak).

```bash
{riak_kv,
  ...
  {add_paths, ["./custom"]}
}
```

Tudo que você precisa de fazer é definir o módulo e a função em Erlang como um valor em JSON, para o array do pré-commit do bucket `{"mod":"my_validators","fun":"value_exists"}`.

```bash
curl -i -XPUT http://localhost:8098/riak/carrinho \
  -H "Content-Type:application/json" \
  -d '{"props":{"precommit":[{"mod":"my_validators","fun":"value_exists"}]}}'
```

Se você tentar fazer um POST no bucket do `carrinho` sem um valor, deve devolver a nossa mensagem de erro.

```bash
curl -XPOST http://localhost:8098/riak/carrinho \
  -H "Content-Type:application/json"
É necessário um valor com tamanho maior que 0 bytes.
```

Você também pode escrever funções de pré-commit em JavaScript, embora o código Erlang execute mais rápido.

Os pós-commits são similares na forma e no uso, embora sejam sejam executados após a escrita ter sucedido. Principais diferenças:

* A única linguagem suportado é Erlang;
* O valor devolvido pela função é ignorado, logo não pode causar que uma mensagem de falha seja devolvida ao cliente.


## Entropia

A entropia é um subproduto da *coerência inevitável*. Por outras palavras: apesar da coerência inevitável dizer que uma escrita vai replicar para todos nós mais tarde ou mais cedo, pode haver um pequeno atraso enquanto todos os nós não contêm o mesmo valor.

Essa diferença é a *entropia*, e assim Riak criou várias estratégias de *anti-entropia* (também chamado *AE*). Nós já falamos sobre como um quorum R/W pode lidar com diferentes valores ao ler ou escrever, se os pedidos se sobrepuserem em pelo menos um nó. O Riak pode "reparar" a entropia, ou permitir que você o faça sozinho.

O Riak tem duas estratégias para lidar com nós que não concordam sobre um valor.

<h3>Last Write Wins (Última Escrita Ganha)</h3>

A estratégia mais básica e menos confiável para tratar da entropia é chamada de *Last Write Wins (Última Escrita Ganha)*. É a simples ideia de que a última escrita irá substituir uma escrita mais antiga, de acordo com o relógio real do nó local. Este é o comportamento por defeito do Riak atualmente (`allow_mult` está a falso). Alternativamente, pode-se ativar o `last_write_wins` para `true`e obter o mesmo resultado, mas sem guardar qualquer informação causal (vclocks), aumentando o desempenho.

Realisticamente, esta opção existe por uma questão de desempenho e simplicidade, ou quando você realmente não se importa com a verdadeira ordem das operações, ou a possibilidade da perda de dados. Uma vez que é impossível para manter os relógios dos servidores em sincronia (sem os famosos relógios atómicos geo-sincronizados), este é o melhor palpite sobre o que "último" significa, com a precisão ao milissegundo.

<h3>Vetores Versão</h3>

Nós vimos em [Conceitos](#Compromissos-na-prática)), que os *vetores versão* (vclocks) são a maneira do Riak de saber a verdadeira sequência de eventos sobre um objeto. Vamos ver como usar os vclocks para resolver conflitos de uma maneira mais sofisticada que apenas aceitar o mais recente.

Cada nó do Riak tem seu próprio ID único, que é usado para indicar onde uma atualização acontece como a chave do vetor versão.

<h4>Siblings ("Irmãos")</h4>

Os *siblings* ocorrerem quando há valores em conflito, sem nenhuma maneira clara de o Riak saber qual valor está correto. O Riak vai tentar resolver estes conflitos por si se o `allow_mult` estiver a falso. No entanto, pode optar que o Riak crie *siblings*, se definir o `allow_mult` de um bucket para `true`.

```bash
curl -i -XPUT http://localhost:8098/riak/carrinho \
  -H "Content-Type:application/json" \
  -d '{"props":{"allow_mult":true}}'
```

Os *siblings* aparecem em dois casos:

1. Um cliente escreve um valor, fornecendo um vetor versão opaco (ou nenhum).
2. Dois clientes escrevem ao mesmo tempo com o mesmo vetor versão.

Usamos o segundo caso para fabricar um conflito no último capítulo e vamos voltar a usar agora.

<h4>Exemplo de Conflito</h4>

Imagine que criámos um carrinho de compras para um único frigorífico, e que várias pessoas numa casa podem pedir comida através desse carrinho. Como não queremos perder compras para não causar mau ambiente na casa, vamos configurar o Riak com `allow_mult=true`.

Primeiro o Casey (vegetariano) coloca 10 pedidos de couve no seu carrinho.

O Casey escreve `[{"item":"couve","contador":10}]`.

```bash
curl -i -XPUT http://localhost:8098/riak/carrinho/fridge-97207?returnbody=true \
  -H "Content-Type:application/json" \
  -d '[{"item":"couve","contador":10}]'
HTTP/1.1 200 OK
X-Riak-Vclock: a85hYGBgzGDKBVIcypz/fgaUHjmTwZTImMfKsMKK7RRfFgA=
Vary: Accept-Encoding
Server: MochiWeb/1.1 WebMachine/1.9.0 (someone had painted...
Link: </riak/carrinho>; rel="up"
Last-Modified: Thu, 01 Nov 2012 00:13:28 GMT
ETag: "2IGTrV8g1NXEfkPZ45WfAP"
Date: Thu, 01 Nov 2012 00:13:28 GMT
Content-Type: application/json
Content-Length: 28

[{"item":"couve","contador":10}]
```

Repare no vclock opaco devolvido pelo Riak através do cabeçalho `X-Riak-Vclock`. O mesmo clock será devolvido para qualquer outra leitura, até que haja uma nova escrita nesta chave.

O seu colega de quarto `mark`, lê o carrinho e adiciona leite. Para que o Riak saiba a ordem das operações, o Mark fornece o vetor versão mais recente no seu PUT.

O Mark escreve `[{"item":"couve","contador":10},{"item":"leite","contador":1}]`.

```bash
curl -i -XPUT http://localhost:8098/riak/carrinho/fridge-97207?returnbody=true \
  -H "Content-Type:application/json" \
  -H "X-Riak-Vclock:a85hYGBgzGDKBVIcypz/fgaUHjmTwZTImMfKsMKK7RRfFgA="" \
  -d '[{"item":"couve","contador":10},{"item":"leite","contador":1}]'
HTTP/1.1 200 OK
X-Riak-Vclock: a85hYGBgzGDKBVIcypz/fgaUHjmTwZTIlMfKcMaK7RRfFgA=
Vary: Accept-Encoding
Server: MochiWeb/1.1 WebMachine/1.9.0 (someone had painted...
Link: </riak/carrinho>; rel="up"
Last-Modified: Thu, 01 Nov 2012 00:14:04 GMT
ETag: "62NRijQH3mRYPRybFneZaY"
Date: Thu, 01 Nov 2012 00:14:04 GMT
Content-Type: application/json
Content-Length: 54

[{"item":"couve","contador":10},{"item":"leite","contador":1}]
```

Se reparar bem, o vclock mudou com a segunda escrita.

* <code>a85hYGBgzGDKBVIcypz/fgaUHjmTwZTI<strong>mMfKsMK</strong>K7RRfFgA=</code> (depois da escrita do Casey)
* <code>a85hYGBgzGDKBVIcypz/fgaUHjmTwZTI<strong>lMfKcMa</strong>K7RRfFgA=</code> (depois da escrita do Mark)

Agora consideremos um terceiro companheiro de quarto, o Andy, que adora amêndoas. Antes do Mark ter adicionado o leite ao carrinho partilhado, o Andy leu o pedido das couves do Casey e adicionou amêndoas. Tal como o pedido do Mark, a escrita do Andy vai atualizar o vclock que inclui a informação do pedido do Casey, que é o último pedido que Andy conhecia à data da escrita.

O Andy escreve `[{"item":"couve","contador":10},{"item":"amêndoas","contador":12}]`.

```bash
curl -i -XPUT http://localhost:8098/riak/carrinho/fridge-97207?returnbody=true \
  -H "Content-Type:application/json" \
  -H "X-Riak-Vclock:a85hYGBgzGDKBVIcypz/fgaUHjmTwZTImMfKsMKK7RRfFgA="" \
  -d '[{"item":"couve","contador":20},{"item":"amêndoas","contador":12}]'
HTTP/1.1 300 Multiple Choices
X-Riak-Vclock: a85hYGBgzGDKBVIcypz/fgaUHjmTwZTInMfKoG7LdoovCwA=
Vary: Accept-Encoding
Server: MochiWeb/1.1 WebMachine/1.9.0 (someone had painted...
Last-Modified: Thu, 01 Nov 2012 00:24:07 GMT
ETag: "54Nx22W9M7JUKJnLBrRehj"
Date: Thu, 01 Nov 2012 00:24:07 GMT
Content-Type: multipart/mixed; boundary=Ql3O0enxVdaMF3YlXFOdmO5bvrs
Content-Length: 491


--Ql3O0enxVdaMF3YlXFOdmO5bvrs
Content-Type: application/json
Link: </riak/carrinho>; rel="up"
Etag: 62NRijQH3mRYPRybFneZaY
Last-Modified: Thu, 01 Nov 2012 00:14:04 GMT

[{"item":"couve","contador":10},{"item":"leite","contador":1}]
--Ql3O0enxVdaMF3YlXFOdmO5bvrs
Content-Type: application/json
Link: </riak/carrinho>; rel="up"
Etag: 7kfvPXisoVBfC43IiPKYNb
Last-Modified: Thu, 01 Nov 2012 00:24:07 GMT

[{"item":"couve","contador":10},{"item":"amêndoas","contador":12}]
--Ql3O0enxVdaMF3YlXFOdmO5bvrs--
```

Uau! Que é isto tudo?

Como houve um conflito entre o Mark e Andy sobre o que devia ter o carrinho, o Riak manteve ambos os valores.

<h4>VTag</h4>

Como estamos a utilizar o cliente HTTP, o Riak devolveu o código `300 Multiple Choices` com o tipo MIME de `multipart/mixed`. Cabe agora ao utilizador analisar os resultados (ou pode pedir um valor específico usando o Etag, também chamado de Vtag).

Executar um simples GET sobre a chave `/carrinho/fridge-97207` vai devolver os vtags de todos os siblings.

```
curl http://localhost:8098/riak/carrinho/fridge-97207
Siblings:
62NRijQH3mRYPRybFneZaY
7kfvPXisoVBfC43IiPKYNb
```

O que se pode fazer com estes vtags? Pode solicitar um determinado sibling usando o seu respetivo `vtag`. Para obter o primeiro sibling da lista (o leite do Mark):

```bash
curl http://localhost:8098/riak/carrinho/fridge-97207?vtag=62NRijQH3mRYPRybFneZaY
[{"item":"couve","contador":10},{"item":"leite","contador":1}]
```

Se quiser recuperar todos os siblings, diga ao Riak que aceita uma mensagem com múltiplos valores adicionando `-H "Accept:multipart/mixed"`.

```bash
curl http://localhost:8098/riak/carrinho/fridge-97207 \
  -H "Accept:multipart/mixed"
```

<aside class="sidebar"><h3>Depende do Cenário?</h3>

Quando são criados siblings, é a responsabilidade da aplicação saber como lidar com o conflito. No nosso exemplo, queremos aceitar apenas um dos pedidos? Devemos remover o leite e as amêndoas e apenas manter a couve?
Devemos calcular o mais barato dos dois e manter a opção mais barata?
Devemos juntar todos os resultados num único pedido? É por isso que podemos pedir ao Riak para não resolver este conflito automaticamente... queremos ter esta flexibilidade.
</aside>

<h4>Revolvendo Conflitos</h4>

Quando temos conflitos, queremos resolvê-los. Uma vez que a resolução deste conflito é em grande parte específico a cada caso, o Riak permite que o utilizador escolha como a nossa aplicação deve proceder.

Por exemplo, vamos juntar todos os valores num único conjunto de resultados, ficando com o maior *contador* caso o *item* seja o mesmo. Quando acabar, escreva o resultado no Riak juntamente com o vclock do objeto com múltiplos valores que recebeu, assim o Riak sabe que você está a resolver o conflito, e você vai receber de volta um novo vetor versão.

Leituras subsequentes receberão um único valor (fruto da nossa "fusão").

```bash
curl -i -XPUT http://localhost:8098/riak/carrinho/fridge-97207?returnbody=true \
  -H "Content-Type:application/json" \
  -H "X-Riak-Vclock:a85hYGBgzGDKBVIcypz/fgaUHjmTwZTInMfKoG7LdoovCwA=" \
  -d '[{"item":"couve","contador":10},{"item":"leite","contador":1},\
      {"item":"amêndoas","contador":12}]'
```

<h3>Último ganha (LWW) vs. Siblings</h3>

Os seus dados e as suas necessidades de negócio irão ditar a abordagem apropriada à resolução de conflitos. Não é preciso escolher uma estratégia global, em vez disso, sinta-se livre para tirar proveito dos buckets no riak para especificar quais dados usam siblings e quais guardam cegamente o último valor escrito.

Um pequeno resumo de dois valores de configuração que lhe deve interessar modificar:

* `allow_mult` por defeito é `false`, que significa que a última escrita ganha sempre.
* Mudando o `allow_mult` para `true` diz ao Riak para guardar valores em conflito como siblings (irmãos).
* `last_write_wins` por defeito é `false`, mas, talvez contra o que é era esperado, ainda podemos ter *last write wins*: o `allow_mult` é o parâmetro chave nesta escolhe.
* Mudando o `last_write_wins` para `true` vai otimizar as escritas ao ignorar todos os vclocks.
* Mudando o `allow_mult` e o `last_write_wins` para `true` não é suportado e vai resultar em efeitos imprevisíveis.


<h3>Read Repair (Reparação na Leitura)</h3>

Quando uma leitura bem sucedida acontece, mas nem todas as réplicas concordam sobre o valor, é executado o mecanismo chamado *read repair* (reparação na leitura). Isto significa que o Riak irá atualizar as réplicas "atrasadas" com o valor mais recente. Isso pode acontecer, ou quando um objeto não é encontrado (o vnode não tem uma cópia), ou quando um vnode contém um antigo valor (antigo significa que o seu vclock é um antepassado vclock mais recente). Ao contrário do `last_write_wins` ou da resolução manual de conflitos, o read repair é (obviamente, pelo nome) desencadeado por uma leitura, em vez de uma escrita.

Se os seus nós ficarem dessincronizados (por exemplo, se se aumentar o `n_val` num bucket), você pode forçar o read repair através da realização de uma operação de leitura de todas as chaves do bucket. Pode devolver `not found` (não encontrado) da primeira vez, mas leituras posteriores vão devolver os valores mais recentes.

<h3>Anti-Entropia Ativa (AAE)</h3>

Embora resolver conflitos durante leituras usando *read repair* seja suficiente para a maioria dos casos, os dados que nunca são lidos podem eventualmente ser perdidos devido a esses nós falharem e serem substituídos.

Com o Riak 1.3, foi introduzido a anti-entropia ativa (*active anti-entropy*) para pro-ativamente identificar e reparar dados incoerentes. Este mecanismo é útil também para recuperar da perda de dados quando os discos falham ou houve erros administrativos.


O custo desta funcionalidade é minimizado ao manter árvores de hashes sofisticadas ("Merkle Trees"), que facilitam a comparação do conjunto de dados entre nós virtuais. Esta funcionalidade pode ser desligada, caso seja desejado.

## Consultas

Até agora só lidamos com pesquisas de chave/valor. A verdade é que o par chave/valor é um mecanismo muito poderoso que abrange um largo espectro de cenários. No entanto, às vezes precisamos de pesquisar dados por valor, em vez da chave. Às vezes precisamos de realizar alguns cálculos, ou agregações, ou pesquisas mais avançadas.

<h3>Indexação Secundária (2i)</h3>

A *indexação secundária* (2i) é uma estrutura de dados que reduz o custo de
encontrar valores não-chave . Tal como muitas outras bases de dados, o Riak tem a capacidade de indexar dados. No entanto, dado que o Riak não tem conhecimento real dos dados que armazena (eles são apenas valores binários), ele usa metadados para indexar por nome, quer números ou binários.

Se a sua instalação estiver configurada para usar 2i (vamos ver isso no próximo capítulo),
uma simples escrita de um valor para Riak com o cabeçalho com prefixo `X-Riak-Index-` e com sufixos `_int` para números e `_bin` para texto, irá criar índices.

```bash
curl -i -XPUT http://localhost:8098/riak/pessoas/casey \
  -H "Content-Type:application/json" \
  -H "X-Riak-Index-idade_int:31" \
  -H "X-Riak-Index-fridge_bin:fridge-97207" \
  -d '{"trabalho":"palhaço"}'
```

Consultas podem ser feitas de duas formas: um valor exato ou um intervalo de valores. Adicionando mais umas pessoas, vamos ver o que temos: `mark` tem `32`, e `andy` tem `35` anos; ambos partilham o frigorífico `fridge-97207`.

Quais as pessoas que possuem o frigorífico `fridge-97207`? É uma pesquisa rápida para consultar as chaves que tenham um índice idêntico.

```bash
curl http://localhost:8098/buckets/pessoas/index/fridge_bin/fridge-97207
{"keys":["mark","casey","andy"]}
```
Com estas chaves, é fácil ler do Riak pelos nomes e obter mais detalhes.

A outra opção de consulta é sobre um intervalo. A seguinte pesquisa encontra todas as pessoas com menos de `32` anos (procurando entre `0` e `32`).

```bash
curl http://localhost:8098/buckets/pessoas/index/idade_int/0/32
{"keys":["mark","casey"]}
```
É mais ou menos isto sobre  índices secundários. É uma implementação simples, com uma gama decente de casos de uso.

<h3>MapReduce/Link Walking (</h3>

O *MapReduce* é um método de agregação de grandes quantidades de dados através da separação do processamento em duas fases: mapear e reduzir, sendo ambas executadas separadamente. O mapeamento é executado por objeto, para converter / extrair algum valor, e em seguida, os valores mapeados serão reduzidos / combinados num resultado agregado. Mas o que se ganha ao fazer isto? Isto é baseado na ideia de que é mais barato mover os algoritmos para onde os dados vivem, do que transferir quantidades massivas de dados para um único servidor e efetuar o processamento.

Este método, popularizado pela Google, pode ser visto numa grande variedade de base de dados NoSQL. No Riak, você executa uma tarefa MapReduce num único nó, que de seguida propaga-a para outros nós. Os resultados são mapeados e reduzidos, e no final são agregados no coordenador do MapReduce, que então devolve o resultado ao cliente.


![MapReduce que devolve o número de caracteres dos nomes](../assets/mapreduce.svg)

Vamos supor que temos um bucket para registos que armazena mensagens prefixadas por INFO ou ERROR. Queremos contar o número de registos INFO que contenham a palavra "carrinho".


```bash
LOGS=http://localhost:8098/riak/logs
curl -XPOST $LOGS -d "INFO: Novo utilizador"
curl -XPOST $LOGS -d "INFO: couve adicionada ao carrinho"
curl -XPOST $LOGS -d "INFO: leite adicionado ao carrinho"
curl -XPOST $LOGS -d "ERROR: carrinho cancelado"
```

Os trabalhos de MapReduce tanto podem ser código Erlang como JavaScript. Desta vez, vamos usar JavaScript. Executa-se um trabalho MapReduce ao enviar um JSON para o caminho `/mapred`.


```bash
curl -XPOST "http://localhost:8098/mapred" \
  -H "Content-Type: application/json" \
  -d @- \
<<EOF
{
  "inputs":"logs",
  "query":[{
    "map":{
      "language":"javascript",
      "source":"function(riakObject, keydata, arg) {
        var m = riakObject.values[0].data.match(/^INFO.*carrinho/);
        return [(m ? m.length : 0 )];
      }"
    },
    "reduce":{
      "language":"javascript",
      "source":"function(values, arg){
        return [values.reduce(
          function(total, v){ return total + v; }, 0)
        ];
      }"
    }
  }]
}
EOF
```

O resultado deve ser `[2]`, como esperado. Ambas as fases do mapeamento e da redução devem devolver sempre uma matriz. A fase de mapeamento recebe um único objeto do riak, enquanto que a  fase redução recebe uma matriz de valores: o resultado de múltiplos resultados de mapeamentos, ou de múltiplos resultados de redução. Eu provavelmente fiz um pouco de batota ao usar a função `reduce` do JavaScript para somar os valores, mas... Bem-vindos ao pensamento em termos de MapReduce!


<h4>Filtros de Chave</h4>

Além de executar uma função de mapeamento contra todos os objetos num bucket, você pode reduzir o seu alcance usando *filtros de chave*. Eles são uma forma de incluir apenas aqueles objetos que correspondem a um padrão... ele filtra certas chaves.

Ao invés de passar o nome do bucket como valor para o `inputs`, vamos passar um objeto JSON que contém o `bucket` e as `key_filters`.
O `key_filters` requer um array descrevendo como transformar e depois testar cada chave no bucket. Quaisquer chaves que correspondam ao predicado, serão passadas para a fase de mapeamento; todos as outras chaves serão filtrados.

Para obter todas as chaves no bucket `carrinho` que terminam com um número superior a 97000, você poderia dividir as chaves usando `-` (lembre-se como utilizamos `fridge-97207`) e manter a segunda metade do string, converte-la num número inteiro e finamente verificar esse número é maior que 97000.

```
"inputs":{
  "bucket":"carrinho",
  "key_filters":[["tokenize", "-", 2],["string_to_int"],["greater_than",97000]]
}
```

Seria algo como isto para que o mapeador apenas retornasse chaves correspondentes. Preste especial atenção à função `map`, e à falta de um `reduce`.

```bash
curl -XPOST http://localhost:8098/mapred \
  -H "Content-Type: application/json" \
  -d @- \
<<EOF
{
  "inputs":{
    "bucket":"carrinho",
    "key_filters":[
      ["tokenize", "-", 2],
      ["string_to_int"],
      ["greater_than",97000]
    ]
  },
  "query":[{
    "map":{
      "language":"javascript",
      "source":"function(riakObject, keydata, arg) {
        return [riakObject.key];
      }"
    }
  }]
}
EOF
```

<h4>MR + 2i</h4>

Outra opção quando se usa MapReduce é combiná-lo com índices secundários. Você pode enviar os resultados de uma *consulta 2i* num MapReduce, basta especificar o índice que deseja usar: `key`para usar uma chave na pesquisar no índice, ou `start` e `stop` para pesquisar numa gama de valores.


```json
    ...
    "inputs":{
       "bucket":"pessoas",
       "index": "idade_int",
       "start": 18,
       "end":   32
    },
    ...
```

<h4>Percorrer Links</h4>

Conceptualmente, um link é uma relação de um só sentido, a partir de um objeto para outro.
*Percorrer Links* é uma opção de consulta conveniente para recuperar dados quando você começa
com o objeto ligado a partir desse.

Vamos adicionar um link para as nossas pessoas, definindo o `Casey` como o irmão do `mark`
usando o cabeçalho HTTP `Link`.

```bash
curl -XPUT http://localhost:8098/riak/pessoas/mark \
  -H "Content-Type:application/json" \
  -H "Link: </riak/pessoas/casey>; riaktag=\"irmao\""
```
Com um link no lugar, agora é hora de percorre-lo. Percorrer links é como um pedido normal, mas com o sufixo `/[bucket],[riaktag],[keep]`. Ou seja, o *bucket* para onde um possível link aponta, o valor do *riaktag*, e se é para manter (*keep*) os resultados desta fase (útil apenas para encadear links). Qualquer conbinação dos valores nas pesquisas pode ser definido como um *wildcard* _, ou seja, qualquer valor serve.

```bash
curl http://localhost:8098/riak/pessoas/mark/pessoas,irmao,_

--8wuTE7VSpvHlAJo6XovIrGFGalP
Content-Type: multipart/mixed; boundary=991Bi7WVpjYAGUwZlMfJ4nPJROw

--991Bi7WVpjYAGUwZlMfJ4nPJROw
X-Riak-Vclock: a85hYGBgzGDKBVIcypz/fgZMzorIYEpkz2NlWCzKcYovCwA=
Location: /riak/pessoas/casey
Content-Type: application/json
Link: </riak/pessoas>; rel="up"
Etag: Wf02eljDiBa5q5nSbTq2s
Last-Modified: Fri, 02 Nov 2012 10:00:03 GMT
x-riak-index-idade_int: 31
x-riak-index-fridge_bin: fridge-97207

{"trabalho":"palhaço"}
--991Bi7WVpjYAGUwZlMfJ4nPJROw--

--8wuTE7VSpvHlAJo6XovIrGFGalP--
```

Mesmo sem retornar o Content-Type, este tipo de corpo deve ser familiar.
Percorrer links devolve sempre um `multipart/mixed`, já que uma única chave pode
conter qualquer número de links, ou seja, qualquer número de objetos devolvidos.

E ainda é mais louco. Você pode na realidade encadear percorridas de links, que vão seguir o link seguido. Se o `Casey` tem links, eles podem ser seguidos com outro link no final, assim:

```bash
curl http://localhost:8098/riak/pessoas/mark/pessoas,irmao,0/_,_,_
```

Pode não parecer pelo que temos visto, mas percorrer links é uma forma especializada do MapReduce.

Há uma outra fase no MapReduce chamado de "link". No entanto, em vez de executar uma função, requer a mesma configuração que já vimos nos URL acima.

```json
    ...
    "query":[{
      "link":{
        "bucket":"pessoas",
        "tag":   "irmao",
        "keep":  false
      }
    }]
    ...
```

Como vimos, o MapReduce no Riak é uma maneira poderosa de puxar dados para fora de uma "simples" base de dados chave/valor. Mas temos mais um método de encontrar dados no Riak.


<aside class="sidebar"><h3>O que aconteceu com o Riak Search?</h3>

Se você já usou o Riak antes, ou teve acesso a documentação mais antiga, você pode estar a perguntar-se qual é a diferença entre o Riak Search e o Yokozuna.

Numa tentativa de tornar o Riak Search agradável para os utilizadores, ele foi originalmente desenvolvido com uma interface parecida com o *Solr*. Infelizmente, devido à complexidade na construção de motores de busca distribuídos, estava lamentavelmente incompleto. Então, a Basho decidiu que, em vez de tentar manter a paridade com Solr, um motor de busca popular e com mais recursos, fazia mais sentido para integrar os dois.
</aside>

<h3>Pesquisa (Yokozuna)</h3>

*Nota: Isto cobre um projeto que ainda está sob desenvolvimento. Mudanças são esperadas, por isso vejam a [página do projeto](https://github.com/rzezeski/yokozuna) para saber das últimas novidades.*

O Yokozuna é uma extensão para o Riak que permite realizar pesquisas para encontrar dados num cluster Riak. Ao contrário do original Riak Search, o Yokozuna aproveita o Solr distribuído para executar a indexação invertida e recuperação de valores correspondentes.

Antes de utilizar o Yokozuna, você terá que o instalar e ter um bucket com um índice (estes pormenores podem ser encontrados no capítulo seguinte).

O exemplo mais simples é uma pesquisa completa de texto. Vamos adicionar o `ryan` na tabela de `pessoas` (com um índice por defeito).

```bash
curl -XPUT http://localhost:8098/riak/pessoas/ryan \
  -H "Content-Type:text/plain" \
  -d "Ryan Zezeski"
```

Para executar uma pesquisa, temos que pedir: `/search/[bucket]` junto com qualquer [parâmetro do Solr](http://wiki.apache.org/solr/CommonQueryParameters) distribuído. Vamos consultar os documentos que contêm uma palavra que começa com 'zez`, pedindo que os resultados sejam no formato JSON (`wt=json`) e que apenas devolva a chave Riak (`fl=_yz_rk`).

```bash
curl "http://localhost:8098/search/pessoas?wt=json&\
      omitHeader=true&fl=_yz_rk&q=zez*" | jsonpp
{
  "response": {
    "numFound": 1,
    "start": 0,
    "maxScore": 1.0,
    "docs": [
      {
        "_yz_rk": "ryan"
      }
    ]
  }
}
```

Com as chaves correspondentes a `_yz_rk`, você pode recuperar os corpos com uma simples pesquisa no Riak.

O Yokozuna suporta o Solr 4.0, que inclui consultas com filtro, gamas de valores, páginas de score, valores e linhas iniciais (os dois últimos são úteis para a paginação). Você também pode receber trechos de resultados correspondentes em [destaque no texto](http://wiki.apache.org/solr/HighlightingParameters) (`hl`,`hl.fl`), algo que é útil para a construção de um motor de pesquisa (e é algo que usamos no [search.basho.com](http://search.basho.com)).


<h4>Tagging</h4>

Outro recurso útil do Solr e do Yokozuna é a *tagging* (marcação) de valores. Dar tags a valores dá um contexto adicional a um valor no Riak. A implementação atual exige que todos os valores marcados comecem com `X-Riak-Meta`, e podem ser listados num cabeçalho especial chamado `X-Riak-Meta-yz-tags`.

```bash
curl -XPUT "http://localhost:8098/riak/pessoas/dave" \
  -H "Content-Type:text/plain" \
  -H "X-Riak-Meta-yz-tags: X-Riak-Meta-nickname_s" \
  -H "X-Riak-Meta-nickname_s:dizzy" \
  -d "Dave Smith"
```

Para procurar pela tag `nickname_s`, basta usar essa tag como prefixo e acrescentar a palavra para a pesquisa, septada por ":".

```bash
curl "http://localhost:8098/search/pessoas?wt=json&\
      omitHeader=true&q=nickname_s:dizzy" | jsonpp
{
  "response": {
    "numFound": 1,
    "start": 0,
    "maxScore": 1.4054651,
    "docs": [
      {
        "nickname_s": "dizzy",
        "id": "dave_25",
        "_yz_ed": "20121102T215100 dave m7psMIomLMu/+dtWx51Kluvvrb8=",
        "_yz_fpn": "23",
        "_yz_node": "dev1@127.0.0.1",
        "_yz_pn": "25",
        "_yz_rk": "dave",
        "_version_": 1417562617478643712
      }
    ]
  }
}
```

Note que a resposta também contêm `"nickname_s":"dizzy"` como um valor. Todos os valores marcados (com a tag) serão devolvidos nos resultados correspondentes.

*Fique preparado para mais recursos no Yokozuna, assim que ele se aproxima de uma versão final.*

## Conclusão

O riak é um armazenamento de dados distribuídos com várias adições para melhorar a simples pesquisa de chave/valor, como a especificação de valores de replicação. Como os valores no Riak são opacos, muitos destes métodos exigem: ou um código personalizado para extrair e dar sentido aos valores, como o *MapReduce*; ou que os metadados no cabeçalho permitam uma descrição do objeto, tais como *índices secundários*, *percorrer links* ou *pesquisa*.

De seguida, vamos espreitar ainda mais o interior do riak, ver como configurar e gerir um cluster por si próprio, e ver o que você deve saber.
