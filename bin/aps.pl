#!/usr/bin/perl

#require "src/readConn.pl";
#require "src/readBench.pl";
#require "src/readWave.pl";
#require "src/buildNetwork.pl";
#require "src/topoSortNetwork.pl";
require "src/hierPartitionAndSim.pl";
use lib "/home/xiaoliac/bin/perl/lib";
use PROBSIM;

use Env;
use Getopt::Long;
use File::Basename;

my $program = $0;
my $switches = join(" ",@ARGV);
$switches =~ s/-/\n-/g;
print "Approximate Probabilistic Simulation (APS) started at ".(localtime)."\n";
print "prog = $program\nswitches = \n$switches\n";

GetOptions(
	"infile=s"	=> \$infile,
	"outnode=s"	=> \$outnode,
	"wavefile=s"	=> \$wavefile,
	"algorithm=s"	=> \$algorithm,
	"stemlimit=i"	=> \$stemlimit,
	"depthlimit=i"	=> \$depthlimit,
	"wavelimit=i"	=> \$wavelimit,
	"eventlimit=i"	=> \$eventlimit,
	"glitchth=f"	=> \$glitchth,
	"sim!"		=> \$sim,
	"propagate!"	=> \$propagate,
	"debug!"	=> \$debug,
	"verbose=i"	=> \$verbose
);

if(!$infile or !$outnode or !$wavefile){
	print "Please specify conn file, output node and wavefile\n$!";
	exit(1);
}

$algorithm = "waveform" if(!defined $algorithm);
$eventlimit = 3 if(!defined $eventlimit);
$stemlimit = 2 if(!defined $stemlimit);
#$stemsumlimit = 1000 if(!defined $stemsumlimit);
$depthlimit = 10 if(!defined $depthlimit);
$glitchth  = 0 if(!defined $glitchth);
$sgprobsim = 1 if(!defined $sgprobsim);
$debug = 1 if($verbose>10);
$verbose = 0 if($debug);
$verbose = 1;

# print message setting
$prtMsgReadInput	= 1;
$prtMsgReadWave		= 1;
#supergae
$prtMsgSgNetwork2lcgraph = 1;
$prtMsgSgSupergateDfs	= 1;

## read input $infile, create %netowrk 
## $network{<net>}{type}
## $network{<net>}{gate}
## $network{<net>}{delay}
## $network{<net>}{trace}
my %network;
if($infile =~ /\.conn$/){
	%network = readConn($infile);
}elsif($infile =~ /\.bench/){
	%network = readBench($infile);
}
if($prtMsgReadInput){
	print "\nnetwork:\n";
	foreach my $net(sort keys %network){
		print "$net:$network{$net}{type}, $network{$net}{gate}, $network{$net}{delay}, $network{$net}{trace}\n";
	}
	print "\n";
}
print "read infile $infile, create \%network finished at ".(localtime)."\n" if($verbose);
$|=1;

## input waveforms $eventsfile
## add $network{<net>}{waveform}{<events>} = <prob>
my @wavefiles = split(/,/,$wavefile);
foreach my $file(@wavefiles){
	chomp($file);
	print "read events file: $file\n" if($prtMsgReadEvent);
	readWave($file,\%network);
}
print "read wavefile finished at ".(localtime)."\n" if($verbose);
$|=1;

## hierPartitionAndSim()
my %networkUpdated=buildNetwork(\%network,$outnode);
hierPartitionAndSim(\%networkUpdated,$outnode,$stemlimit,$depthlimit,$wavelimit,$eventlimit,$glitchTh);

print "Approximate Probabilistic Simulation (APS) finished at ".(localtime)."\n";

print "\narrival time statistics\n";
print "-----------------------\n";
foreach my $waveform(sort keys %{$networkUpdated{$outnode}{waveform}}){
	#next if($waveform =~ /^\s*$/);
	next if(!$waveform);
	my($time,$trans) = split(/,/,$waveform);
	my $prob = $conn{$outnode}{waveform}{$waveform};
	$time =~ s/(([-\d]+\/)*)([-\d]+)$/$3/;
	$trans =~ s/(([rf]\/)*)([rf])$/$3/;
	$arrivalProb{"$time,$trans"} += $prob;
}
foreach my $arrivalTimeTrans(sort {
					my ($at,$ae) = split(/,/,$a);
					my ($bt,$be) = split(/,/,$b);
					if($at == $bt){
						return ($ae cmp $be);
					}else{
						return ($at <=> $bt);
					}
				  } keys %arrivalProb){
	print "$arrivalTimeTrans : $arrivalProb{$arrivalTimeTrans}\n";
}
#close(LOG);

