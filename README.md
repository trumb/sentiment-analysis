#sentiment-analysis

Ruby and R scripts for performing sentiment analysis.


##sentiment-for-symbol

This utility performs one or more web searches, then calculates sentiment scores
on the results. These scores can be reported per-result (e.g. 10-20 scores per
search engine) or per-engine (e.g. the mean or median of the results). Output
is in JSON by default, but can be pipe-delimited.

Supported search engines:

	* Google News
	* Google Finance
	* Google Blog
	* Yahoo News
	* Yahoo Finance
	* Yahoo InPlay

###Usage:

	Usage: sentiment_for_symbol.rb TERM [...]
	Perform sentiment analysis on a web query for keyword

	Google Engines:
	    -b, --google-blog                Include Google Blog search
	    -f, --google-finance             Include Google Finance search
	    -n, --google-news                Include Google News search
	Yahoo Engines:
	    -F, --yahoo-finance              Include Yahoo Finance search
	    -I, --yahoo-inplay               Include Yahoo InPlay search
	    -N, --yahoo-news                 Include Yahoo News search
	Summary Options:
	    -m, --median                     Calculate median
	    -M, --mean                       Calculate mean
	Output Options:
	    -p, --pipe-delim                 Print pipe-delimited table output
	    -r, --raw                        Serialize output as a Hash, not an Array
	Misc Options:
	    -h, --help                       Show help screen
	
###Examples:

	# Output results for Google News search of 'Home Depot' and 'DeWalt'
	./sentiment_for_symbol.rb 'Home Depot' 'DeWalt'
	# Same, only results are in a pipe-delimited table
	./sentiment_for_symbol.rb -p 'Home Depot' 'DeWalt'
	# Use Yahoo News for the query
	./sentiment_for_symbol.rb -N -p 'Home Depot' 'DeWalt'
	# Use both Google News and Yahoo News for the query
	./sentiment_for_symbol.rb -N -n -p 'Home Depot' 'DeWalt'

	# Use Google Finance for stock symbols MSFT, AAPL and GOOG
	./sentiment_for_symbol.rb -f -p MSFT AAPL GOOG
	# Same, but report only the median value for each sentiment score
	./sentiment_for_symbol.rb -f -m -p MSFT AAPL GOOG
	# Same, but report the mean value instead of the median
	./sentiment_for_symbol.rb -f -M -p MSFT AAPL GOOG

	# Use twitter to search for string 'BlackBerry'
	# See Notes for en explanation of the --id parameter.
	./sentiment_for_symbol.rb -t --id twitter_credentials.RData BlackBerry

###Sentiment Analysis

The R plugin used in this script is based on the [Lydia/TextMap] (http://www/textmap.com) system.


  [TextMap Paper] (http://icwsm.org/papers/3--Godbole-Srinivasaiah-Skiena.pdf)

  [Presentation for tm.plugins.sentiment] (http://statmath.wu.ac.at/courses/SNLP/Presentations/DA-Sentiment.pdf)

The system calculates the following metrics:

  * polarity

	p - n / p + n
	> diff of positive/negative sentiment refs / total num of sentiment refs

  * sentiment

	p + n / N
	> total num of sentiment references / total num of references

  * pos_refs_per_ref

	p / N
	> total num of positive sentiment references / total num of references

  * neg_refs_per_ref

	n / N
	> total num of negative sentiment references / total num of references

  * senti_diffs_per_ref

	p - n / N
	> num positive references / total num of references


###Dependencies

  * [R] (http://www.r-project.org)
  * R package [tm.plugins.webmining] (http://cran.r-project.org/web/packages/tm.plugin.webmining/index.html)
  * R package [tm.plugins.sentiment] (https://r-forge.r-project.org/R/?group_id=1048)
  * R package [twitteR] (http://cran.r-project.org/web/packages/twitteR/index.html)
  * [rsruby] (https://github.com/alexgutteridge/rsruby)
   

###Notes

	* Reuters, and NY Times are disabled
	* Yahoo Finance appears to be broken in tm.plugins.webmining
	* Twitter is broken in tm.plugin.webmining, and has been implemented
	  using the TwitteR package. The authentication mechanism uses
	  Twitter's application-only OAuth authentication, documented here:
	    https://dev.twitter.com/docs/auth/application-only-auth
	  The OAuth credential must be generated in R and stored in a variable
	  named 'twitter.credentials', which is then serialized to an .RData
	  file. This file is passed using the --id parameter. Note that an
	  R script for creating this file is provided: 
	    utils/generate_twitter_credentials.R
	  Source this file from within R in order to generate the credentials
	  file twitter_credentials.RData in the working directory:
	    source('utils/generate_twitter_credentials.R')
	* Installing  rsruby can be tricky. Here is an example, using RVM
	  on a Linux system:

	sudo rvm all do gem install rsruby -- --with-R-home=/usr/lib/R --with-R-include=/usr/share/R/include
