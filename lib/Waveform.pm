#!/usr/bin/perl

package Waveform;

use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(checkWaveform eventProp);
use Switch;

sub checkWaveform{
	my($waveform)=@_;
	my($timeSeq,$eventSeq)=split(/,/,$waveform);
	my @time=split(/\//,$timeSeq);
	my @event=split(/\//,$eventSeq);

	my $error=0;
	if(!scalar(@event)){
		$error++;
		print "waveform $waveform is invalid. zero event.\n";
	}
	if(scalar(@time) != scalar(@event)){
		$error++;
		print "waveform $waveform is invalid. The number of time and event doesn't match.\n";
	}

	my $prevState;
	foreach my $event(@event){
		my @state = split("",$event);
		if(scalar(@state)!=2){
			$error++;
			print "waveform $waveform is invalid. Event $event doesn't have 2 states.\n";
		}
		if(defined $prevState){
			if($prevState ne $state[0]){
				$error++;
				print "waveform $waveform is invalid. PrevState $prevState doesn't equal to $state[0].\n";
			}
		}
		$prevState = $state[1];
	}

	return $error;
}

sub eventProp{
	my($in1Trans,$in2Trans,$gate)=@_;
	my($outTrans);
	
	# exchange transition pin
	#if($in1Trans !~ /\b(01|0x|10|1x|x0|x1)\b/ && $in2Trans =~ /\b(01|0x|10|1x|x0|x1)\b/){
	#	my $transTmp = $in1Trans;
	#	$in1Trans = $in2Trans;
	#	$in2Trans = $transTmp;
	#}
	my @in1Trans=split("",$in1Trans);
	my @in2Trans=split("",$in2Trans);
	my @outTrans;
	switch ($gate){
		case "BUF" {
			foreach my $i(qw(0 1)){ $outTrans[$i]	= $in1Trans[$i]; }
		}
		case "INV" {
			foreach my $i(qw(0 1)){
				$outTrans[$i]	= ($in1Trans[$i] eq "x") ? "x" : ($in1Trans[$i] eq "0") ? "1" : "0"; }
		}
		case "AND" {
			foreach my $i(qw(0 1)){
				switch ($in1Trans[$i]){
					case "0"{ $outTrans[$i] = "0"; }
					case "1"{ $outTrans[$i] = $in2Trans[$i]; }
					case "x"{ $outTrans[$i] = $in2Trans[$i] eq "0" ? "0" : "x"; }
					else{ print "gate $gate has invalid state $i : $in1Trans[$i]\n"; }
				}
			}
		}
		case "NAND" {
			foreach my $i(qw(0 1)){
				switch ($in1Trans[$i]){
					case "0"{ $outTrans[$i] = "1"; }
					case "1"{ $outTrans[$i] = ($in2Trans[$i] eq "x") ? "x" : ($in2Trans[$i] eq "0") ? "1" : "0"; }
					case "x"{ $outTrans[$i] = $in2Trans[$i] eq "0" ? "1" : "x"; }
					else{ print "gate $gate has invalid state $i : $in1Trans[$i]\n"; }
				}
			}
		}
		case "OR" {
			foreach my $i(qw(0 1)){
				switch ($in1Trans[$i]){
					case "0"{ $outTrans[$i] = $in2Trans[$i]; }
					case "1"{ $outTrans[$i] = "1"; }
					case "x"{ $outTrans[$i] = $in2Trans[$i] eq "1" ? "1" : "x"; }
					else{ print "gate $gate has invalid state $i : $in1Trans[$i]\n"; }
				}
			}
		}
		case "NOR" {
			foreach my $i(qw(0 1)){
				switch ($in1Trans[$i]){
					case "0"{ $outTrans[$i] = ($in2Trans[$i] eq "x") ? "x" : ($in2Trans[$i] eq "0") ? "1" : "0"; }
					case "1"{ $outTrans[$i] = "0"; }
					case "x"{ $outTrans[$i] = $in2Trans[$i] eq "1" ? "0" : "x"; }
					else{ print "gate $gate has invalid state $i : $in1Trans[$i]\n"; }
				}
			}
		}
		case "XOR" {
			foreach my $i(qw(0 1)){
				switch ($in1Trans[$i]){
					case "0"{ $outTrans[$i] = ($in2Trans[$i] eq "x") ? "x" : ($in2Trans[$i] eq "1") ? "1" : "0"; }
					case "1"{ $outTrans[$i] = ($in2Trans[$i] eq "x") ? "x" : ($in2Trans[$i] eq "0") ? "1" : "0"; }
					case "x"{ $outTrans[$i] = "x"; }
					else{ print "gate $gate has invalid state $i : $in1Trans[$i]\n"; }
				}
			}
		}
		case "XNOR" {
			foreach my $i(qw(0 1)){
				switch ($in1Trans[$i]){
					case "0"{ $outTrans[$i] = ($in2Trans[$i] eq "x") ? "x" : ($in2Trans[$i] eq "0") ? "1" : "0"; }
					case "1"{ $outTrans[$i] = ($in2Trans[$i] eq "x") ? "x" : ($in2Trans[$i] eq "1") ? "1" : "0"; }
					case "x"{ $outTrans[$i] = "x"; }
					else{ print "gate $gate has invalid state $i : $in1Trans[$i]\n"; }
				}
			}
		}
		else {
			print "ERROR:Gate $gate is not supported!\n";
		}
	}
	$outTrans	= join("",@outTrans);

	return($outTrans);
}

1;
