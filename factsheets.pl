#!/usr/bin/env perl
use strict;
use warnings;

##
# @file
# This program producess from its inputs an XML output like this:
#
#    <?xml version="1.0" encoding="UTF-8"?>
#    <factsheets>
#      <factsheet>
#         <alias>alias path</alias>
#         <title>title text</title>
#         <ui>identifier</ui>
#         <class>identifier</class>
#         <body> escaped HTML fragment text... </body>
#      </factsheet>
#      ...
#    </factsheets>
#
# Only valid inputs are included in the output

use Getopt::Long;
use XML::LibXML;

##
# Usage
sub usage {
    print STDERR "Usage: $0 [-out output_file] input-aliases-file input-dir\n";
    exit 1;
}
GetOptions("out=s" => \my $out_file) or &usage;

&usage unless int(@ARGV) == 2;
my ($in_aliases, $in_dir) = @ARGV;

if ($out_file) {
    open(STDOUT, ">$out_file") or die "Unable to write '$out_file': $!";
}


##
# Aliases CSV has the following format without a header row:
#      dcr,alias
# It encodes information about the URL that is to be output
#
my $dcr_to_alias = {};
open ALIASES, "<$in_aliases" or die "Unable to read `$in_aliases': $!";
while (<ALIASES>) {
    chomp;
    my ($dcrfile, $aliaspath) = split(/,/);
    $dcr_to_alias->{$dcrfile} = $aliaspath;
}
close ALIASES;


opendir INPUTDIR, $in_dir or die "Unable to open input directory `$in_dir': $!";
my @infiles = grep { /\.(dcr|xml)$/ } readdir INPUTDIR;
closedir INPUTDIR;

print qq{<?xml version="1.0" encoding="UTF-8"?>\n};
print qq{<factsheets>\n};

foreach my $file (@infiles) {
    my $fullpath = "$in_dir/$file";
    unless (open(XMLFILE, "<$fullpath")) {
        print STDERR "Skipping $fullpath - cannot open file for reading\n";
    } else {
        # maybe need to catch an XML error here -- add a bad file here
        my $doc;
        eval {
            $doc = XML::LibXML->load_xml({IO => *XMLFILE{IO}});
        };
        if ($@) {
            print STDERR "XML syntax error on `$fullpath': $@";
        } elsif (!$doc) {
            print STDERR "XML DOM missing for `$fullpath': $@";
        } else {
            &process_doc($fullpath, $doc);
        }
        close XMLFILE;
    }
}
print qq{</factsheets>\n};

sub process_doc {
    my ($fullpath, $doc) = @_;
    foreach my $record ($doc->findnodes("//record[\@type='content']")) {
        my $name = $record->getAttribute('name');
        my $alias = $dcr_to_alias->{$fullpath};
        if (! $alias) {
            $alias = $dcr_to_alias->{$name};
        }
        if (! $alias) {
            print STDERR qq{Warning - no alias for $fullpath - taking automatic alias\n};
            $alias = $fullpath;
            $alias =~ s{^/}{};
            $alias =~ s{\.dcr$}{};
        }
        &process_dcr($fullpath, $record, $name, $alias);
    }
}

sub process_dcr {
    my ($fullpath, $record, $name, $alias) = @_;

    ## 
    # Some very ticklish rules dealing with the heading
    my $heading = $record->findvalue("item[\@name='heading']/value") or
        return item_not_found($name, $fullpath, "heading");
    my @lines = split(m{<br */>}, $heading);
    if (int(@lines) > 1) {
        $heading = join(' - ', splice(@lines, 1));
    } else {
        $heading = $lines[0];
    }
    $heading =~ s{&#174([^;])}{&#174;$1}g;
    $heading =~ s{&#174$}{&#174;}g;
    $heading =~ s{&reg;}{&#174;}g;
    $heading =~ s{</?[^>]*>}{}g;

    my $mdate = $record->findvalue("item[\@name='permanence']/value/item[\@name='date_modified']/value") or
        return item_not_found($name, $fullpath, "last modification date");

    my $header;
    foreach ($record->findnodes("item[\@name='header']/value")) { $header = $_; last; }
    $header or return item_not_found($name, $fullpath, "header");

    my ($ui, $class);
    foreach my $meta ($header->findnodes("item[\@name='metadata']/value/item[\@name='name']/value")) {
        my $field = $meta->findvalue("item[\@name='field']/value");
        if ($field) {
            if ($field eq "NLMDC.Identifier.BibUI") {
                $ui = $meta->findvalue("item[\@name='content']/value");
            } elsif ($field eq "NLMDC.Subject.NLMClass") {
                $class = $meta->findvalue("item[\@name='content']/value");
            }
        }
    }

    ## 
    # What is below could be combined into a single XPath expression at the expense of defining
    # what's going on here.
    my $body;
    foreach my $pagec ($record->findnodes("item[\@name='pagecontent']/value")) {
        foreach my $generic ($pagec->findnodes("item[\@name='Generic']/value")) {
            foreach my $content ($generic->findnodes("item[\@name='content']/value/text()")) {
                $body .= $content->getData();
            }
        }
    }
    $body or return item_not_found($name, $fullpath, "first column content");
    my $textnode = XML::LibXML::Text->new($body);
    $body = $textnode->toString();

    print "  <factsheet>\n";
    print "    <source>$fullpath</source>\n";
    print "    <dcrname>$name</dcrname>\n";
    print "    <alias>$alias</alias>\n";
    print "    <title>$heading</title>\n";
    print "    <mod_date>$mdate</mod_date>\n";
    print "    <ui>$ui</ui>\n" if defined $ui;
    print "    <class>$class</class>\n" if defined $class;
    print "    <body>$body</body>\n";
    print "  </factsheet>\n";
}

sub item_not_found {
    my ($name, $fullpath, $whatsmissing) = @_;
    print STDERR qq{Unable to process record with name="$name" from $fullpath - $whatsmissing not found\n};
    return undef;
}

