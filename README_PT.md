# Um Pequeno Livro sobre Riak

Pode fazer o download de diferentes formatos na pasta
[rendered](https://github.com/coderoshi/little_riak_book/tree/master/rendered/).

Deve ter também o `ruby` instalado, testado principalmente com a versão 1.9.2+

### Gerar os eBooks/PDFs

```
[sudo] gem install bundler
bundle install
[sudo] gem install redcarpet
```

O texto está todo em *markdown*. Para compilar o livro, tem que instalar o
[calibre](http://manual.calibre-ebook.com/cli/cli-index.html).

Para gerar o PDF é preciso algo mais avançado. É preciso tanto o
[Pandoc](http://johnmacfarlane.net/pandoc/) como o `xelatex`
([XeTeX](http://scripts.sil.org/xetex) para o OSX, e
[MikTeX](http://miktex.org/) para o Windows) instalados.

```
bookgen.rb pt
```

As ferramentas para construir o PDF foram inspirados no livro Pro Git.
Obrigado a essa equipa.
