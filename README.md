# A Little Riak Book

You can download different formats from [rendered](https://github.com/coderoshi/little_riak_book/tree/master/rendered/).

You must have `ruby` installed, tested mostly on 1.9.2+

### Building eBooks

```
gem install bundler
bundle install
```

All text is in markdown. To build the book, you must install [calibre](http://manual.calibre-ebook.com/cli/cli-index.html).

```
bookgen.rb
```

### Building PDF

Building a PDF is a bit more involved. It requires you have both [Pandoc](http://johnmacfarlane.net/pandoc/) and `xelatex` ([XeTeX](http://scripts.sil.org/xetex) for OSX, and [MikTeX](http://miktex.org/) for Windows) installed.

```
pdfgen.rb
```

The tools to build the PDF was pilfered from the Pro Git book builder. Thanks to that team.
