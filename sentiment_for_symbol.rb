#!/usr/bin/env ruby
# Perform sentiment analysis on web engine search results
# Usage: sentiment_for_symbol.rb [options] KEYWORD [...]
# (c) Copyright 2013 mkfs (https://github.com/mkfs)
# NOT FOR REDISTRIBUTION

require 'ostruct'
require 'optparse'

require 'rubygems'
require 'json/ext'
require 'rsruby'

# TODO: clean corpus before sending to sentiment

$DEBUG = false

=begin rdoc
Sentiment Analysis methods that require R.

R_HOME : top-level directory of the R installation to run
=end
module SentimentR

  def self.initialize_r(opts)
    # set R_HOME to location of R install
    ENV['R_HOME'] ||= (opts.dir || detect_r)
    if ! (File.exist? ENV['R_HOME'].to_s)
      raise "Use --r-dir or set R_HOME to R install directory"
    end

    @r = RSRuby.instance
    fix_graphics

    $stderr.puts "Loading package 'tm'" if $DEBUG
    @r.eval_R("suppressMessages(library('tm'))")

    $stderr.puts "Loading package 'tm.plugin.webmining'" if $DEBUG
    @r.eval_R("suppressMessages(library('tm.plugin.webmining'))")

    $stderr.puts "Loading package 'tm.plugin.sentiment'" if $DEBUG
    @r.eval_R("suppressMessages(library('tm.plugin.sentiment'))")

    # Define a replacement Twitter source as the webmining one is broken
    define_twitter_source if opts.engines.include? :twitter

    # Load the credentials in the specified file (required for Twitter)
    if opts.ident_file
      $stderr.puts "Loading credentials file '#{opts.ident_file}'" if $DEBUG
      @r.eval_R("load('#{opts.ident_file}')")
    end
  end

=begin rdoc
Defines the R function TwitteRSource, which uses the twitteR package and
pre-loaded twitter application OAuth credentials in order to perform a
search on the query. The return value of the R function is a tm VectorSource 
object.
=end
  def self.define_twitter_source
    $stderr.puts "Loading package 'twitteR'" if $DEBUG
    @r.eval_R("suppressMessages(library('twitteR'))")

    $stderr.puts "Defining function 'TwitteRSource'" if $DEBUG
    @r.eval_R("TwitteRSource <- function(query, n=1500, 
                                         params=list(lang='en'), ...) {
               dbg <- #{$DEBUG.to_s.upcase}

               if (! exists('twitter.credentials') ) {
                 write('twitter.credentials object is not defined!', stderr())
                 # return an empty results object
                 return( VectorSource(c('')) )
               }

               if (dbg) write('Authenticating twitter via OAuth', stderr())
               registerTwitterOAuth(twitter.credentials)

               if (dbg) write(paste('Sending query \"', query, '\"', sep=''), 
                              stderr())
               lst <- searchTwitter(query, n=n, lang=params$lang)
               VectorSource( sapply(lst, function(x) x$text) )
              }")
  end

=begin rdoc
Detect the install location of R on *NIX using the `which` command.
=end
  def self.detect_unix_r
    path = `which R`
    return nil if (! path) || path.empty?

    path = File.join( path.split('/bin/R')[0], 'lib', 'R' )
    (File.exist? path) ? path : nil
  end

=begin rdoc
Return the top-level directory of the system R installation.
=end
  def self.detect_r
    # TODO: actually attempt to detect if R is installed
    case RUBY_PLATFORM
    when /win32/ 
      'C:/Program Files/R'  # probably wrong
    when /linux/, /freebsd/
      detect_unix_r || '/usr/lib/R'
    when /darwin/
      '/Library/Frameworks/R.framework/Resources'
    when /freebsd/
      detect_unix_r || '/usr/local/lib/R'  # probably wrong
    else
      nil
    end
  end

=begin rdoc
Some R graphics subsystems don't play nice on the command line. This fixes that.

Note: This is only necessary if plotting to a widget.
=end
  def self.fix_graphics
    fix = nil
    case RUBY_PLATFORM
    when /linux/, /freebsd/
      fix = 'graphics.off(); X11.options(type="Xlib")'
    when /darwin/
      fix = 'graphics.off(); X11.options(type="nbcairo")'
    end
    @r.eval_R(fix) if fix
  end
  
  # ----------------------------------------------------------------------

