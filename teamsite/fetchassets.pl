#!/usr/bin/env perl
use strict;
use warnings;

use Getopt::Long;
use File::Basename qw/dirname basename/;
use HTML::TreeBuilder;
use LWP::UserAgent;
use File::Path qw/make_path/;
use URI;

## Verbose Output ##

my $verbose;
sub verbose {
    if ($verbose) {
        print STDERR join(' ', @_)."\n";
    }
}

## Progress ##

my $show_progress;
my $progress_counter = 0;

sub progress {
    if ($show_progress) {
        print ".";
        STDOUT->flush;
        if (++$progress_counter > 80) {
            print "\n";
            $progress_counter = 0;
        }
    }
}

## Inputs ##

sub usage {
    print STDERR "Usage: $0 [ -input <path-to-input-file> ] [ -directory <path-to-output-directory> ]\n";
    print STDERR "    -input defaults to STDIN\n";
    print STDERR "    -directory defaults to \"assets\", the directory must exist\n";
    print STDERR "    -v means print verbose output\n";
    print STDERR "    -progress prints .... until its done\n";
    exit 1;
}
GetOptions("input=s" => \my $inpath,
           "v" => \$verbose,
           "progress" => \$show_progress,
           "directory=s" => \my $outdir) or &usage;

## Validate input file ##

my $infh;
if ($inpath) {
   open($infh, "<", $inpath) or die "Cannot read `$inpath': $!\n";
} else {
   $infh = *STDIN;
}

## Validate directory ##

$outdir || ($outdir = "assets");
(-d $outdir && -w $outdir) || die "Directory `$outdir' must exist and be writeable: $!\n";

## Create User Agents ##

my $ua = LWP::UserAgent->new;
$ua->timeout(5);

## Path to assets that are relative paths ##

my %assets = ();

## Path to anchors that are relative paths which *may* or *maynot* be assets, like file attachments ##

my %visited = ();

## Process one url per line of input ##

&readurls;

sub readurls {
    while (my $url = <$infh>) {
        $url =~ s/#.*$//;    # ignore comments
            $url =~ s/\s*$//;    # right trim stronger than chomp
            next if ($url eq '');        # skip blank lines
            my $baseuri = URI->new($url);

        my $r = $ua->get($url);
        unless ($r->is_success) {
            warn "Unable to get `$url`: ".$r->code." - ".$r->message;
        } elsif ($r->content_type !~ /html/) {
            warn "content type of `$url' is not html: ".$r->content_type;
        } else {
            &handle_html($baseuri, $r);
        }
        verbose "visited $url";
        progress;
    }
}
        
## Handle successfully returned HTML ##

sub handle_html {
    my ($baseuri, $r) = @_;
    my $tree = HTML::TreeBuilder->new_from_content($r->content);

    # handle relative anchors - we want to keep non-HMTL links, but we want to visit them only once
    foreach my $a ($tree->find('a')) {
        my $href = $a->attr('href');
        if ($href) {
            $href =~ s/[#?].*$//;               # throw-out a local anchor and the query string
            next unless $href ne '';            # skip if this is a link to ourself

            my $uri = URI->new($href);
            unless (defined $uri->scheme) {
                my $absuri = $uri->abs($baseuri);
                unless ($visited{$absuri->as_string}) {
                    $visited{$absuri->as_string} = 1;
                    my $r2 = $ua->get($absuri);
                    if ($r2->is_success and $r2->content_type !~ /html/) {
                        $assets{$absuri->as_string} = 1;
                    }
                }
            }
        }
    }

    # handle relative images
    foreach my $img ($tree->find('img')) {
        my $src = $img->attr('src');
        if ($src) {
            my $uri = URI->new($src);
            unless (defined $uri->scheme) {
                my $abspath= $uri->abs($baseuri)->as_string;
                $assets{$abspath} = 1;
            }
        }
    }

    # handle relatively linked scripts
    foreach my $script ($tree->find('script')) {
        my $src = $script->attr('src');
        if ($src) {
            my $uri = URI->new($src);
            unless (defined $uri->scheme) {
                my $abspath = $uri->abs($baseuri)->as_string;
                $assets{$abspath} = 1;
            }
        }
    }

    # handle relatively linked stylesheets
    foreach my $link ($tree->find('link')) {
        my $rel = $link->attr('rel');
        if ('stylesheet' eq $rel) {
            my $href = $link->attr('href');
            if ($href) {
                my $uri = URI->new($href);
                unless (defined $uri->scheme) {
                    my $abspath= $uri->abs($baseuri)->as_string;
                    $assets{$abspath} = 1;
                }
            }
        }
    }
}


## Get each asset and store it in the ouptut directory ##
&fetchassets( keys %assets );

sub fetchassets {
    foreach my $asset (@_) {
        my $r = $ua->get( $asset );
        unless ($r->is_success) {
            warn "Unable to get `$asset`: ".$r->code." - ".$r->message;
        } elsif ($r->content_type =~ /html/) {
            warn "content type of `$asset' is html: ".$r->content_type;
        } else {
            my $uri = URI->new ($asset);
            my $locpath = $outdir . "/" . $uri->host . $uri->path;
            make_path(dirname($locpath));
            open(ASSET, '>', $locpath) or die "unable to write `$locpath': $!";
            print ASSET $r->content;
            close ASSET;
        }
        verbose "fetched $asset";
        progress;
    }
}


