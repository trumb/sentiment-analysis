#!/usr/bin/env R
# R module for Twitter developer API

# IMPORTANT: set these to your Twitter application OAuth consumer key and secret
twitter.consumer.key = ''
twitter.consumer.secret = ''

# ----------------------------------------------------------------------
Rurl <- "https://api.twitter.com/oauth/request_token"
ACurl <- "https://api.twitter.com/oauth/access_token"
AUurl <- "https://api.twitter.com/oauth/authorize"

# Generate 
twitter.credentials <- OAuthFactory$new(consumerKey=twitter.consumer.key, 
		                        consumerSecret=twitter.consumer.secret, 
		                        requestURL =  Rurl,
		                        accessURL = ACurl,
		                        authURL = AUurl )
  
# Complete OAUTH authentication handshake
twitter.credentials$handshake()
# Save OAuth token to file
save(twitter.credentials, file="twitter_credentials.RData")
