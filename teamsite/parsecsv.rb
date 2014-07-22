#!/usr/bin/env ruby
require 'csv'
require 'uri'
require 'net/http'

if (ARGV.size != 1) 
	STDERR.puts "Usage: #{$0} CSV_path"
	exit 1
end

http = Net::HTTP.new "drupal-eval.nlm.nih.gov"

CSV.foreach ARGV[0] do |row|
	path = row[1]
	if (path != 'URL') 
   		path.sub! %r/\.html\Z/, ''
    	path.sub! %r/\Ahttp:\/\/www\.nlm\.nih\.gov\//, '/'
    	path.sub! %r/\Awww\.nlm\.nih\.gov\//, '/'

	    res = http.request_get path
	    unless (res.is_a? Net::HTTPSuccess)
	    	STDOUT.puts "http://www.nlm.nih.gov#{path}.html"
	    end
	end
end