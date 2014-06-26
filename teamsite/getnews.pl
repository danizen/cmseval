#!/usr/bin/env perl
use strict;
use warnings;

use Getopt::Long;
use WWW::Mechanize;

#---------------------------
#          OPTIONS
#----------------------------

sub usage {
    print STDERR "Usage: $0 [ -print perl-regex ] [ -follow perl-regex ] seed\n";
    exit 1;
}
GetOptions("print=s" => \my $printre,
           "follow=s" => \my $followre) || &usage;
int(@ARGV) == 1 or &usage;
my $seed = $ARGV[0];

#---------------------------
#          PROCESSING
#----------------------------

my $mech = WWW::Mechanize->new;
my @queue = ( $seed );
my @done = ( );

while (int(@queue) > 0) {
    my $url = pop @queue;
    push @done, $url;

    if (!$print or $url =~ /$print/i) {
        print STDOUT "$url\n";
    }

    $mech->get( $url );

    if ($mech->is_html()) {
        foreach my $link ($mech->links) {
            if (!$follow or $link->url_abs =~ /$follow/i) {
                push @queue, $link;
            }
        }
    }
}

