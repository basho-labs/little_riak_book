#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require 'rubygems'
require 'redcarpet'
require 'fileutils'
require 'erb'
require 'yaml'

OUTPUT_DIR = 'rendered'

include FileUtils

$here = File.expand_path(File.dirname(__FILE__))
$root = $here #File.join($here, '..')
$outDir = File.join($root, 'pdf')

def gen_pdf(languages)
  # I hate this with a passion. Need to fix the 'svg' suffix failure issue
  def figures(&block)
    begin
      Dir::mkdir("#$root/figures") rescue nil
      Dir::mkdir("#$root/figures/decor") rescue nil
      Dir["#$root/assets/*.png","#$root/assets/decor/*.png"].each do |file|
        cp file, file.sub(/assets\/(.*?)\.\w{3}/, "figures/\\1.png")
      end
      Dir["#$root/assets/*.pdf"].each do |file|
        cp file, file.sub(/assets\/(.*?)\.\w{3}/, "figures/\\1.pdf")
      end
      block.call
    ensure
      Dir["#$root/figures/decor/*"].each do |file|
        rm(file) rescue nil
      end
      Dir::unlink("#$root/figures/decor") rescue nil
      Dir["#$root/figures/*"].each do |file|
        rm(file) rescue nil
      end
      Dir::unlink("#$root/figures") rescue nil
    end
  end

  def command_exists?(command)
    if File.executable?(command) then
      return command
    end
    ENV['PATH'].split(File::PATH_SEPARATOR).map do |path|
      cmd = "#{path}/#{command}"
      File.executable?(cmd) || File.executable?("#{cmd}.exe") || File.executable?("#{cmd}.cmd")
    end.inject{|a, b| a || b}
  end

  def replace(string, &block)
    string.instance_eval do
      alias :s :gsub!
      instance_eval(&block)
    end
    string
  end

  def verbatim_sanitize(string)
    string.gsub('\\', '{\textbackslash}').
      gsub('~', '{\textasciitilde}').
      gsub(/([\$\#\_\^\%])/, '\\\\' + '\1{}')
  end

  def pre_pandoc(string, config, isprint)
    replace(string) do
      # Pandoc discards #### subsubsections - this hack recovers them
      # be careful to try to match the longest sharp string first
      s %r{\#\#\#\#\# (.*?)$}, 'PARAGRAPH: \1'
      s %r{\#\#\#\# (.*?)$}, 'SUBSUBSECTION: \1'
      s %r{\#\#\# (.*?)$}, 'SUBSECTION: \1'
      s %r{\<h5\>(.*?)\<\/h5\>}, 'PARAGRAPH: \1'
      s %r{\<h4\>(.*?)\<\/h4\>}, 'SUBSUBSECTION: \1'
      s %r{\<h3\>(.*?)\<\/h3\>}, 'SUBSECTION: \1'

      # s %r{\<aside.*?\>.*?\<h3\>(.+?)\<\/h3\>(.+?)\<\/aside\>}im, "ASIDE: \\1\n\\2\nENDASIDE"
      s %r{\<aside.*?\>(.+?)\<\/aside\>}im, "ASIDE: \\1\n:ENDASIDE"

      # Process figures
      s /^\!\[(.*?)\]\(\.\.\/(.*?\/decor\/drinks.*?)\)/, 'DEC2: \2'
      s /^\!\[(.*?)\]\(\.\.\/(.*?\/decor\/.*?)\)/, 'DEC: \2'
      # Yet another ugly hack because xelatex doesn't recognize svg
      s /^\!\[(.*?)\]\(\.\.\/assets\/(.*?)\.(svg)\)/, 'FIG: \2 --- pdf --- \1'
      s /^\!\[(.*?)\]\(\.\.\/assets\/(.*?)\.(\w{3,4})\)/, 'FIG: \2 --- \3 --- \1'

      # TODO: perhaps this should be post pandoc?
      if isprint
        # Extract absolute any clickable links to be a footnote
        # ignore any local links
        s %r{\[(.*?)\]\((https?\:\/\/.*?)\)}, 'LINK: \2 ---*\1*---'
        s %r{\<a\s+.*?href=['"]?(https?\:\/\/.*?)['"]?\>(.*?)\<\/a\>}, 'LINK: \1 ---*\2*---'
      else
        # Make any URL a clickable links
        s %r{\`(https?:\/\/[A-Za-z0-9\/\%\&\=\-\_\\\.]+)\`}, '<\1>'
        s %r{(\n\n)\t(https?:\/\/[A-Za-z0-9\/\%\&\=\-\_\\\.]+)\n([^\t]|\t\n)}, '\1<\2>\1'
      end
    end
  end

  def post_pandoc(string, config, isprint)
    replace(string) do
      # Reformat for the book documentclass as opposed to article
      s '\section', '\chap'
      s '\sub', '\\'
      s /SUBSUBSECTION: (.*)/, '\subsubsection{\1}'
      s /SUBSECTION: (.*)/, '\subsection{\1}'
      s /PARAGRAPH: (.*)/, '\paragraph{\1}'

      # replace asides
      # s /\<aside.*?\>\s*\<h3\>(.+?)\<\/h3\>(.+?)\<\/aside\>/, "\\begin{aside}\n\\begin{center}\n\\emph{\1}\n\\end{center}\n\2\n\\end{aside}"
      s /ASIDE: (.+?)\:ENDASIDE/m, "\\begin{aside}\n\\1\\end{aside}"

      # Enable proper cross-reference
      s /#{config['fig'].gsub(/\s/, '\s')}\s*(\d+)\-\-(\d+)/, '\imgref{\1.\2}'
      s /#{config['tab'].gsub(/\s/, '\s')}\s*(\d+)\-\-(\d+)/, '\tabref{\1.\2}'
      s /#{config['prechap'].gsub(/\s/, '\s')}\s*(\d+)(\s*)#{config['postchap'].gsub(/\s/, '\s')}/, '\chapref{\1}\2'

      # Miscellaneous fixes
      # s /DEC: (.*)/, "\\begin{wrapfigure}{r}{.3\\textwidth}\n  \\includegraphics[scale=1.0]{\\1}\n\\end{wrapfigure}"
      s /DEC: (.*)/, "\\begin{wrapfigure}{r}{.4\\textwidth}\n  \\includegraphics[scale=1.0]{\\1}\n\\end{wrapfigure}"
      s /DEC2: (.*)/, "\\begin{wrapfigure}{r}{.65\\textwidth}\n  \\includegraphics[scale=1.0]{\\1}\n\\end{wrapfigure}"
      s /FIG: (.*?) \-\-\- (\w{3,4}) \-\-\- (.*)/, '\img{\1}{\2}{\3}'
      s '\begin{enumerate}[1.]', '\begin{enumerate}'
      s /(\w)--(\w)/, '\1-\2'
      s /``(.*?)''/, "#{config['dql']}\\1#{config['dqr']}"

      if isprint
        # Extract any clickable links to become a footnote
        s /LINK\: (.*?) \-{3}(.*?)\-{3}/, '\2\\footnote{\1}'
      end

      # Typeset the maths in the book with TeX
      s '\verb!p = (n(n-1)/2) * (1/2^160))!', '$p = \frac{n(n-1)}{2} \times \frac{1}{2^{160}}$)'
      s '2\^{}80', '$2^{80}$'
      s /\sx\s10\\\^\{\}(\d+)/, '\e{\1}'

      # Convert inline-verbatims into \texttt (which is able to wrap)
      s /\\verb(\W)(.*?)\1/ ,'\\texttt{\2}'

      # Make Tables 2-1..2-3 actual tables
      s /\\begin\{verbatim\}\n(([^\t\n]+\t.*?\n)+)(([^\t\n]*)\n)?\\end\{verbatim\}/ do
        $cap = $4
        "\\begin{table}[ht!]
          \\refstepcounter{tab}
          \\centering
          \\label{tab:\\thetab}
          \\begin{tabular}{p{2.75cm}p{8.25cm}}
            \\toprule\n" <<
            verbatim_sanitize($1).
              gsub(/^([^\n\t]+)\t/, '{\footnotesize\texttt{\1}} & ').
              gsub(/(\n)/, '\\\\\\\\\1').
              sub(/\{\\footnotesize\\texttt(.*?)\n/, '{\1\midrule ').
              concat("
            \\bottomrule
          \\end{tabular}
          \\textbf{\\caption{#{$cap}}}
        \\end{table}")
      end

      # char13 doesn't render right with pandoc
      s /\{\\char13\}/, "'"
      s /(\d+)\\\^\{\}(\d+)/, "$\\1^{\\2}$"

      # hack fixs of bad bash renderer
      s /we\ execute /, "we execute \\linebreak[4]"

      # Shaded verbatim block
      s /(\\begin\{verbatim\}.*?\\end\{verbatim\})/m, '\begin{shaded}\1\end{shaded}'
      # s /\\begin\{shaded\}(.*?)\\end\{shaded\}/im, '\1'
      # s /\\begin\{highlighting\}(?:\[\])?(.*?)\\end\{highlighting\}/im, '\1'
    end
  end

  missing = ['pandoc', 'xelatex'].reject{|command| command_exists?(command)}
  unless missing.empty?
    puts "Missing dependencies: #{missing.join(', ')}."
    puts "Install these and try again."
    exit
  end

  $config = YAML.load_file("#$here/tex.yml")
  template = ERB.new(File.read("#$here/template.tex"))

  figures do
    languages.each do |lang|
      config = $config['default'].merge($config[lang]) rescue $config['default']

      puts "#{lang}:"
      markdown = Dir.glob("#$root/#{lang}/*.md").sort.map do |file|
        File.read(file)
      end.join("\n\n")

      ### Output a PDF suitable for a 8.5x11 PDF
      isprint = false
      print "\tParsing markdown... "
      latex = IO.popen('pandoc -p --no-wrap -f markdown -t latex', 'w+') do |pipe|
        pipe.write(pre_pandoc(markdown, config, isprint))
        pipe.close_write
        post_pandoc(pipe.read, config, isprint)
      end
      puts "done"

      print "\tCreating riaklil-#{lang}.tex... "
      dir = "#$here/rendered"
      File.open("#{dir}/riaklil-#{lang}.tex", 'w') do |file|
        file.write(template.result(binding))
      end
      puts "done"

      abort = false
      puts "\tRunning XeTeX:"
      # cd($root)
      3.times do |i|
        print "\t\tPass #{i + 1}... "
        IO.popen("xelatex -papersize=letter -output-directory=\"#{dir}\" \"#{dir}/riaklil-#{lang}.tex\" 2>&1") do |pipe|
          unless $DEBUG
            if $_[0..1]=='! '
              puts "failed with:\n\t\t\t#{$_.strip}"
              puts "\tConsider running this again with --debug."
              abort = true
            end while not abort and pipe.gets
          else
            STDERR.print while pipe.gets rescue abort = true
          end
        end
        break if abort
        puts "done"
      end

      ### Output a PDF suitable for a 6x9 print book 
      isprint = true
      print "\tParsing markdown for print... "
      latex = IO.popen('pandoc -p --no-wrap -f markdown -t latex', 'w+') do |pipe|
        pipe.write(pre_pandoc(markdown, config, isprint))
        pipe.close_write
        post_pandoc(pipe.read, config, isprint)
      end
      puts "done"

      print "\tCreating riaklil-print-#{lang}.tex... "
      dir = "#$here/rendered"
      File.open("#{dir}/riaklil-print-#{lang}.tex", 'w') do |file|
        file.write(template.result(binding))
      end
      puts "done"

      3.times do |i|
        print "\t\tPass #{i + 1}... "
        IO.popen("xelatex --debug -papersize=letter -output-directory=\"#{dir}\" \"#{dir}/riaklil-print-#{lang}.tex\" 2>&1") do |pipe|
          unless $DEBUG
            if $_[0..1]=='! '
              puts "failed with:\n\t\t\t#{$_.strip}"
              # puts "\tConsider running this again with --debug."
              abort = true
            end while not abort and pipe.gets
          else
            STDERR.print while pipe.gets rescue abort = true
          end
        end
        break if abort
        puts "done"
      end
    end
  end
end


def gen_html(language, published=false)
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
  prelude = markdown.render(File.read("#{language}/prelude.pmd"))
  if published
    html = "<html><head><title>A Little Riak Book</title></head><meta charset=\"utf-8\"><link href=\"style.css\" media=\"screen\" rel=\"stylesheet\" type=\"text/css\"><link href='http://fonts.googleapis.com/css?family=Playfair+Display' rel='stylesheet' type='text/css'><body>#{prelude}#{toc}#{html}</body></html>"
    full_file = "#{OUTPUT_DIR}/book-#{language}.html"
  else
    html = "<html><head><title>A Little Riak Book</title></head><meta charset=\"utf-8\"><body>#{prelude}#{toc}#{html}</body></html>"
    full_file = "#{OUTPUT_DIR}/riaklil-#{language}.html"
  end
  File.open(full_file, 'w') {|f| f.write(html) }
  full_file
end

def gen_book(language, html_file, format)
  system('ebook-convert', html_file, "#{OUTPUT_DIR}/riaklil-#{language}.#{format}",
    '--language', language,
    '--authors', 'Eric Redmond',
    '--comments', "Licensed under the Creative-Commons Attribution-Noncommercial-Share Alike 3.0 Unported",
    '--cover', 'assets/cover.png',
    '--extra-css', 'assets/style.css',
    '--tags', 'riak,free',
    '--level1-toc', '//h:h1',
    '--level2-toc', '//h:h2',
    '--smarten-punctuation')
end


## Run the generators for the given language

languages = [ARGV[0] || "en"]

# generate the pdf
gen_pdf(languages)

# generate the ebooks
languages.each do |language|
  formats = %w{mobi epub}

  html_file = gen_html(language)
  formats.each do |format|
    gen_book(language, html_file, format)
  end

  gen_html(language, true)
end