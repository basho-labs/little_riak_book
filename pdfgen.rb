#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# Pulled from https://github.com/progit/progit
require 'fileutils'
require 'erb'
require 'yaml'

include FileUtils

$here = File.expand_path(File.dirname(__FILE__))
$root = $here #File.join($here, '..')
$outDir = File.join($root, 'pdf')

$figures = {
  'replication' => '2.1',
  'partitions' => '2.2',
  'replpart' => '2.3',
  'ring0' => '2.4',
  'ring1' => '2.5',
  'top' => '4.1',
  'riak-stack' => '4.2',
  'riak-stack-erlang' => '4.3',
  'riak-stack-core' => '4.4',
  'riak-stack-kv' => '4.5',
  'riak-stack-pipe' => '4.6',
  'riak-stack-yokozuna' => '4.7',
  'riak-stack-backend' => '4.8',
  'riak-stack-api' => '4.9',
  'control-snapshot' => '4.10',
  'control-cluster' => '4.11',
}

def figures(&block)
  begin
    Dir["#$root/assets/*.pdf","#$root/assets/*.png"].each do |file|
      assetname = file.sub(/.*?\/assets\/(.*?)\.\w{3}$/, '\1')
      next unless figure = $figures[assetname]
      cp file, file.sub(/assets\/(.*?)\.\w{3}/, "figures/#{figure}.png")
    end
    block.call
  ensure
    Dir["#$root/figures/*"].each do |file|
      rm(file)
    end
  end
end

def usage
  puts <<USAGE
Usage:
  makepdf [OPTION...] LANGUAGE [LANGUAGE 2...]

Options:
  -d, --debug      prints TeX and other output
USAGE
  exit
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

def pre_pandoc(string, config)
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

    # Turns URLs into clickable links
    s %r{\`(http:\/\/[A-Za-z0-9\/\%\&\=\-\_\\\.]+)\`}, '<\1>'
    s %r{(\n\n)\t(http:\/\/[A-Za-z0-9\/\%\&\=\-\_\\\.]+)\n([^\t]|\t\n)}, '\1<\2>\1'

    # Process figures
    # s /Insert\s18333fig\d+\.png\s*\n.*?\d{1,2}-\d{1,2}\. (.*)/, 'FIG: \1'
    s /^\!\[(.*?)\]\((.*?)\)/, 'FIG: \1'
  end
end

def post_pandoc(string, config)
  replace(string) do
    space = /\s/

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
    s /#{config['fig'].gsub(space, '\s')}\s*(\d+)\-\-(\d+)/, '\imgref{\1.\2}'
    s /#{config['tab'].gsub(space, '\s')}\s*(\d+)\-\-(\d+)/, '\tabref{\1.\2}'
    s /#{config['prechap'].gsub(space, '\s')}\s*(\d+)(\s*)#{config['postchap'].gsub(space, '\s')}/, '\chapref{\1}\2'

    # Miscellaneous fixes
    s /FIG: (.*)/, '\img{\1}'
    s '\begin{enumerate}[1.]', '\begin{enumerate}'
    s /(\w)--(\w)/, '\1-\2'
    s /``(.*?)''/, "#{config['dql']}\\1#{config['dqr']}"

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

    # Shaded verbatim block
    s /(\\begin\{verbatim\}.*?\\end\{verbatim\})/m, '\begin{shaded}\1\end{shaded}'
    # s /\\begin\{shaded\}(.*?)\\end\{shaded\}/im, '\1'
    # s /\\begin\{highlighting\}(?:\[\])?(.*?)\\end\{highlighting\}/im, '\1'
  end
end

languages = [ARGV[0] || "en"]

$config = YAML.load_file("#$here/tex.yml")
template = ERB.new(File.read("#$here/template.tex"))

missing = ['pandoc', 'xelatex'].reject{|command| command_exists?(command)}
unless missing.empty?
  puts "Missing dependencies: #{missing.join(', ')}."
  puts "Install these and try again."
  exit
end

figures do
  languages.each do |lang|
    config = $config['default'].merge($config[lang]) rescue $config['default']

    puts "#{lang}:"
    markdown = Dir.glob("#$root/#{lang}/*.md").sort.map do |file|
      File.read(file)
    end.join("\n\n")

    print "\tParsing markdown... "
    latex = IO.popen('pandoc -p --no-wrap -f markdown -t latex', 'w+') do |pipe|
      pipe.write(pre_pandoc(markdown, config))
      pipe.close_write
      post_pandoc(pipe.read, config)
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
      IO.popen("xelatex -output-directory=\"#{dir}\" \"#{dir}/riaklil-#{lang}.tex\" 2>&1") do |pipe|
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
  end
end
