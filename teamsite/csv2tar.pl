#!/usr/bin/env perl
use strict;
use warnings;

use Getopt::Long;

# Process arguments

sub usage {
   print STDERR "Usage: $0 [-workarea basedir] path-to-input-csv path-to-output-tar\n";
   exit 1;
}

GetOptions("workarea=s" => \my $workarea
	) or &usage;

int(@ARGV) == 2 or &usage;
my $input_path = $ARGV[0];
my $output_path = $ARGV[1];


# Open the input the file, check ability to read 

my $infh;
if ($input_path) {
    open($infh, "<", $input_path) or die "unable to read `$input_path': $!";
} else {
    $infh = *STDIN;
}

# create the output file if needed, check ability to write

my $outfh;
open($outfh, ">", $output_path) or die "Unable to write `$output_path': $!";
close $outfh;

my %skipme = ();

# add a path to the tar with -uvf (file must exist) if it hasn't been seen

sub add_path_to_tar {
    my ($tarpath, $base, $path) = @_;
    unless (exists $skipme{$path}) {
	`tar -uvf $tarpath -C $base $path`;
	$skipme{$path} = 1;
    }
}
    
# read CSV, adding files from each line to the tar

while (my $line = <$infh>) {
    chomp $line;
    my ($url, $base, $path, $form, $dcr, $pt) = split(/,/, $line);
    next if $url eq 'URL';
    next if ($workarea and $base !~ /$workarea/);       # Skip rows that don't match workarea

    if ($path eq "") {
	print STDERR "URL Not Found: $url\n";
    } else {
	add_path_to_tar($output_path, $base, $path);
	add_path_to_tar($output_path, $base, $form) if $form ne '';
	add_path_to_tar($output_path, $base, $dcr) if $dcr ne '';
	add_path_to_tar($output_path, $base, $pt) if $pt ne '';
    }
}
