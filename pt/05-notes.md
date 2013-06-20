# Notas

## Uma pequena nota sobre o RiakCS

O *Riak CS* é uma extensão open-source do Riak pela Basho, que permite que o seu
cluster funcione como um servidor de dados remoto, comparável (e compatível) com
o S3 da Amazon. Há várias razões para querer ter a sua própria solução de
servidor na cloud (segurança, razões legais, já tem em posse muito hardware,
mais barato em escala). Isto não é abordado neste pequeno livro, embora eu
esteja com vontade de escrever um sobre isto.

## Uma pequena nota sobre o MDC

O *MDC* ou Multi Data Center (Múltiplos Data Centers), é uma extensão
comercial do Riak oferecida pela Basho. Embora a documentação esteja disponível
livremente, o código fonte não está. Se atingir um volume de dados em que
precise de ter múltiplos clusters do Riak em sincronia numa escala local ou
global, eu recomendaria considerar esta opção.
