#!/usr/bin/env ruby
require 'redcarpet'

OUTPUT_DIR = 'rendered'

def gen_html(language)
  Dir.mkdir('tmp') rescue nil

  markdown_toc = Redcarpet::Markdown.new(Redcarpet::Render::HTML_TOC.new(),
    :fenced_code_blocks => true,
    :autolink => true,
    :no_intra_emphasis => true,
    :space_after_headers => false
  )
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(:with_toc_data => true),
    :fenced_code_blocks => true,
    :autolink => true,
    :no_intra_emphasis => true,
    :space_after_headers => false
  )

  html = ""
  toc = ""
  Dir.glob("#{language}/*.md").each do |page_path|
    chapter = File.read(page_path)
    toc << markdown_toc.render(chapter)
    html << markdown.render(chapter)
  end
  prelude = markdown.render(File.read("en/prelude.pmd"))
  html = "<html><head><title>A Little Riak Book</title></head><body>#{prelude}#{toc}#{html}</body></html>"
  full_file = "#{OUTPUT_DIR}/riaklil-#{language}.html"
  File.open(full_file, 'w') {|f| f.write(html) }
  full_file
end

def gen_book(language, html_file, format)
  system('ebook-convert', html_file, "#{OUTPUT_DIR}/riaklil-#{language}.#{format}",
    '--language', language,
    '--authors', 'Eric Redmond',
    '--comments', "Licensed under the Creative-Commons Attribution-Noncommercial-Share Alike 3.0 Unported",
    # '--cover', 'assets/cover.png',
    '--level1-toc', '//h:h1',
    '--level2-toc', '//h:h2',
    '--level3-toc', '//h:h3')
end


language = ARGV[0] || "en"
formats = %w{pdf mobi epub}

html_file = gen_html(language)
formats.each do |format|
  gen_book(language, html_file, format)
end
