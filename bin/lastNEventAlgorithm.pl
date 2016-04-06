#!/usr/bin/perl

use Switch;

# waveform format: (timeSeq,eventSeq)=<prob>, eg:(t1/t2/.../tn,01/1x/.../x0)=0.1
# always keep first event and last event
# handle 'x' state
sub lastNEventAlgorithm(){
	my($in1Time,$in1Trans,$in1Prob,$in2Time,$in2Trans,$in2Prob,$gate,$gateDelay,$glitchTh)=@_;
	# get time need to be evaluated
	print "lastn: in1time $in1Time,in1trans $in1Trans,in1prob $in1Prob,in2time $in2Time,in2trans $in2Trans,in2prob $in2Prob\n" if($verbose>2);
	my(@evalTime,@eventsTime,@sortedTime,%seen,%check);
	my @in1Time_in  = split(/\//,$in1Time);
	my @in1Trans_in = split(/\//,$in1Trans);
	my @in2Time_in  = split(/\//,$in2Time);
	my @in2Trans_in = split(/\//,$in2Trans);
	if($in1Time_in[0] eq "-"){
		$in1Time_in[0] = -10000;
	}
	if($in2Time_in[0] eq "-"){
		$in2Time_in[0] = -10000;
	}
	push(@eventsTime,@in1Time_in);
	push(@eventsTime,@in2Time_in);
	print "eventstime are ".scalar(@eventsTime).", $eventsTime[0],$eventsTime[1]," if($verbose>2);
	@sortedTime = sort {$a<=>$b} @eventsTime;
	@evalTime = grep { ! $seen{$_}++ } sort {$a<=>$b} @eventsTime;
	print "evaltime number is ".scalar(@evalTime)." after reduction\n" if($verbose>2);
	# get in1 in2 status @ evalTime
	my $in1Idx = -1;
	my $in2Idx = -1;
	my (@in1Trans,@in2Trans);
	for(my $i=0;$i<@evalTime;$i++){
	print "in1Idx is $in1Idx, in1Time_in is $in1Time_in[$in1Idx+1], evaltime is $evalTime[$i]\n" if($verbose>2);
		if($in1Time_in[$in1Idx+1] eq $evalTime[$i]){
		#has event on evalTime, - idx+1==evalt, put trans=event[++idx]
		print "hit 1\n" if($verbose>2);
			$in1Idx++;
			$in1Trans[$i] = $in1Trans_in[$in1Idx];
		}elsif($in1Idx >= (scalar(@in1Time_in)-1)){
		#already reach last event, - r=1,f=0
		print "hit 2\n" if($verbose>2);
			my $padding = $in1Trans_in[$in1Idx];
			$padding =~ s/^\w//;
			$in1Trans[$i] = "$padding$padding"; # final value
		}else{
		#has no event on evalTime, use next event for padding
		print "hit 3\n" if($verbose>2);
			my $padding = $in1Trans_in[$in1Idx+1];
			$padding =~ s/\w$//;
			$in1Trans[$i] = "$padding$padding"; # state value
		}
		if($in2Time_in[$in2Idx+1] eq $evalTime[$i]){
			$in2Idx++;
			$in2Trans[$i] = $in2Trans_in[$in2Idx];
		}elsif($in2Idx >= (scalar(@in2Time_in)-1)){
			my $padding = $in2Trans_in[$in2Idx];
			$padding =~ s/^\w//;
			$in2Trans[$i] = "$padding$padding"; # final value
		}else{
			my $padding = $in2Trans_in[$in2Idx+1];
			$padding =~ s/\w$//;
			$in2Trans[$i] = "$padding$padding"; # state value
		}
	print "in1Idx is $in1Idx, in1trans is $in1Trans[$i],in2Idx is $in2Idx, in2trans is $in2Trans[$i]\n" if($verbose>2);
	}
	if($evalTime[0] == -10000){
		$evalTime[0] = "-";
	}
	# calc output events
	my(@outTime,@outTrans,$outProb,%out);
	for(my $i=0;$i<@evalTime;$i++){
		print "nlast: single event evaltimme $evalTime[$i], in1trans $in1Trans[$i], in2trans $in2Trans[$i]\n" if($verbose>2);
		print "nlast: single event evaltimme $evalTime[$i], in1trans $in1Trans[$i], in2trans $in2Trans[$i] gate $gate gateDelay $gateDelay\n";
		%out=singleEventPropagation($evalTime[$i],$in1Trans[$i],$in2Trans[$i],$gate,$gateDelay);
		print "nlast: single event output: $out{time}, $out{trans}\n" if($verbose>2);
		if($i == 0 && $out{trans} =~ /00|11/){
			$out{time} = "-";
			$out{trans} = $out{trans} eq "11" ? "01" : "10";
		}
		if($out{trans} !~ /11|00|xx/){
			push(@outTime,$out{time});
			push(@outTrans,$out{trans});
		}
	}
	#check output, states must be state continous, 10->0x->xx->x1->10
	my ($prevTrans,$curTrans,$nPrevTrans);
	print "check outTrans :".join(",",@outTrans)."\n" if($verbose);
	for(my $i=0;$i<scalar(@outTime);$i++){
		if(!$prevTrans){
			$prevTrans = $outTrans[$i];
			$prevTrans =~ s/^\w//;
			next;
		}else{
			($curTrans,$nPrevTrans) = split("",$outTrans[$i]);
			if($curTrans ne $prevTrans){
				print "ERROR:outtrans $i is not continous: $prevTrans->$curTrans\n" if($verbose);
			}
			$prevTrans = $nPrevTrans;
		}
	}
	print "lastn:$out{time},$outTime[0];$out{trans},$outTrans[0]\n" if($verbose>2);
	# filter output glitches/no changes 
	for(my $i=0;$i<scalar(@outTime);$i++){
		if($outTrans[$i] =~ /00|11|xx/){
			splice(@outTime,$i,1);
			splice(@outTrans,$i,1);
			$i = $i-1;
		}elsif($i == 0){
			next;
		}elsif( ($outTime[$i] - $outTime[$i-1])<=$glitchTh){
			splice(@outTime,$i-1,2);
			splice(@outTrans,$i-1,2);
			$i = $i-2;
		}
	}
	print "lastn:$outTrans[0],$outTime[0]\n" if($verbose>2);
	if(scalar(@outTrans)>1 && $outTime[0] eq "-"){
		splice(@outTime,0,1);
		splice(@outTrans,0,1);
	}
	# merge x events
	my ($firstXIdx,$lastXIdx);
	for(my $i=0;$i<scalar(@outTime);$i++){
		if(!$firstIdx){
			$firstXIdx = $i if($outTrans[$i] =~ /\wx/);
		}else{
			$lastXIdx = $i if($outTrans[$i] =~ /x\w/);
		}
	}
	if($lastIdx-$firstXIdx>=2){
		splice(@outTrans,$firstXIdx+1,$lastIdx-$firstIdx-1);
		splice(@outdTime,$firstXIdx+1,$lastIdx-$firstIdx-1);
		print "$merge x: remove ".($firstXIdx+1)." to ".($lastXIdx-1)."\n";
	}
	print "lastn:$outTrans[0],$outTime[0]\n" if($verbose>2);
	# keep k events
	if(scalar(@outTrans)>$eventlimit+1){
		print "only keep k last events\n" if($verbose>2);
		#keep last n events
		#splice(@outTime,0,scalar(@outTrans)-$eventlimit);
		#splice(@outTrans,0,scalar(@outTrans)-$eventlimit);
		#keep first + lastest k event
		splice(@outTime,1,scalar(@outTrans)-$eventlimit-1);
		splice(@outTrans,1,scalar(@outTrans)-$eventlimit-1);
		$outTrans[1]=~s/\w$/x/;
		$outTrans[-$eventlimit]=~s/^\w/x/;
	}
	print "lastn:$outTrans[0],$outTime[0]\n" if($verbose>2);
	print "event number is ".scalar(@outTrans).",event limit is $eventlimit\n" if($verbose>2);
	print "lastn:$outTrans[0],$outTime[0]\n" if($verbose>2);
	# output
	$out{time} = join("\/",@outTime);
	$out{trans} = join("\/",@outTrans);
	$out{prob} = ($gate =~ /\b(BUF|INV)\b/) ? $in1Prob : ($in1Prob*$in2Prob);

	return(%out);
}

#time-event pair: (t1/t2/t3/t4/t5,e1/e2/e3/e4/e5)
# t is time, "-" equals to very large neg number means minus infinit
# e is transition state, can transit from "0,1,x", 9 transitions in total
# "01"(r),"10"(f),"11"(1),"00"(0),"0x","1x","x0","x1","xx"

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
	print "singleevent:trans_0 $in1Trans[0],$in2Trans[0], trans_1 $in1Trans[1],$in2Trans[1]\n";
	#propagate
	switch ($gate){
		case "BUF" {
			$outTime	= $evalTime + $gateDelay;
			foreach my $i(qw(0 1)){
				$outTrans[$i]	= $in1Trans[$i];
			}
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
	print "singleevnet: outtrans $outTrans[0],$outTrans[1]\n";
	$outTime = "-" if($outTime < 0);
	$out{time}	= $outTime;
	$out{trans}	= join("",@outTrans);
	print "    --single event propagation\: in1\:$in1Trans in2\:$in2Trans @ $evalTime \-\> out\:$out{trans} @ $out{time}\n" if($verbose>2);

	return(%out);
}

1;
