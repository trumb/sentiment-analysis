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

# convert R data frames to Ruby dataframes
#require 'dataframe'
#theR.class_table['data.frame'] = lambda{|x| DataFrame.new(x)}
#RSRuby.set_default_mode(RSRuby::CLASS_CONVERSION)

module SentimentR

  def self.initialize_r
    ENV['R_HOME'] ||= detect_r
    @r = RSRuby.instance
    fix_graphics
    @r.eval_R("suppressMessages(library('tm.plugin.webmining'))")
    @r.eval_R("suppressMessages(library('tm.plugin.sentiment'))")
  end

  def self.detect_r
    # TODO: actually attempt to detect if R is installed
    case RUBY_PLATFORM
    when /win32/ 
      'C:/Program Files/R'  # probably wrong
    when /linux/
      '/usr/lib/R'
    when /darwin/
      '/Library/Frameworks/R.framework/Resources'
    when /freebsd/
      '/usr/local/lib/R'  # probably wrong
    else
      ''
    end
  end

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

  def self.sentiment_analysis(opts)
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

  def self.sentiment_query(query_str, opts)
    rv = nil
    begin
      @r.eval_R("corpus <- WebCorpus(#{query_str})")
      @r.eval_R('corpus <- score(corpus)')
      rv = @r.eval_R('scores <- meta(corpus)')
      rv = calculate_summary(opts.summary_func) if opts.summary_func
    rescue RException => e
      $stderr.puts "ERROR IN QUERY #{query_str.inspect}"
      $stderr.puts e.message
      $stderr.puts e.backtrace[0,3]
    end
    rv || {}
  end

  def self.calculate_summary(fn)
    @r.eval_R("v <- sapply(colnames(scores), function(x) #{fn}(scores[,x]) )")
    @r.eval_R('as.list(v)')
  end

  # ----------------------------------------------------------------------

  ENGINES = {
    :google_blog => 'GoogleBlogSearchSource',
    :google_finance => 'GoogleFinanceSource',
    :google_news => 'GoogleNewsSource',
    #:nytimes => 'NYTimesSource', # appid = user_app_id
    #:reutersnews => 'ReutersNewsSource', # query: businessNews
    #:twitter => 'TwitterSource',
    :yahoo_finance => 'YahooFinanceSource',
    :yahoo_inplay => 'YahooInplaySource',
    :yahoo_news => 'YahooNewsSource'
  }

  def self.build_query(engine, term)
    # TODO: support for nytimes, twitter, reuters
    "#{ENGINES[engine]}('#{term}')"
  end

  # ----------------------------------------------------------------------

  def self.output_sentiment(term_scores, opts)
    return JSON.pretty_generate(term_scores) if opts.output == :json_raw

    lines = []
    header = nil
    term_scores.each do |term, h|
      header ||= h.keys.sort - ['engine']
      lines += header.map { |k| [h[k]].flatten }.transpose.map { |a| 
                                a.unshift h['engine']; a.unshift term }
    end
    header.unshift 'engine'
    header.unshift 'keyword'
    lines.unshift header

    opts.output == :pipe_table ? lines.map { |line| line.join('|') } :
                                 JSON.pretty_generate(lines)
  end

  def self.handle_options(args)

    options = OpenStruct.new
    options.engines = []
    options.query_terms = []
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
      #opts.on('-t', '--twitter', 'Twitter') { options.engines << :twitter }

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
  SentimentR.initialize_r
  results = SentimentR.sentiment_analysis options
  puts SentimentR.output_sentiment(results, options)
end

__END__
Sentiment analysis noted:

  http://icwsm.org/papers/3--Godbole-Srinivasaiah-Skiena.pdf
  http://statmath.wu.ac.at/courses/SNLP/Presentations/DA-Sentiment.pdf

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

