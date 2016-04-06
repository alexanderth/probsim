#!/usr/bin/perl

my $infile = $ARGV[0];
open(FP,$infile) or die("Can't open $infile\n$!");
while(my $line=<FP>){
	#if($line =~ /(\d+)\s+\d+\/([\d\.]+)\s+\d+\/([\d\.]+)\s+\d+\/([\d\.]+)/){
	if($line =~ /:\s+([\d\.]+)/){
		print "$1\n";
	}else{
		print $line;
	}
}
close(FP);
