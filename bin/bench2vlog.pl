#!/usr/bin/perl

use Getopt::Long;

GetOptions(
	"bench=s"	=> \$bench,
	"vlog=s"	=> \$vlog
);

local(*BENCH,*VLOG);
if(!$bench or !open(BENCH,"$bench")){
	print "Can't open bench file $bench\n";
	exit();
}

$vlog = "out.v" if(!$vlog);
open(VLOG,">$vlog") or die("Can't open verilog file $vlog\n");

# #c3155 - comments
# INPUT(1) - input pin 1
# OUTPUT(1324) - output pin 1324
# 977 = NOT(860)
# 1324 = BUFF(1292)
# 978 = AND(938, 939, 940, 873)
# 986 = OR(978, 979, 980, 981)
print VLOG "\/\/ generated from $bench\n\n";
my (@inputs,@outputs,$top);
while(my $line=<BENCH>){
print "line:$line";
	if($line =~ /^\#\s*((C|c)\d+)/){
		$top = $1;
	}elsif($line =~ /^\#|^\s*$/){
		$line =~ s/^\#/\/\//;
		print VLOG $line;
	}elsif($line =~ /^\s*INPUT\((\d+)\)/){
		my $pinName = "n".$1;
		push(@inputs,$pinName);
	}elsif($line =~ /^OUTPUT\((\d+)\)/){
		while($line =~ /^\s*OUTPUT\((\d+)\)/){
			my $pinName = "n".$1;
			push(@outputs,$pinName);
			$line = <BENCH>;
		}
		print VLOG $line;
		print VLOG "module $top (";
		print VLOG join(",",@inputs,@outputs);
		print VLOG ");\n\n";
		foreach my $pin(@inputs){
			print VLOG "input $pin;\n";
		}
		foreach my $pin(@outputs){
			print VLOG "output $pin;\n";
		}
		print VLOG "\n";
		next;
	}elsif($line =~ /^\s*(\d+)\s*\=\s*(\w+)\s*\(([\d\s,]+)\)/){
		my $out = "n".$1;
		my $gate = $2;
		my @ins = split(/,\s+/,$3);
		@nins = map {"n".$_} @ins;
		#print "out $out gate $gate ins ".join(" ",@nins)."\n";
		if($gate eq "BUFF"){
			print VLOG "assign $out = $nins[0];\n";
		}elsif($gate eq "NOT"){
			print VLOG "assign $out = ~$nins[0];\n";
		}elsif($gate eq "AND"){
			print VLOG "assign $out = ".join(" & ",@nins).";\n";
		}elsif($gate eq "NAND"){
			print VLOG "assign $out = ~\(".join(" & ",@nins)."\);\n";
		}elsif($gate eq "OR"){
			print VLOG "assign $out = ".join(" | ",@nins).";\n";
		}elsif($gate eq "NOR"){
			print VLOG "assign $out = ~\(".join(" | ",@nins)."\);\n";
		}elsif($gate eq "XOR"){
			print VLOG "assign $out = ".join(" ^ ",@nins).";\n";
		}elsif($gate eq "XNOR"){
			print VLOG "assign $out = ~\(".join(" ^ ",@nins)."\);\n";
		}else{
			print "ERROR: Can't handle $line\n";
		}
	}else{
		print "ERROR: Can't handle $line\n";
	}
}
print VLOG "\nendmodule";
close(BENCH);
close(VLOG);
