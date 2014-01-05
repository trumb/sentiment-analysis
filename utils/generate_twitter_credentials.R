#!/usr/bin/env R
# R utility to generate a credentials file for a Twitter application.
# Usage: source from within R.
#        source('utils/generate_twitter_credentials.R')
# (c) Copyright 2014 mkfs (https://github.com/mkfs)
# NOT FOR REDISTRIBUTION

library(twitteR)

# ----------------------------------------------------------------------
# Prompt for Consumer key and Secret
cat("Obtain consumer key and secret for Twitter application-only auth here:")
cat("https://dev.twitter.com/docs/auth/application-only-auth")
twitter.consumer.key  <- readline('Consumer Key: ')
print(paste('KEY:', twitter.consumer.key))
twitter.consumer.secret  <- readline('Consumer Secret: ')
print(paste('SECRET:', twitter.consumer.secret))
# NOTE: The above can be replaced by hard-coding the consumer key and secret:
# twitter.consumer.key  <- ''
# twitter.consumer.secret <- ''

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
# Note: This will prompt the user for a PIN from a provided URL
twitter.credentials$handshake()
# Save OAuth token to file
save(twitter.credentials, file="twitter_credentials.RData")
