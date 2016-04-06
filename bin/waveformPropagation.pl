#!/usr/bin/perl

use Switch;

# waveform format: (timeSeq,eventSeq)=<prob>, eg:(t1/t2/.../tn,01/1x/.../x0)=0.1
# always keep first event and last event
# handle 'x' state
sub waveformPropagation{
	my($waveform1,$waveProb1,$waveform2,$waveProb2,$gate,$gateDelay,$eventlimit,$glitchTh)=@_;
	if($prtMsgWaveformPropagation){
		print "waveform propagation: gate $gate waveform1 $waveform1 prob $waveProb1, ";
		print "waveform2 $waveform2 prob $waveProb2 eventlimit $eventlimit glitchTh $glitchTh\n";
	}
	if($assertion){
		if(checkWaveform($waveform1)){
			print "waveform1 $waveform1 is invalid\n";
			#exit(1);
		}
		if($gate !~ /INV|BUF/ && checkWaveform($waveform2)){
			print "waveform2 $waveform2 is invalid\n";
			#exit(1);
		}
		if($waveProb1<=0 or $waveProb1>1 ){
			print "waveProb1 is invalide less or equal than 0\n" if($waveProb1<=0);
			print "waveProb1 is invalide great than 1\n" if($waveProb1>1);
			exit();
		}
		if($gate !~/INV|BUF/ && ($waveProb2<=0 or $waveProb2>1)){
			print "waveProb2 is invalide less or equal than 0\n" if($waveProb2<=0);
			print "waveProb2 is invalide great than 1\n" if($waveProb2>1);
			exit();
		}
	}
	my ($in1Time,$in1Trans) = split(/,/,$waveform1);
	my ($in2Time,$in2Trans) = split(/,/,$waveform2);
	# get time need to be evaluated
	my @in1Time_in  = split(/\//,$in1Time);
	my @in1Trans_in = split(/\//,$in1Trans);
	my @in2Time_in  = split(/\//,$in2Time);
	my @in2Trans_in = split(/\//,$in2Trans);
	my(@eventsTime,%seen,%check);
	push(@eventsTime,@in1Time_in);
	push(@eventsTime,@in2Time_in);
	my @evalTime = grep { ! $seen{$_}++ } sort {$a<=>$b} @eventsTime;
	print "eventstime are ".scalar(@eventsTime).", $eventsTime[0],$eventsTime[1]," if($prtMsgWaveformPropagation>2);
	print "evaltime number is ".scalar(@evalTime)." after reduction\n" if($prtMsgWaveformPropagation>2);
	# get in1 in2 state @ evalTime
	my $in1Idx = -1;
	my $in2Idx = -1;
	my (@in1Trans,@in2Trans);
	for(my $i=0;$i<@evalTime;$i++){
	print "in1Idx is $in1Idx, in1Time_in is $in1Time_in[$in1Idx+1], evaltime is $evalTime[$i]\n" if($prtMsgWaveformPropagation>2);
		if($in1Time_in[$in1Idx+1] eq $evalTime[$i]){
		#has event on evalTime, - idx+1==evalt, put trans=event[++idx]
		print "hit 1\n" if($prtMsgWaveformPropagation>2);
			$in1Idx++;
			$in1Trans[$i] = $in1Trans_in[$in1Idx];
		}elsif($in1Idx == (scalar(@in1Time_in)-1)){
		#already reach last event, - r=1,f=0
		print "hit 2\n" if($prtMsgWaveformPropagation>2);
			my $padding = $in1Trans_in[$in1Idx];
			$padding =~ s/^\w//;
			$in1Trans[$i] = "$padding$padding"; # final value
		}elsif($in1Idx < (scalar(@in1Time_in)-1)){
		#has no event on evalTime, use next event for padding
		print "hit 3\n" if($prtMsgWaveformPropagation>2);
			my $padding = $in1Trans_in[$in1Idx+1];
			$padding =~ s/\w$//;
			$in1Trans[$i] = "$padding$padding"; # state value
		}else{
			print "ERROR: waveformPropagation in1Idx $in1Idx can't exceeds ".(scalar(@in1Time_in)-1)."\n";
		}
		if($in2Time_in[$in2Idx+1] eq $evalTime[$i]){
			$in2Idx++;
			$in2Trans[$i] = $in2Trans_in[$in2Idx];
		}elsif($in2Idx == (scalar(@in2Time_in)-1)){
			my $padding = $in2Trans_in[$in2Idx];
			$padding =~ s/^\w//;
			$in2Trans[$i] = "$padding$padding"; # final value
		}elsif($in2Idx < (scalar(@in2Time_in)-1)){
			my $padding = $in2Trans_in[$in2Idx+1];
			$padding =~ s/\w$//;
			$in2Trans[$i] = "$padding$padding"; # state value
		}else{
			print "ERROR: waveformPropagation in2Idx $in2Idx can't exceeds ".(scalar(@in2Time_in)-1)."\n";
		}
	print "in1Idx is $in1Idx, in1trans is $in1Trans[$i],in2Idx is $in2Idx, in2trans is $in2Trans[$i]\n" if($prtMsgWaveformPropagation>2);
	}
	# calc output events
	my(@outTime,@outTrans,$outProb,%out);
	for(my $i=0;$i<@evalTime;$i++){
		print "eventPropagation input: evaltimme $evalTime[$i], in1trans $in1Trans[$i], in2trans $in2Trans[$i] gate $gate gateDelay $gateDelay\n" if($prtMsgWaveformPropagation>2);
		%out=eventPropagation($evalTime[$i],$in1Trans[$i],$in2Trans[$i],$gate,$gateDelay);
		print "eventPropagation output: $out{time}, $out{trans}\n" if($prtMsgWaveformPropagation>2);
		push(@outTime,$out{time});
		push(@outTrans,$out{trans});
	}
	#check output, states must be state continous, 10->0x->xx->x1->10
	if($assertion){
		my $outWaveform = join("/",@outTime).",".join("/",@outTrans);
		my $error=checkWaveform($outWaveform);
		if($error){
			print "ERROR: waveformPropagate output waveform $outWaveform is invalide\n";
			exit(1);
		}
	}
	print "output waveform ".join("/",@outTime).",".join("/",@outTrans)."\n" if($prtMsgWaveformPropagation);
	# filter out no changes
	my ($noChangeTime,$noChangeTrans);
	for(my $i=0;$i<scalar(@outTime);$i++){
		if($outTrans[$i] =~ /00|11|xx/){
			$noChangeTime = $outTime[$i] if(!defined $noChangeTime);
			$noChangeTrans = $outTrans[$i] if(!defined $noChangeTrans);
			splice(@outTime,$i,1);
			splice(@outTrans,$i,1);
			$i = $i-1;
		}
	}
	if(scalar(@outTime) == 0){
		push(@outTime,0);
		push(@outTrans,$noChangeTrans);
	}
	# filter output glitches
	for(my $i=0;$i<scalar(@outTime);$i++){
		if($i == 0){
			next;
		}elsif( ($outTime[$i] - $outTime[$i-1])<$glitchTh){
			splice(@outTime,$i-1,2);
			splice(@outTrans,$i-1,2);
			$i = $i-1;
		}
	}
	print "nochange/glitch waveform ".join("/",@outTime).",".join("/",@outTrans)."\n" if($prtMsgWaveformPropagation);
	# merge x events
	my ($firstXIdx,$lastXIdx);
	for(my $i=0;$i<scalar(@outTime);$i++){
		if(!defined $firstXIdx){
			$firstXIdx = $i if($outTrans[$i] =~ /\wx/);
		}
		if(!defined $lastXIdx){
			$lastXIdx = $i if($outTrans[$i] =~ /x\w/);
		}
	}
	if(defined $firstXIdx && defined $lastXIdx && $lastXIdx-$firstXIdx>=2){
		splice(@outTrans,$firstXIdx+1,$lastXIdx-$firstIdx-1);
		splice(@outdTime,$firstXIdx+1,$lastXIdx-$firstIdx-1);
		print "$merge x: remove ".($firstXIdx+1)." to ".($lastXIdx-1)."\n" if($prtMsgWaveformPropagation>2);
	}
	print "mergeX waveform ".join("/",@outTime).",".join("/",@outTrans)."\n" if($prtMsgWaveformPropagation);
	# keep k events
	if(scalar(@outTrans)>$eventlimit+1){
		print "only keep k last events\n" if($prtMsgWaveformPropagation>2);
		#keep last n events
		#splice(@outTime,0,scalar(@outTrans)-$eventlimit);
		#splice(@outTrans,0,scalar(@outTrans)-$eventlimit);
		#keep first + lastest k event
		splice(@outTime,1,scalar(@outTrans)-$eventlimit-1);
		splice(@outTrans,1,scalar(@outTrans)-$eventlimit-1);
		$outTrans[0]=~s/\w$/x/;
		$outTrans[-$eventlimit]=~s/^\w/x/;
	}
	print "kevents:$outTrans[0],$outTime[0]\n" if($prtMsgWaveformPropagation>2);
	print "kevents waveform ".join("/",@outTime).",".join("/",@outTrans)."\n" if($prtMsgWaveformPropagation);
	print "event number is ".scalar(@outTrans).",event limit is $eventlimit\n" if($prtMsgWaveformPropagation>2);
	# output
	$out{time} = join("\/",@outTime);
	$out{trans} = join("\/",@outTrans);
	$out{prob} = ($gate =~ /\b(BUF|INV)\b/) ? $waveProb1 : ($waveProb1*$waveProb2);
	if($assertion){
		if($out{prob}<=0 or $out{prob}>1){
		print "waveform propagation: ";
		printf("waveform1 $waveform1 prob %f ",$waveProb1);
		printf("waveform2 $waveform2 prob %f ",$waveProb2);
		print "eventlimit $eventlimit glitchTh $glitchTh ";
		printf("out time,trans $out{time},$out{trans}, prob %f\n", $out{prob});
		print "invalide waveform ";
		print "prob1 is invalid" if($waveProb1<=0 or $waveProb1>1);
		print "prob2 is invalid" if($waveProb2<=0 or $waveProb2>1);
		print "\n";
		exit();
		}
	}
	print "out waveform:$out{time},$out{trans} = $out{prob}\n" if($prtMsgWaveformPropagation>2);

	return(%out);
}

#time-event pair: (t1/t2/t3/t4/t5,e1/e2/e3/e4/e5)
# t is time, "-" equals to very large neg number means minus infinit
# e is transition state, can transit from "0,1,x", 9 transitions in total
# "01"(r),"10"(f),"11"(1),"00"(0),"0x","1x","x0","x1","xx"

# signle event propagation for lastNEventAlgorithm
sub eventPropagation(){
	my($evalTime,$in1Trans,$in2Trans,$gate,$gateDelay)=@_;
	print "eventPropagation: evaltime $evalTime,in1trans $in1Trans,in2trans $in2Trans,gate $gate,gateDelay $gateDelay\n" if($prtMsgEventPropagation>2);
	my($outTime,$outTrans,$outProb,%out);
	
	##change r/f/0/1/x
	#$evalTime = -10000 if($evalTime eq "-");
	# exchange transition pin
	if($in1Trans !~ /\b(01|0x|10|1x|x0|x1)\b/ && $in2Trans =~ /\b(01|0x|10|1x|x0|x1)\b/){
		my $transTmp = $in1Trans;
		$in1Trans = $in2Trans;
		$in2Trans = $transTmp;
	}
	my @in1Trans=split("",$in1Trans);
	my @in2Trans=split("",$in2Trans);
	my @outTrans;
	#print "event:trans_0 $in1Trans[0],$in2Trans[0], trans_1 $in1Trans[1],$in2Trans[1]\n";
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
				$outTrans[$i]	= ($in1Trans[$i] eq "x") ? "x" : ($in1Trans[$i] eq "0") ? "1" : "0";
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
						print "gate $gate has invalid state $i : $in1Trans[$i]\n";
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
			    		$outTrans[$i] = ($in2Trans[$i] eq "x") ? "x" : ($in2Trans[$i] eq "0") ? "1" : "0";
					}
					case "x"{
			    		$outTrans[$i] = $in2Trans[$i] eq "0" ? "1" : "x";
					}
					else{
						print "gate $gate has invalid state $i : $in1Trans[$i]\n";
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
	print "event propagation: outtrans $outTrans[0],$outTrans[1]\n" if($prgMsgEventPropagation);
	$out{time}	= $outTime;
	$out{trans}	= join("",@outTrans);
	print "    --event propagation\: in1\:$in1Trans in2\:$in2Trans @ $evalTime \-\> out\:$out{trans} @ $out{time}\n" if($prtMsgEventPropagation);

	return(%out);
}

sub checkWaveform(){
	my($waveform)=@_;
	my($timeSeq,$eventSeq)=split(/,/,$waveform);
	my @time=split(/\//,$timeSeq);
	my @event=split(/\//,$eventSeq);

	my $error=0;
	#if(!scalar(@event)){
	#	$error++;
	#	print "waveform $waveform is invalid. zero event.\n";
	#}
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

1;
