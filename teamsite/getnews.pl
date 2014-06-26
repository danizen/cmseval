#!/usr/bin/env perl
use strict;
use warnings;

use Getopt::Long;
use WWW::Mechanize;

#---------------------------
#          OPTIONS
#----------------------------

sub usage {
    print STDERR "Usage: $0 [ -follow perl-regex ] seed\n";
    exit 1;
}
#GetOptions("print=s" => \my $printre,
#           "follow=s" => \my $followre) || &usage;
#my $printre = 'www\.nlm\.nih\.gov/news';
my $followre = 'www\.nlm\.nih\.gov/news.*\.html$';
int(@ARGV) == 1 or &usage;
my $seed = $ARGV[0];

#---------------------------
#          PROCESSING
#----------------------------

my @queue = ( $seed );
my $all = { $seed => 0 };

while (int(@queue) > 0) {
    my $url = pop @queue;

    my $mech = WWW::Mechanize->new;
    eval {
        $mech->get( $url );
        $all->{$url} = 1;
    };
    if ($all->{$url} == 1) {
        print STDOUT "$url\n";
    } else {
        print STDERR "$url not found\n";
    }

    if ($mech->is_html()) {
        foreach my $link ($mech->links) {
            if (!$followre or $link->url_abs =~ m{$followre}i) {
                unless ( defined $all->{$link->url_abs} ) {
                    push @queue, $link->url_abs;
                    $all->{$link->url_abs} = 0;
                }
            }
        }
    }
}

