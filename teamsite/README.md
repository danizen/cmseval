# Web Properties from TeamSite #

## Description ##

These scripts crawl the web sites built from TeamSite and extract a minimal set of pages
needing to be prototyped in the CMS Evaluation.   The code is simple bash/wget/sed 

## Input ##

The input is really encoded into two scripts and a file:

        must-haves
        crawl-nlmmain
        crawl-nihseniorhealth

## Output ##

The output is a file of URLS, one per line:
        
        all-urls

You run it using `make`, and clean up using `make clean` or `make purge`

If that does not work (you have bash/sed but not make?), try:

        cat Makefile

## Fetch Assets ##

Another thing you can do is to later go back and get the relative assets for all these pages.
There may be someway to do just the relative assets, but I wanted to capture CSS sprites,
and anchors that are files.

        mkdir assets
        ./fetchassets -input all-urls

## Author ##

Dan Davis, daniel.davis@nih.gov