=begin rdoc
Perform a sentiment analysis using tm.plugins.webmining and tm.plugins.sentiment
=end
  def self.sentiment_analysis(opts)
    # FIXME : This should really just build a corpus for each term using all
    #         engines, then invoke the sentiment analysis on the corpus.
    terms = {}
    opts.query_terms.each do |term|
      terms[term] = {}
      terms[term]['engine'] = []

      opts.engines.each do |engine|
        terms[term]['engine'] << engine.to_s

        sentiment_query(build_query(engine, term), opts).each do |k,v| 
          next if k.to_s == 'MetaID'
          terms[term][k] ||= []
          terms[term][k] += [v].flatten.map { |x| (x.nan?) ? nil : x }

        end
      end
    end
    terms
  end

=begin rdoc
Perform a web query using tm.plugins.webmining, then sent the corpus to
tm.plugins.sentiment for scoring.
=end
  def self.sentiment_query(query_str, opts)
    rv = nil
    begin
      $stderr.puts "Evaluating " + "corpus <- WebCorpus(#{query_str})" if $DEBUG
      @r.eval_R("corpus <- WebCorpus(#{query_str})")

      $stderr.puts "Evaluating " + 'corpus <- score(corpus)' if $DEBUG
      @r.eval_R('corpus <- score(corpus)')

      $stderr.puts "Evaluating " + 'scores <- meta(corpus)' if $DEBUG
      rv = @r.eval_R('scores <- meta(corpus)')

      rv = calculate_summary(opts.summary_func) if opts.summary_func &&
                                                  (! rv.empty?)
    rescue RException => e
      $stderr.puts "ERROR IN QUERY #{query_str.inspect}"
      $stderr.puts e.message
      $stderr.puts e.backtrace[0,3]
    end
    rv || {}
  end

=begin rdoc
Invoke an R summary statistics method (such as mean or median) on the scores
dataframe.
=end
  def self.calculate_summary(fn)
    $stderr.puts "Evaluating " + 
      "v <- sapply(colnames(scores), function(x) #{fn}(scores[,x]) )" if $DEBUG
    @r.eval_R("v <- sapply(colnames(scores), function(x) #{fn}(scores[,x]) )")
    $stderr.puts "Evaluating " + 'as.list(v)' if $DEBUG
    @r.eval_R('as.list(v)')
  end

  # ----------------------------------------------------------------------

=begin rdoc
Supported search engines.
See http://cran.rstudio.com/web/packages/tm.plugin.webmining/tm.plugin.webmining.pdf
=end
  ENGINES = {
    :google_blog => 'GoogleBlogSearchSource',
    :google_finance => 'GoogleFinanceSource',
    :google_news => 'GoogleNewsSource',
    #:nytimes => 'NYTimesSource', # appid = user_app_id
    #:reutersnews => 'ReutersNewsSource', # query: businessNews
    #:twitter => 'TwitterSource', # BROKEN IN tm.plugin.webmining
    :twitter => 'TwitteRSource',
    :yahoo_finance => 'YahooFinanceSource',
    :yahoo_inplay => 'YahooInplaySource',
    :yahoo_news => 'YahooNewsSource'
  }

  IDENT_ENGINES = [ :nytimes, :twitter ]

=begin rdoc
Build a tm.plugins.webmining function invocation based on the engine and search
term.
=end
  def self.build_query(engine, term)
    # TODO: support for nytimes, reuters
    "#{ENGINES[engine]}('#{term}')"
  end

  # ----------------------------------------------------------------------

