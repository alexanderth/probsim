#!/usr/bin/perl

#time-event pair: (t1/t2/t3/t4/t5,e1/e2/e3/e4/e5)
# t is time, "-" equals to very large neg number means minus infinit
# e is transition state, can transit from "0,1,x", 9 transitions in total
# "01"(r),"10"(f),"11"(1),"00"(0),"0x","1x","x0","x1","xx"

use Switch;
# signle event propagation for lastNEventAlgorithm
sub singleEventPropagation(){
	my($evalTime,$in1Trans,$in2Trans,$gate,$gateDelay)=@_;
	print "single event: evaltime $evalTime,in1trans $in1Trans,in2trans $in2Trans,gate $gate,gateDelay $gateDelay\n" if($verbose>2);
	my($outTime,$outTrans,$outProb,%out);
	
	#change r/f/0/1/x
	$evalTime = -10000 if($evalTime eq "-");
	# exchange transition pin
	if($in1Trans !~ /\b(01|0x|10|1x|x0|x1)\b/ && $in2Trans =~ /\b(01|0x|10|1x|x0|x1)\b/){
		my $transTmp = $in1Trans;
		$in1Trans = $in2Trans;
		$in2Trans = $transTmp;
	}
	my @in1Trans=split("",$in1Trans);
	my @in2Trans=split("",$in2Trans);
	my @outTrans;
	#propagate
	switch ($gate){
		case "BUF" {
			$outTime	= $evalTime + $gateDelay;
			$outTrans[0]	= $in1Trans[0];
			$outTrans[1]	= $in1Trans[1];
		}
		case "INV" {
			$outTime	= $evalTime + $gateDelay;
			foreach my $i(qw(0 1)){
				$outTrans[$i]	= ($in1Trans[$i] eq "x") ? "x" : ($in1Trans[$i] eq "f") ? "r" : "f";
			}
		}
		case "AND" {
			foreach my $i(qw(0 1)){
				switch ($in1Trans[$i]){
					case "0"{
						$outTrans[$i] = "0";
					}
					case "1"{
			    		$outTrans[$i] = $in2Trans[$i];
					}
					case "x"{
			    		$outTrans[$i] = $in2Trans[$i] eq "0" ? "0" : "x";
					}
					else{
						print "gate $gate has invalide state $i : $in1Trans[$i]\n";
					}
				}
			}
			$outTime = $evalTime + $gateDelay;
		}
		case "NAND" {
			foreach my $i(qw(0 1)){
				switch ($in1Trans[$i]){
					case "0"{
						$outTrans[$i] = "1";
					}
					case "1"{
			    		$outTrans[$i] = ($in2Trans[$i] eq "x") ? "x" : ($in2Trans[$i] eq "1") ? "0" : "1";
					}
					case "x"{
			    		$outTrans[$i] = $in2Trans[$i] eq "0" ? "1" : "x";
					}
					else{
						print "gate $gate has invalide state $i : $in1Trans[$i]\n";
					}
				}
			}
			$outTime = $evalTime + $gateDelay;
		}
		case "OR" {
			foreach my $i(qw(0 1)){
				switch ($in1Trans[$i]){
					case "0"{
						$outTrans[$i] = $in2Trans[$i];
					}
					case "1"{
			    			$outTrans[$i] = "1";
					}
					case "x"{
			    			$outTrans[$i] = $in2Trans[$i] eq "1" ? "1" : "x";
					}
					else{
						print "gate $gate has invalide state $i : $in1Trans[$i]\n";
					}
				}
			}
			$outTime = $evalTime + $gateDelay;
		}
		case "NOR" {
			foreach my $i(qw(0 1)){
				switch ($in1Trans[$i]){
					case "0"{
						$outTrans[$i] = ($in2Trans[$i] eq "x") ? "x" : ($in2Trans[$i] eq "0") ? "1" : "0";
					}
					case "1"{
			    			$outTrans[$i] = "0";
					}
					case "x"{
			    			$outTrans[$i] = $in2Trans[$i] eq "1" ? "0" : "x";
					}
					else{
						print "gate $gate has invalide state $i : $in1Trans[$i]\n";
					}
				}
			}
			$outTime = $evalTime + $gateDelay;
		}
		case "XOR" {
			foreach my $i(qw(0 1)){
				switch ($in1Trans[$i]){
					case "0"{
						$outTrans[$i] = ($in2Trans[$i] eq "x") ? "x" : ($in2Trans[$i] eq "1") ? "1" : "0";
					}
					case "1"{
						$outTrans[$i] = ($in2Trans[$i] eq "x") ? "x" : ($in2Trans[$i] eq "0") ? "1" : "0";
					}
					case "x"{
			    			$outTrans[$i] = "x";
					}
					else{
						print "gate $gate has invalide state $i : $in1Trans[$i]\n";
					}
				}
			}
			$outTime = $evalTime + $gateDelay;
		}
		case "XNOR" {
			foreach my $i(qw(0 1)){
				switch ($in1Trans[$i]){
					case "0"{
						$outTrans[$i] = ($in2Trans[$i] eq "x") ? "x" : ($in2Trans[$i] eq "0") ? "1" : "0";
					}
					case "1"{
						$outTrans[$i] = ($in2Trans[$i] eq "x") ? "x" : ($in2Trans[$i] eq "1") ? "1" : "0";
					}
					case "x"{
			    			$outTrans[$i] = "x";
					}
					else{
						print "gate $gate has invalide state $i : $in1Trans[$i]\n";
					}
				}
			}
			$outTime = $evalTime + $gateDelay;
		}
		else {
			print "ERROR:Gate $gate is not supported!\n";
		}
	}
	$out{time}	= $outTime;
	$out{trans}	= join("",@outTrans);
	print "    --single event propagation\: in1\:$in1Trans in2\:$in2Trans @ $evalTime \-\> out\:$outTrans @ $outTime\n" if($verbose>2);

	return(%out);
}

1;
