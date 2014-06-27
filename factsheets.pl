#!/usr/bin/env perl
use strict;
use warnings;

use XML::LibXML;

sub usage {
    print STDERR "Usage: $0 input-aliases-file input-dir output-dir\n";
    exit 1;
}

&usage unless int(@ARGV) == 3;
my ($in_aliases, $in_dir, $out_dir) = @ARGV;
&usage unless -f $in_aliases;
&usage unless -d $in_dir;
&usage unless -d $out_dir;


##
# Aliases CSV has the following format without a header row:
#      dcr,alias
# It encodes information about the URL that is to be output
#
print "Processing Aliases ...\n";
my $dcr_to_alias = {};
open ALIASES, "<$in_aliases" or die "Unable to read `$in_aliases': $!";
while (<ALIASES>) {
    chomp;
    my ($dcrfile, $aliaspath) = split(/,/);
    $dcr_to_alias->{$dcrfile} = $aliaspath;
}
close ALIASES;
print "SUCCESS\n\n";


print "Processing DCRs ...\n";
opendir INPUTDIR, $in_dir or die "Unable to open input directory `$in_dir': $!";
my @dcrs = grep { /\.dcr$/ } readdir INPUTDIR;
closedir INPUTDIR;

foreach my $dcr (@dcrs) {
    my $fullpath = "$in_dir/$dcr";
    unless (open(DCRFILE, "<$fullpath")) {
        print STDERR "Skipping $in_dir/$dcr - cannot open file for reading\n";
    } else {
        # maybe need to catch an XML error here -- add a bad file here
        my $dom;
        eval {
           $dom = XML::LibXML->load_xml({IO => *DCRFILE{IO}});
        };
        if ($@) {
           print STDERR "XML syntax error on `$in_dir/$dcr': $@";
        } elsif (!$dom) {
           print STDERR "XML DOM missing for `$in_dir/$dcr': $@";
        } else {
            &process_dcr($dcr, $dom, $dcr_to_alias->{$dcr});
        }

        close DCRFILE;
    }
}
print "SUCCESS\n\n";

sub process_dcr {
    my ($dcr, $dom, $alias) = @_;
    if ($alias) {
        print "$alias => $dcr\n";
    } else {
        print "? => $dcr\n";
    }
}