=begin rdoc
Return a string representing the sentiment analysis results.
This can be a JSON-serialized data structure (either a raw Hash, or an Array
representing a Table of data) or a pipe-delimited table.
=end
  def self.output_sentiment(term_scores, opts)
    return JSON.pretty_generate(term_scores) if opts.output == :json_raw

    lines = []
    header = nil
    term_scores.each do |term, h|
      next if h.empty?

      header ||= h.keys.sort - ['engine']
      engines = h['engine']
      lines += header.map { |k| [h[k]].flatten }.transpose.map { |a| 
                                a.unshift engines.shift; a.unshift term }
    end
    header.unshift 'engine'
    header.unshift 'keyword'
    lines.unshift header

    opts.output == :pipe_table ? lines.map { |line| line.join('|') } :
                                 JSON.pretty_generate(lines)
  end

  # ----------------------------------------------------------------------
  def self.handle_options(args)

    options = OpenStruct.new
    options.engines = []
    options.query_terms = []
    options.ident_file = nil
    options.r_dir = nil
    options.summary_func = nil
    options.output = :json_table

    opts = OptionParser.new do |opts|
      opts.banner = "Usage: #{File.basename $0} TERM [...]"
      opts.separator "Perform sentiment analysis on a web query for keyword"
      opts.separator ""
      opts.separator "Google Engines:"
      opts.on('-b', '--google-blog', 'Include Google Blog search') { 
              options.engines << :google_blog }
      opts.on('-f', '--google-finance', 'Include Google Finance search') { 
              options.engines << :google_finance }
      opts.on('-n', '--google-news', 'Include Google News search') { 
              options.engines << :google_news }

      opts.separator "Yahoo Engines:"
      opts.on('-F', '--yahoo-finance', 'Include Yahoo Finance search') { 
              options.engines << :yahoo_finance }
      opts.on('-I', '--yahoo-inplay', 'Include Yahoo InPlay search') { 
              options.engines << :yahoo_inplay }
      opts.on('-N', '--yahoo-news', 'Include Yahoo News search') { 
              options.engines << :yahoo_news }
      opts.on('-t', '--twitter', 'Twitter') { options.engines << :twitter }

      opts.separator "Summary Options:"
      opts.on('-m', '--median', 'Calculate median') { 
              options.summary_func = 'median' }
      opts.on('-M', '--mean', 'Calculate mean') { 
              options.summary_func = 'mean' }

      opts.separator "Output Options:"
      opts.on('-p', '--pipe-delim', 'Print pipe-delimited table output') { 
              options.output = :pipe_table }
      opts.on('-r', '--raw', 'Serialize output as a Hash, not an Array') { 
              options.output = :json_raw }

      opts.separator "Misc Options:"
      opts.on('-d', '--debug', 'Print debug output') { $DEBUG = true } 
      # TODO: appid for nytimes
      opts.on('--id str', 'ID or credentials file (e.g. twitter.RData') { |str|
        options.ident_file = str }
      opts.on('--r-dir str', 'Top-level directory of R installation') { |str|
        options.r_dir = str }
      opts.on_tail('-h', '--help', 'Show help screen') { puts opts; exit 1 }
    end

    opts.parse! args
    options.engines << :google_news if options.engines.empty?

    while args.length > 0
      options.query_terms << args.shift
    end

    if options.query_terms.empty?
      $stderr.puts 'SEARCH TERM REQUIRED'
      puts opts
      exit -1
    end

    options
  end
end

# ----------------------------------------------------------------------
if __FILE__ == $0
  options = SentimentR.handle_options(ARGV)
  SentimentR.initialize_r(options)
  results = SentimentR.sentiment_analysis options
  puts SentimentR.output_sentiment(results, options)
end

__END__

# Notes:
Subjectivity indicates proportion of sentiment to frequency of occurrence, 
while polarity indicates percentage of positive sentiment references among 
total sentiment references.

polarity:               p - n / p + n
          diff of positive/negative sentiment refs / total num of sentiment refs
sentiment:              p + n / N
          total num of sentiment references / total num of references
pos_refs_per_ref :      p / N
          total num of positive sentiment references / total num of references
neg_refs_per_ref :      n / N
          total num of negative sentiment references / total num of references
senti_diffs_per_ref :   p - n / N
          num positive references / total num of references

Median of these scores is best -- suppress outliers

# TODO: limit to sentences containing keyword
  library(openNLP)
  sentences <- sentDetect(text, language = "en")
  sentences <- sentences[grepl(keyword,sentences)]

# TODO: Limit to headline
  sapply(corpus, FUN=function(x){ attr(x,"Heading ") })

# TODO: Limit to description
  sapply(corpus, FUN=function(x) { attr(x,"Description") })

# TODO: output list of sentiment words
  library(tm.plugin.tags)

