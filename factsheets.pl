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

# remove trailing slash added by <TAB>
$in_dir =~ s{/$}{};

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

    # Some very ticklish rules dealing with what will be the page title

    my $heading = $record->findvalue("item[\@name='heading']/value");
    unless ($heading) {
        # Take title without " Fact Sheet" suffix if heading is missing
        $heading = $record->findvalue("item[\@name='title']/value");
        $heading =~ s/ *Fact Sheet$//g;
    } else {
        # The heading is pretty messy...
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
    }

    my $mdate = $record->findvalue("item[\@name='permanence']/value/item[\@name='date_modified']/value");
    unless ($mdate) {
        return item_not_found($name, $fullpath, "last modification date");
    }

    my $header;
    foreach ($record->findnodes("item[\@name='header']/value")) { $header = $_; last; }
    unless ($header) {
        return item_not_found($name, $fullpath, "header");
    }

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

    # What is below could be combined into a single XPath expression at the expense of defining
    # what's going on here.  This way also validates that all there is Generic content in pagecontent

    my $body;
    my $unsupported; 
    foreach my $pageitem ($record->findnodes("item[\@name='pagecontent']/value/item")) {
        if ($pageitem->getAttribute('name') ne 'Generic') {
            $unsupported = 1;
        } else {
            foreach my $content ($pageitem->findnodes("value/item[\@name='content']/value/text()")) {
                $body .= $content->getData();
            }
        }
    }
    if ($unsupported) { 
        return item_has_unsupported_content($name, $fullpath, "pagecontent");
    }
    if (! $body) { 
        return item_not_found($name, $fullpath, "generic content");
    }

    # body contains some boiler plate text that we will remove and make automatic, via Custom Content
    # In a production migrate, probably worth using XML::LibXML to parse this as HTML content, and then 
    # navigate it that way.  The below is pretty dangerous...

    if ($body =~ m{<p><strong>For information on NLM services, contact}) {
       # Take prematch
       $body = $`;
    } elsif ($body =~ m{<p><strong>A complete list of NLM Fact Sheets}) {
       # Take prematch
       $body = $`;
    }

    # This is needed to again escape the HTML
    my $textnode = XML::LibXML::Text->new($body);
    $body = $textnode->toString();

    # validate that secondary content is empty
    foreach my $secondary ($record->findnodes("item[\@name='secondaryContent']/value")) {
        $unsupported = 1;
    }
    if ($unsupported) {
        return item_has_unsupported_content($name, $fullpath, "secondaryContent");
    }

    print "  <factsheet>\n";
    print "    <source>$fullpath</source>\n";
    print "    <dcrname>$name</dcrname>\n";
    print "    <alias>$alias</alias>\n";
    print "    <title>$heading</title>\n";
    print "    <modified>$mdate</modified>\n";
    print "    <ui>$ui</ui>\n" if defined $ui;
    print "    <class>$class</class>\n" if defined $class;
    print "    <body>$body</body>\n";
    print "  </factsheet>\n";
}

sub item_not_found {
    my ($name, $fullpath, $whatsmissing) = @_;
    print STDERR qq{Unable to process record name="$name" from $fullpath - $whatsmissing not found\n};
    return undef;
}

sub item_has_unsupported_content {
    my ($name, $fullpath, $where) = @_;
    print STDERR qq{Unable to process record name="$name" from $fullpath - unsupported content in $where\n};
    return undef;
}

