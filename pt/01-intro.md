# Introdução

## Roleta da Inatividade

![Apostas com a Disponibilidade](../assets/decor/roulette.png)

Imagine uma roleta num casino, onde qualquer número tem a probabilidade de 1 em 37 de sair. Imagine agora que você poderia apostar que um determinado número *não* ia sair (97,3% de hipóteses a seu favor), e ganhando pagaria 10 vezes a sua aposta. Você faria essa aposta? Eu pegava na minha carteira tão rápido que o meu polegar iniciava um incêndio no meu bolso.

Agora imagine que podia apostar de novo, mas só ganha se a roda fizer 100 rotações seguidas em seu favor, senão perde. Será que você ainda joga? Ganhar uma aposta simples pode ser fácil, mas ao longo de várias tentativas as probabilidades não são favoráveis.

As pessoas estão sempre a fazer este tipo de apostas com os dados. Um único servidor tem boas hipóteses de continuar disponível. Mas quando você administra um cluster com milhares de servidores, ou biliões de pedidos, as hipóteses de qualquer um falhar tornam-se muito grandes. 

Até um desastre de uma-vez-num-milhão é comum à luz de um bilião de oportunidades.

## O que é o Riak?

O Riak é uma base de dados distribuída de código aberto que oferece alta disponibilidade, tolerância a falhas e escalabilidade quase linear. Basicamente, significa que o Riak raramente tem falhas de serviço e que cresce com o sistema.

<!-- image: phone with 1/0's flying from it to a disk array -->

À medida que o mundo moderno que interliga com ligações cada vez mais complexas, grandes mudanças estão a ocorrer na gestão de dados. A web e os dispositivos com conectividade provocaram uma explosão tanto na recolha como no acesso a dados, inédito na história moderna. A magnitude de dados que estão a ser armazenados e geridos cresceu a um ritmo vertiginoso, e em paralelo, mais pessoas que nunca precisam de acesso rápido e confiável a esses dados. É isto que é geralmente se chama de *Big Data*.


<aside id="big-data" class="sidebar"><h3>Então o que é o <em>Big Data?</em></h3>

Há muita discussão em torno do que constitui o <em>Big Data</em>.

Eu tenho 6 Terabytes em minha casa para guarar vídeos e outros backups. Isso conta? Por outro lado, o CERN armazenou cerca de [200 Petabytes](http://www.itbusinessedge.com/cm/blogs/lawson/the-big-data-software-problem-behind-cerns-higgs-boson-hunt/?cs=50736) na procura do *Higgs Boson*.

<!-- image: raid box -->

É um número difícil de definir, porque Big Data é uma figura pessoal. O que é grande para uma pessoa pode ser pequeno para outra. É por isso que muitas definições não se referem a tamanhos em específico, mas a valores relativos. Uma razoável, embora extensa, [definição de Big Data](http://www.gartner.com/DisplayDocument?ref=clientFriendlyUrl&id=2057415) é dado pela Gartner.

<blockquote>Big Data é informação de elevado volume, de alta velocidade, e/ou de grande variedade, que exigem novas formas de processamento para permitir tomar decisões inteligentes, compreender os dados e otimizar processos.</blockquote></aside>

<h3>Conte sempre com o Riak</h3>

O cenário ideal para usar o Riak é com um elevado volume de dados (que estão disponíveis para ler e escrever quando for preciso), a alta velocidade (responde facilmente ao crescimento) e com grande variedade (pode armazenar qualquer tipo de dados como um valor).

O Riak foi construído como uma solução para problemas reais do Big Data, com base no modelo do *Dynamo* da Amazon. O Dynamo foi pensado para ser altamente disponível---o que significa que responde rapidamente a pedidos em escalas muito grandes, mesmo se a aplicação armazena e serve Terabytes de dados por dia. O Riak já era utilizado em produção antes de ser disponibilizado em código aberto em 2009. Atualmente, é usado pelo Github, Comcast, Voxer, Disqus ente outros, com os maiores sistemas a armazenar centenas de TBs de dados, manipulando diariamente vários GBs por máquina.

O Riak foi escrito na linguagem de programação Erlang. O Erlang foi escolhido devido ao seu forte suporte à concorrência, comunicação distribuída, atualização de código em produção e tolerância a falhas. Como o Erlang corre numa máquina virtual, para executar o Riak é também necessário ter o Erlang instalado.

Portanto, será que você deve usar o Riak? Uma boa regra de ouro para os potenciais utilizadores é de se perguntar se cada momento de indisponibilidade lhe vai custar de alguma forma (dinheiro, utilizadores, etc.). Nem todos os sistemas necessitam de uma disponibilidade tão elevada, e se for esse o seu caso, o Riak pode não ser para si.

## Acerca deste Livro

Este não é um guia do estilo "instale e acompanhe". Este é um guia para "ler e compreender". Não se sinta obrigado a ter o Riak instalado, ou mesmo sequer ter um computador à mão, ao iniciar este livro. Você pode desejar instalar em algum momento e, nesse caso, as instruções podem ser encontradas na documentação oficial: [Riak Docs](http://docs.basho.com).

Na minha opinião, a parte mais importante deste livro é o [capítulo Conceitos](#Conceitos). Se você já tem algum conhecimento pode achar o começo aborrecido, mas isso muda rapidamente. Depois de lançar as bases teóricas, vamos ajudar os [programadores](#Programadores) a usar o Riak, aprendendo como se consulta os dados e como alterar algumas configurações. Finalmente, vamos falar sobre os detalhes básicos que os [administradores](#Administradores) devem saber, como por exemplo a criação de um cluster Riak, configurar alguns valores, usar ferramentas opcionais, e muito mais.

