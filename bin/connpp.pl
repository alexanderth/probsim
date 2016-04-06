#!/usr/bin/perl

my $infile = $ARGV[0];
my $outfile = $ARGV[1];
local(*FP,*FP1);
open(FP,"$infile") or die("Can't open $infile\n$!");
open(FP1,">$outfile") or die("Can't create $outfile\n$!");
while(my $line=<FP>){
	$line =~ s/\{|\}|\[|\]//g;
	$line =~ s/\<|\>/_/g;
	print FP1 $line;
}
close(FP);
close(FP1);
