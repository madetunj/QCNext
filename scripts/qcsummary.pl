#!/usr/bin/perl
# process outputfiles to specified folder for qc

use strict;
use JSON;
use Getopt::Long;
use Pod::Usage;
use File::Basename;
 
my ($help, $manual, $infile, $json, $folder, $newpath, $toil);

GetOptions ("i|in=s"=>\$infile,"t|toil"=>\$toil);
my $usage = "perl $0 -i <log output file>\n";
unless ( $infile ) { die $usage; }

local $/; #Enable 'slurp' mode
open my $fh, "<", $infile;
$json = <$fh>;
close $fh;
my $data = decode_json($json);

#output to desired folder
unless ($folder) { $folder = (split("\_fastq", $data->{'readqc_zip'}->{'nameroot'}))[0]; }
`mkdir -p $folder`;
if ($toil) {
  $newpath = (fileparse( (split("file://", $data->{'statsfile'}->{'location'}))[1] ))[1];
}
else {
  $newpath = (fileparse($data->{'statsfile'}->{'path'}))[1];
}       

`cp -rf $newpath/*-stats* $folder`;
`cp -rf $newpath/*fastqc* $folder`;
