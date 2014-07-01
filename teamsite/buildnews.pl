#!/usr/bin/env perl
use strict;
use warnings;

use Getopt::Long;
use File::Basename qw/dirname basename/;
use XML::LibXML;
use HTML::Tree;
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
    print STDERR "Usage: $0 [ -in <path-to-input-file> ] [ -out <path-to-output-xml> ] [ -type <article-type> ]\n";
    print STDERR "    -in ................. defaults to STDIN\n";
    print STDERR "    -out ................ defaults to STDOUT\n";
    print STDERR "    -type ............... string to guide taxonomy\n";
    print STDERR "    -v .................. means print verbose output\n";
    print STDERR "    -progress prints .... until its done\n";
    exit 1;
}
GetOptions("in=s" => \my $inpath,
           "out=s" => \my $outpath,
           "type=s" => \my $item_type,
           "v" => \$verbose,
           "progress" => \$show_progress) or &usage;

## Validate input file ##

my $infh;
if ($inpath) {
   open($infh, "<", $inpath) or die "Cannot read `$inpath': $!\n";
} else {
   $infh = *STDIN;
}

## Validate output file ##

my $outfh;
if ($outpath) {
   open($outfh, ">", $outpath) or die "Cannot write `$outpath': $!\n";
} else {
   $outfh = *STDOUT;
}
binmode($outfh, ":utf8");


## Create User Agents ##

my $ua = LWP::UserAgent->new;
$ua->timeout(5);

## Create the document we are building ##

my $doc = XML::LibXML::Document->new("1.0", "UTF-8");
my $newslist = $doc->createElement("newslist");
$doc->setDocumentElement($newslist);
$newslist->appendText("\n");

## Process one url per line of input ##

&readurls;
print $outfh $doc->toString();

## Get each url and process it

sub readurls {
    while (my $url = <$infh>) {
        $url =~ s/#.*$//;    # ignore comments
        $url =~ s/\s*$//;    # right trim stronger than chomp
        next if ($url eq '');        # skip blank lines
        my $baseuri = URI->new($url);

        my $r = $ua->get($url);                                # what about redirects to archive
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

    my $path_query = $baseuri->path_query;
    $path_query =~ s{^/}{};

    my $source = "nlmmain:".$path_query;                       # relative-URI with .html
                        
    my $alias = $path_query;                                   # relative-URI without .html
    $alias =~ s/\.html$//;
    
    my $body = $tree->look_down("id", "body");
    unless ($body) {
        print STDERR "skipping $baseuri: unable to locate <div id=\"body\">\n";
        return;
    }
    my $has_primary = $body->look_down("id", "primary");
    if ($has_primary) {
        print STDERR "skipping $baseuri: seems to have primary column\n";
        return;
    }

    my $has_secondary = $body->look_down("id", "secondary");
    if ($has_secondary) {
        print STDERR "skipping $baseuri: seems to have secondary column\n";
        return;
    }

    my $title;                                          # title is either first h1 or document's title
    my $title_node = $body->look_down("_tag", "h1");
    if ($title_node) {
        $title = $title_node->as_text();                # Maybe too strong - remember fact sheets
        $title_node->destroy;                           # remove from body
    } else {
        $title_node = $tree->find("_tag", "title");
        if ($title_node) {
            $title = $title_node->as_text();
        }
    }
    unless ($title) {                                   # make sure we got a title
        print STDERR "skipping $baseuri: unable to find title\n";
        return;
    }

    # Transform Body into non-encoded HTML
    my $body_xml = $body->as_XML();
    $body_xml =~ s/^<div id="body">//;
    $body_xml =~ s{</div>$}{};

    # Invariant - we have $source, $alias, $title, $body.
    # we can save this to the XML we build at the end

    my $newsref = {
        source => $source,
        alias => $alias,
        title => $title,
        body => $body_xml
    };
    if ($item_type) {
        $newsref->{'type'} = $item_type;
    }
    &create_news_item($newsref);
}

sub create_news_item {
    my ($news_ref) = @_;

    my $news_el = $doc->createElement("newsitem");
    $news_el->appendText("\n");

    $newslist->appendText("  ");
    $newslist->appendChild($news_el);
    $newslist->appendText("\n");

    while (my ($k, $v) = each %$news_ref) {
        $news_el->appendText("    ");
        $news_el->appendTextChild($k, $v);
        $news_el->appendText("\n");
    }
    $news_el->appendText("  ");
}




