#!/usr/bin/perl

#foreach sg
#    topo sort to find stem level
#    assign cross-product & recursive sample probsim
#end
sub probsim(){
print "probsim: algorithm $algorithm, glitch_max $glitchTh\n";
	my($sgNodeSort_ref,$conn_ref)=@_;
	foreach my $sgNode(@$sgNodeSort_ref){
	print "sgNode is $sgNode\n";
		sgProbSim($sgNode,$conn_ref);
	}
}

#output: $conn_ref->{$curNode}->{events}="r/f,t,p"
sub sgProbSim(){
	my($sgNode,$conn_ref)=@_;
	print "********************************\nsgProbSim:$sgNode\n********************************\n";
	my ($curNode,%order2Node,%stems,%events);
	#get all nodes(inputs,internals etc) related to current sg
	#$nodes{nodeName}{stem}	: stem level
	#$nodes{nodeName}{order}: dependent order
	#$nodes{nodeName}{prob}	: stem node prob
	#$order2Node{$order}	: $node
	my %nodes=nodesSort($sgNode,$conn_ref);
	foreach my $node(sort keys %nodes){
		my $order = $nodes{$node}{order};
		$order2Node{$order}=$node;
	}
	#initilize %stems
	#for all stem nodes, set update to 1, curCnt = 0, cpNum = 1, nodes
	#my $inputStem = 0;
	$stems{curStemLevel} = 0;
	$stems{backtrace} = 0;
	foreach my $order(sort {$a<=>$b} keys %order2Node){
		my $node = $order2Node{$order};
		my $stemLevel = $nodes{$node}{stem};
		#initialize if $node is stem
		if($stemLevel){
			$stems{curStemLevel} = 1;
			$stems{$stemLevel}{update} = 1;
			$stems{$stemLevel}{curCnt} = 0;
			$stems{$stemLevel}{cpNum}  = 1;
			$stems{$stemLevel}{nodes} .= ",$node";
			$stems{$stemLevel}{nodes} =~ s/^,//;
		}
	}

	while($curNode=getNextNode($curNode,$sgNode,\%stems,\%nodes,\%order2Node)){
		last if(!$curNode);
		if($nodes{$curNode}{stem} > $stems{curStemLevel} && $stems{backtrace}){
			$stems{backtrace} = 0;
		}
		propagate($curNode,$sgNode,\%stems,\%nodes,$conn_ref,\%events);
		#update stemLevel if enter higher level
		if($nodes{$curNode}{stem} && $nodes{$curNode}{stem} >= $stems{curStemLevel}){
			$stems{curStemLevel} = $nodes{$curNode}{stem};
			updateStemEvents(\%events,\%stems,$conn_ref);
		}
		#update curStemLevel cpNum if curStemLevel is in updating
		if($nodes{$curNode}{stem} && $stems{$stems{curStemLevel}}{update}){
			my $eventsNum = scalar(keys %{$conn_ref->{$curNode}->{events}});
			my $oriCpNum = $stems{$stems{curStemLevel}}{cpNum};
			$stems{$stems{curStemLevel}}{cpNum} *= $eventsNum;
			print "    $curNode updates stemLevel $stems{curStemLevel} cpNum by x $eventsNum, from $oriCpNum to $stems{$stems{curStemLevel}}{cpNum}\n";
		}
		if($curNode eq $sgNode){
			print "-N-\n";
		}
		print "\n";
	}
	foreach my $event(sort keys %{$conn_ref->{$sgNode}->{events}}){
		next if($event =~ /^\s*$/);
		print "$event:$conn_ref->{$sgNode}->{events}->{$event}\n";
	}
	print "finish $sgNode with ".scalar(keys %{$conn_ref->{$sgNode}->{events}})." events\n\n";
}

#input: $curNode, $conn_ref
#output: $conn_ref->{$curNode}->{events}->{r/f,t}=p
#algorithm
#get all inputs based on $conn_ref
#if input is input/sg(not curSg), get events
#if input is stem, 
#	if(first time)
#		push to $stems->{stem}
#	else
#		get 1 value based on $stems->{stem}->{curCnt}
sub propagate(){
	my($curNode,$sgNode,$stems_href,$nodes_href,$conn_ref,$events_href)=@_;
	print "----propagate $curNode (sgnode is $sgNode)\n";
	my(%inputEvents);
	#update curStemNodes
	if($conn_ref->{$curNode}->{isSg} && !defined $stems_href->{curStemNodes}->{$curNode}){
		$stems_href->{curStemNodes}->{$curNode} = 1;
	}
	#calculate
	if($conn_ref->{$curNode}->{type} =~ /input/ or ($conn_ref->{$curNode}->{isSg} && $curNode ne $sgNode)){
		print "    input node has been skipped\n";
	}
	elsif($stems_href->{backtrace} && $nodes_href->{$curNode}->{stem}){
		print "    backtrace stem has been skipped\n";
	}
	else{
		#delete previous events first unless sgNode
		delete $conn_ref->{$curNode}->{events} if($curNode ne $sgNode);
		#calculate prob
		my @inputs = split(/\s+/,$conn_ref->{$curNode}->{trace});
		my $gate = $conn_ref->{$curNode}->{gate};
		my %events;
		my $gatedelay = 1;
		$gate =~ s/2?X1//;
		#set all input events
		my $probCnt = 1;
		foreach my $input(@inputs){
			$input =~ s/(\(|\))//g;
			$input =~ s/^[^\=]\=(.*)/$1/;
			if(!$nodes_href->{$input}->{stem}){
				#print "    assign $input inputEvents ".scalar(keys %{$conn_ref->{$input}->{events}})." values";
				$inputEvents{$input} = $conn_ref->{$input}->{events};
			}else{
				#print "    assign $input inputEvents ".scalar(keys %{$events_href->{$input}})." values";
				$inputEvents{$input} = $events_href->{$input};
			}
			#print ", include ".join(";",sort keys %{$inputEvents{$input}})."\n";
			$probCnt *= scalar(keys %{$inputEvents{$input}});
		}
		#calc prob for each cross-product
		my($eventsNum,$remainder,$quotient,$event,$prob,%cpEvent,%cpProb);
		for(my $i=0;$i<$probCnt;$i++){
			#get cp based on $i
			$quotient = $i;
			#foreach my $input(@inputs){
			my ($in1time,$in1Trans,$in1Prob,$in2time,$in2Trans,$in2Prob);
			for(my $i=0;$i<@inputs;$i++){
				my $input = $inputs[$i];
				$eventsNum = scalar(keys %{$inputEvents{$input}});
				$remainder = $quotient%$eventsNum;
				$quotient = $quotient/$eventsNum;
				$cpEvent{$input} = (sort keys %{$inputEvents{$input}})[$remainder];
				$cpProb{$input} = $inputEvents{$input}{$cpEvent{$input}};
				#record stem node event and prob for prob scaling
				if($nodes_href->{$input}->{stem}){
					$nodes_href->{$input}->{event} = $cpEvent{$input};
					$nodes_href->{$input}->{prob}  = $cpProb{$input};
				}
				#print "    assign $input cpevent $cpEvent{$input} to $cpProb{$input}\n";
				if($i == 0){
					($in1Time,$in1Trans)	= split(",",$cpEvent{$input});
					#prob=1 if stem
					$in1Prob		= $nodes_href->{$input}->{stem} ? 1 : $cpProb{$input};
				}elsif($i == 1){
					($in2Time,$in2Trans)	= split(",",$cpEvent{$input});
					#prob=1 if stem
					$in2Prob		= $nodes_href->{$input}->{stem} ? 1 : $cpProb{$input};
				}else{
					print "ERROR: There are more than 2 inputs for this device.\n";
				}
			}
			my ($outTime,$outTrans,$outProb,%out);
			my $gateDelay = 1;
			#propagate prob through a gate
			print "    calc: gate $gate, in1 Time/trans/prob, $in1Time/$in1Trans/$in1Prob, in2 Time/trans/prob, $in2Time/$in2Trans/$in2Prob\n";
			if($algorithm eq "basic"){
				%out = basicAlgorithm($in1Time,$in1Trans,$in1Prob,$in2Time,$in2Trans,$in2Prob,$gate,$gateDelay);
			}
			elsif($algorithm eq "last1"){
				%out = lastOneEventAlgorithm($in1Time,$in1Trans,$in1Prob,$in2Time,$in2Trans,$in2Prob,$gate,$gateDelay);
			}
			$outTime	= $out{time};
			$outTrans	= $out{trans};
			$outProb	= $out{prob};
			#for all stem nodes, find assigned events, find prob, do prob scaling
			if($curNode eq $sgNode){
				my $stemProbScale = 1;
				foreach my $node(sort keys %$nodes_href){
					if($nodes_href->{$node}->{stem} && $node ne $sgNode){
						my $curStemEvent = $nodes_href->{$node}->{event};
						my $curStemProb  = $nodes_href->{$node}->{prob};
						$stemProbScale *= $curStemProb;
						print "    scaling: stem node $node, event $curStemEvent, prob $curStemProb, curStemProbScale $stemProbScale\n";
					}
				}
				$outProb *= $stemProbScale;
			}
			if(!defined $conn_ref->{$curNode}->{events}->{"$outTime,$outTrans"}){
				$conn_ref->{$curNode}->{events}->{"$outTime,$outTrans"} = $outProb;
			}else{
				$conn_ref->{$curNode}->{events}->{"$outTime,$outTrans"} += $outProb;
			}
			print "  --out time/trans/prob $outTime/$outTrans/$outProb, sum ".$conn_ref->{$curNode}->{events}->{"$outTime,$outTrans"}."\n";
		}
	}
	print "----node $curNode has ".scalar(keys %{$conn_ref->{$curNode}->{events}})." events\n";
	foreach my $event (sort keys %{$conn_ref->{$curNode}->{events}}){
		print "    ".$event;
		print "    ".$conn_ref->{$curNode}->{events}->{$event}."\n";
	}
}

#different simulation algorithm

#basic, last dominant event determines
sub basicAlgorithm(){
	my($in1Time,$in1Trans,$in1Prob,$in2Time,$in2Trans,$in2Prob,$gate,$gateDelay)=@_;
	my($outTime,$outTrans,$outProb,%out);
	$in1Time = -10000 if($in1Time eq "-");
	$in2Time = -10000 if($in2Time eq "-");
	if($gate eq "BUF") {
		$outTime	= $in1Time + $gateDelay;
		$outTrans	= $in1Trans;
		$outProb	= $in1Prob;
	}
	elsif($gate eq "INV") {
		$outTime	= $in1Time + $gateDelay;
		$outTrans	= ($in1Trans eq "f") ? "r" : "f";
		$outProb	= $in1Prob;
	}
	elsif($gate eq "AND") {
		if($in1Trans eq "r" && $in2Trans eq "r"){
			$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			$outTrans	= "r";
		}
		elsif($in1Trans eq "r" && $in2Trans eq "f"){
			$outTime	= $in2Time + $gateDelay;
			$outTrans	= "f";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "r"){
			$outTime	= $in1Time + $gateDelay;
			$outTrans	= "f";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "f"){
			$outTime	= ($in1Time > $in2Time ? $in2Time : $in1Time) + $gateDelay;
			$outTrans	= "f";
		}
		else{
			print "AND input in1Trans $in1Trans or in2Trans $in2Trans doesn't make sense.\n";
		}
		$outProb	= $in1Prob * $in2Prob;
	}
	elsif($gate eq "NAND") {
		if($in1Trans eq "r" && $in2Trans eq "r"){
			$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			$outTrans	= "f";
		}
		elsif($in1Trans eq "r" && $in2Trans eq "f"){
			$outTime	= $in2Time + $gateDelay;
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "r"){
			$outTime	= $in1Time + $gateDelay;
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "f"){
			$outTime	= ($in1Time > $in2Time ? $in2Time : $in1Time) + $gateDelay;
			$outTrans	= "r";
		}
		else{
			print "NAND input in1Trans $in1Trans or in2Trans $in2Trans doesn't make sense.\n";
		}
		$outProb = $in1Prob * $in2Prob;
	}
	elsif($gate eq "OR") {
		if($in1Trans eq "r" && $in2Trans eq "r"){
			$outTime	= ($in1Time > $in2Time ? $in2Time : $in1Time) + $gateDelay;
			$outTrans	= "r";
		}
		elsif($in1Trans eq "r" && $in2Trans eq "f"){
			$outTime	= $in1Time + $gateDelay;
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "r"){
			$outTime	= $in2Time + $gateDelay;
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "f"){
			$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			$outTrans	= "f";
		}
		else{
			print "OR input in1Trans $in1Trans or in2Trans $in2Trans doesn't make sense.\n";
		}
		$outProb = $in1Prob * $in2Prob;
	}
	elsif($gate eq "NOR") {
		if($in1Trans eq "r" && $in2Trans eq "r"){
			$outTime	= ($in1Time > $in2Time ? $in2Time : $in1Time) + $gateDelay;
			$outTrans	= "f";
		}
		elsif($in1Trans eq "r" && $in2Trans eq "f"){
			$outTime	= $in1Time + $gateDelay;
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "r"){
			$outTime	= $in2Time + $gateDelay;
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "f"){
			$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			$outTrans	= "r";
		}
		else{
			print "NOR input in1Trans $in1Trans or in2Trans $in2Trans doesn't make sense.\n";
		}
		$outProb = $in1Prob * $in2Prob;
	}
	elsif($gate eq "XOR") {
		if($in1Trans eq "r" && $in2Trans eq "r"){
			if($in1Time eq $in2Time){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "f";
		}
		elsif($in1Trans eq "r" && $in2Trans eq "f"){
			if($in1Time eq $in2Time){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "r"){
			if($in1Time eq $in2Time){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "f"){
			if($in1Time eq $in2Time){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "f";
		}
		else{
			print "XOR input in1Trans $in1Trans or in2Trans $in2Trans doesn't make sense.\n";
		}
		$outProb = $in1Prob * $in2Prob;
	}
	elsif($gate eq "XNOR") {
		if($in1Trans eq "r" && $in2Trans eq "r"){
			if($in1Time eq $in2Time){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "r";
		}
		elsif($in1Trans eq "r" && $in2Trans eq "f"){
			if($in1Time eq $in2Time){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "f";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "r"){
			if($in1Time eq $in2Time){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "f";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "f"){
			if($in1Time eq $in2Time){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "r";
		}
		else{
			print "XNOR input in1Trans $in1Trans or in2Trans $in2Trans doesn't make sense.\n";
		}
		$outProb = $in1Prob * $in2Prob;
	}
	else{
		print "ERROR:Gate $gate is not supported!\n";
	}
	$outTime = "-" if($outTime < 0);

	$out{time}	= $outTime;
	$out{trans}	= $outTrans;
	$out{prob}	= $outProb;

	return(%out);
}

#only consider the effects of the last one event of every node
sub lastOneEventAlgorithm(){
	my($in1Time,$in1Trans,$in1Prob,$in2Time,$in2Trans,$in2Prob,$gate,$gateDelay,$glitchTh)=@_;
	my($outTime,$outTrans,$outProb,%out);
	$in1Time = -10000 if($in1Time eq "-");
	$in2Time = -10000 if($in2Time eq "-");
	if($gate eq "BUF") {
		$outTime	= $in1Time + $gateDelay;
		$outTrans	= $in1Trans;
		$outProb	= $in1Prob;
	}
	elsif($gate eq "INV") {
		$outTime	= $in1Time + $gateDelay;
		$outTrans	= ($in1Trans eq "f") ? "r" : "f";
		$outProb	= $in1Prob;
	}
	elsif($gate eq "AND") {
		if($in1Trans eq "r" && $in2Trans eq "r"){
			$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			$outTrans	= "r";
		}
		elsif($in1Trans eq "r" && $in2Trans eq "f"){
			if( $in1Time >= $in2Time or ($in2Time-$in1Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= $in2Time + $gateDelay;
			}
			$outTrans	= "f";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "r"){
			if( $in2Time >= $in1Time or ($in1Time-$in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= $in1Time + $gateDelay;
			}
			$outTrans	= "f";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "f"){
			$outTime	= ($in1Time > $in2Time ? $in2Time : $in1Time) + $gateDelay;
			$outTrans	= "f";
		}
		else{
			print "AND input in1Trans $in1Trans or in2Trans $in2Trans doesn't make sense.\n";
		}
		$outProb	= $in1Prob * $in2Prob;
	}
	elsif($gate eq "NAND") {
		if($in1Trans eq "r" && $in2Trans eq "r"){
			$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			$outTrans	= "f";
		}
		elsif($in1Trans eq "r" && $in2Trans eq "f"){
			if( $in1Time >= $in2Time or ($in2Time-$in1Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= $in2Time + $gateDelay;
			}
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "r"){
			if( $in2Time >= $in1Time or ($in1Time-$in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= $in1Time + $gateDelay;
			}
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "f"){
			$outTime	= ($in1Time > $in2Time ? $in2Time : $in1Time) + $gateDelay;
			$outTrans	= "r";
		}
		else{
			print "NAND input in1Trans $in1Trans or in2Trans $in2Trans doesn't make sense.\n";
		}
		$outProb = $in1Prob * $in2Prob;
	}
	elsif($gate eq "OR") {
		if($in1Trans eq "r" && $in2Trans eq "r"){
			$outTime	= ($in1Time > $in2Time ? $in2Time : $in1Time) + $gateDelay;
			$outTrans	= "r";
		}
		elsif($in1Trans eq "r" && $in2Trans eq "f"){
			if( $in2Time >= $in1Time or ($in1Time-$in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= $in1Time + $gateDelay;
			}
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "r"){
			if( $in1Time >= $in2Time or ($in2Time-$in1Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= $in2Time + $gateDelay;
			}
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "f"){
			$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			$outTrans	= "f";
		}
		else{
			print "OR input in1Trans $in1Trans or in2Trans $in2Trans doesn't make sense.\n";
		}
		$outProb = $in1Prob * $in2Prob;
	}
	elsif($gate eq "NOR") {
		if($in1Trans eq "r" && $in2Trans eq "r"){
			$outTime	= ($in1Time > $in2Time ? $in2Time : $in1Time) + $gateDelay;
			$outTrans	= "f";
		}
		elsif($in1Trans eq "r" && $in2Trans eq "f"){
			if( $in2Time >= $in1Time or ($in1Time-$in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= $in1Time + $gateDelay;
			}
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "r"){
			if( $in1Time >= $in2Time or ($in2Time-$in1Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= $in2Time + $gateDelay;
			}
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "f"){
			$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			$outTrans	= "r";
		}
		else{
			print "NOR input in1Trans $in1Trans or in2Trans $in2Trans doesn't make sense.\n";
		}
		$outProb = $in1Prob * $in2Prob;
	}
	elsif($gate eq "XOR") {
		if($in1Trans eq "r" && $in2Trans eq "r"){
			if(abs($in1Time - $in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "f";
		}
		elsif($in1Trans eq "r" && $in2Trans eq "f"){
			if(abs($in1Time - $in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "r"){
			if(abs($in1Time - $in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "f"){
			if(abs($in1Time - $in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "f";
		}
		else{
			print "XOR input in1Trans $in1Trans or in2Trans $in2Trans doesn't make sense.\n";
		}
		$outProb = $in1Prob * $in2Prob;
	}
	elsif($gate eq "XNOR") {
		if($in1Trans eq "r" && $in2Trans eq "r"){
			if(abs($in1Time - $in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "r";
		}
		elsif($in1Trans eq "r" && $in2Trans eq "f"){
			if(abs($in1Time - $in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "f";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "r"){
			if(abs($in1Time - $in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "f";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "f"){
			if(abs($in1Time - $in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "r";
		}
		else{
			print "XNOR input in1Trans $in1Trans or in2Trans $in2Trans doesn't make sense.\n";
		}
		$outProb = $in1Prob * $in2Prob;
	}
	else{
		print "ERROR:Gate $gate is not supported!\n";
	}
	$outTime = "-" if($outTime < 0);

	$out{time}	= $outTime;
	$out{trans}	= $outTrans;
	$out{prob}	= $outProb;

	return(%out);
}


#last two event
sub lastTwoEventAlgorithm(){
	my($in1Time,$in1Trans,$in1Prob,$in2Time,$in2Trans,$in2Prob,$gate,$gateDelay,$glitchTh)=@_;
	my($outTime,$outTrans,$outProb,%out);
	$in1Time = -10000 if($in1Time eq "-");
	$in2Time = -10000 if($in2Time eq "-");
	if($gate eq "BUF") {
		$outTime	= $in1Time + $gateDelay;
		$outTrans	= $in1Trans;
		$outProb	= $in1Prob;
	}
	elsif($gate eq "INV") {
		$outTime	= $in1Time + $gateDelay;
		$outTrans	= ($in1Trans eq "f") ? "r" : "f";
		$outProb	= $in1Prob;
	}
	elsif($gate eq "AND") {
		if($in1Trans eq "r" && $in2Trans eq "r"){
			$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			$outTrans	= "r";
		}
		elsif($in1Trans eq "r" && $in2Trans eq "f"){
			if( $in1Time >= $in2Time or ($in2Time-$in1Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= $in2Time + $gateDelay;
			}
			$outTrans	= "f";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "r"){
			if( $in2Time >= $in1Time or ($in1Time-$in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= $in1Time + $gateDelay;
			}
			$outTrans	= "f";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "f"){
			$outTime	= ($in1Time > $in2Time ? $in2Time : $in1Time) + $gateDelay;
			$outTrans	= "f";
		}
		else{
			print "AND input in1Trans $in1Trans or in2Trans $in2Trans doesn't make sense.\n";
		}
		$outProb	= $in1Prob * $in2Prob;
	}
	elsif($gate eq "NAND") {
		if($in1Trans eq "r" && $in2Trans eq "r"){
			$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			$outTrans	= "f";
		}
		elsif($in1Trans eq "r" && $in2Trans eq "f"){
			if( $in1Time >= $in2Time or ($in2Time-$in1Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= $in2Time + $gateDelay;
			}
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "r"){
			if( $in2Time >= $in1Time or ($in1Time-$in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= $in1Time + $gateDelay;
			}
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "f"){
			$outTime	= ($in1Time > $in2Time ? $in2Time : $in1Time) + $gateDelay;
			$outTrans	= "r";
		}
		else{
			print "NAND input in1Trans $in1Trans or in2Trans $in2Trans doesn't make sense.\n";
		}
		$outProb = $in1Prob * $in2Prob;
	}
	elsif($gate eq "OR") {
		if($in1Trans eq "r" && $in2Trans eq "r"){
			$outTime	= ($in1Time > $in2Time ? $in2Time : $in1Time) + $gateDelay;
			$outTrans	= "r";
		}
		elsif($in1Trans eq "r" && $in2Trans eq "f"){
			if( $in2Time >= $in1Time or ($in1Time-$in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= $in1Time + $gateDelay;
			}
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "r"){
			if( $in1Time >= $in2Time or ($in2Time-$in1Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= $in2Time + $gateDelay;
			}
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "f"){
			$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			$outTrans	= "f";
		}
		else{
			print "OR input in1Trans $in1Trans or in2Trans $in2Trans doesn't make sense.\n";
		}
		$outProb = $in1Prob * $in2Prob;
	}
	elsif($gate eq "NOR") {
		if($in1Trans eq "r" && $in2Trans eq "r"){
			$outTime	= ($in1Time > $in2Time ? $in2Time : $in1Time) + $gateDelay;
			$outTrans	= "f";
		}
		elsif($in1Trans eq "r" && $in2Trans eq "f"){
			if( $in2Time >= $in1Time or ($in1Time-$in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= $in1Time + $gateDelay;
			}
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "r"){
			if( $in1Time >= $in2Time or ($in2Time-$in1Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= $in2Time + $gateDelay;
			}
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "f"){
			$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			$outTrans	= "r";
		}
		else{
			print "NOR input in1Trans $in1Trans or in2Trans $in2Trans doesn't make sense.\n";
		}
		$outProb = $in1Prob * $in2Prob;
	}
	elsif($gate eq "XOR") {
		if($in1Trans eq "r" && $in2Trans eq "r"){
			if(abs($in1Time - $in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "f";
		}
		elsif($in1Trans eq "r" && $in2Trans eq "f"){
			if(abs($in1Time - $in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "r"){
			if(abs($in1Time - $in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "r";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "f"){
			if(abs($in1Time - $in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "f";
		}
		else{
			print "XOR input in1Trans $in1Trans or in2Trans $in2Trans doesn't make sense.\n";
		}
		$outProb = $in1Prob * $in2Prob;
	}
	elsif($gate eq "XNOR") {
		if($in1Trans eq "r" && $in2Trans eq "r"){
			if(abs($in1Time - $in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "r";
		}
		elsif($in1Trans eq "r" && $in2Trans eq "f"){
			if(abs($in1Time - $in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "f";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "r"){
			if(abs($in1Time - $in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "f";
		}
		elsif($in1Trans eq "f" && $in2Trans eq "f"){
			if(abs($in1Time - $in2Time) <= $glitchTh){
				$outTime	= "-";
			}else{
				$outTime	= ($in1Time > $in2Time ? $in1Time : $in2Time) + $gateDelay;
			}
			$outTrans	= "r";
		}
		else{
			print "XNOR input in1Trans $in1Trans or in2Trans $in2Trans doesn't make sense.\n";
		}
		$outProb = $in1Prob * $in2Prob;
	}
	else{
		print "ERROR:Gate $gate is not supported!\n";
	}
	$outTime = "-" if($outTime < 0);

	$out{time}	= $outTime;
	$out{trans}	= $outTrans;
	$out{prob}	= $outProb;

	return(%out);
}

#assign/update values to stem nodes based on curStemLevel and curCnt
#update if cnt change
sub updateStemEvents(){
print "----update stem events\n";
	my($events_href,$stems_href,$conn_ref)=@_;
	my $curStemLevel = $stems_href->{curStemLevel};
	my $curCnt = $stems_href->{$curStemLevel}->{curCnt};
	my $nodes = $stems_href->{$curStemLevel}->{nodes};
	my ($quotient,$remainder,$eventsNum);
	$quotient = $curCnt;
	foreach my $node(split(/,/,$nodes)){
		my $eventsNum = scalar(keys %{$conn_ref->{$node}->{events}});
		last if(!$eventsNum);
		$remainder = $quotient%$eventsNum;
		$quotient = $quotient/$eventsNum;
		$event = (sort keys %{$conn_ref->{$node}->{events}})[$remainder];
		$prob = $conn_ref->{$node}->{events}->{$event};
		delete $events_href->{$node};
		$events_href->{$node}->{$event} = $prob;
	}
	print "    curStemLevel is $curStemLevel, curCnt is $curCnt\n";
}

#%state
#$stems->{0}->{active}
#$stems->{0}->{curCnt}
#$stems->{0}->{cpNum}
#$stems->{0}->{nodes}
sub getNextNode(){
print "----getNextNode\n";
	my($curNode,$sgNode,$stems_href,$nodes_href,$order2Node_href)=@_;
	my $nextNode;
	#if in progress, find next in order
	if($curNode ne $sgNode){
		my $nextOrder = $curNode ? ($nodes_href->{$curNode}->{order} + 1) : 0;
		$nextNode = $order2Node_href->{$nextOrder};
	}
	#if reach the end, get new cross-product
	else{
		print "    get new cp\n";
		for(my $stemLevel = $stems_href->{curStemLevel};$stemLevel>0;$stemLevel--){
			$stems_href->{$stemLevel}->{curCnt} += 1;
			$stems_href->{backtrace} = 1;
			print "    getNextNode: check stemLevel $stemLevel; curCnt $stems_href->{$stemLevel}->{curCnt}, cp $stems_href->{$stemLevel}->{cpNum}\n";
			if($stems_href->{$stemLevel}->{curCnt} >= $stems_href->{$stemLevel}->{cpNum}){
				#reset current stem level if it has been fully visited
				print "    current stemLevel $stemLevel is full, go back\n";
				$stems_href->{$stemLevel}->{cpNum}	= 1;
				$stems_href->{$stemLevel}->{curCnt}	= 0;
				$stems_href->{$stemLevel}->{update}	= 1;
				$stems_href->{curStemLevel} += -1;
				next;
			}else{
				#return current level smallest _changed_! node
				$stems_href->{$stemLevel}->{update} = 0;
				my @stemsNode=split(",",$stems_href->{$stemLevel}->{nodes});
				$nextNode = $stemsNode[0];
				#update %events based on $stems_href->{$stemLevel}->{curCnt}
				#updateStemEvents();
				last;
			}
		}
	}
	print "    get node $nextNode\n";
	return $nextNode;
}

#inputs: sg out,%conn
#output: %nodes->{nodeName}->{stem}	: stem level
#              ->{nodeName}->{order}	: dependent order
#topological sort
sub nodesSort(){
	my($sgNode,$conn_ref) = @_;
	#topological sort, record order
	#record dependent inputs
	my(@dfsQueue,%finishTime,%nodes);
	local $dfsCnt = 0;
	push(@dfsQueue,$sgNode);
	slDfs($conn_ref,\@dfsQueue,\%finishTime,$sgNode);

	my %finishTime_rev= reverse(%finishTime);
	#return nets order by finishTime
	foreach my $order(sort {$a<=>$b} keys %finishTime_rev){
		my $node = $finishTime_rev{$order};
		$nodes{$node}{order}=$order;
	}

	#assign input to level 0
	#assign input stem to level 1
	#assign net level to max input level
	foreach my $order(sort {$a<=>$b} keys %finishTime_rev){
		my $currentNode = $finishTime_rev{$order};
		if($$conn_ref{$currentNode}{type} eq "input" or ($$conn_ref{$currentNode}{isSg} && $currentNode ne $sgNode)){
			$nodes{$currentNode}{stem} = 1;
		}else{
			my $trace = $$conn_ref{$currentNode}{trace};
			$trace  =~ s/(^\(|\)$)//g;
			my @inputs = split(/\s+/,$trace);
			my $input;
			while(@inputs){
				$input = shift(@inputs);
				$input =~ s/^\w+\=(.*)/$1/;
				if(!defined $nodes{$currentNode}{stem}){
					$nodes{$currentNode}{stem} = $nodes{$input}{stem};
				}elsif($nodes{$currentNode}{stem}<=$nodes{$input}{stem}){
					$nodes{$currentNode}{stem} = $nodes{$input}{stem};
					$nodes{$currentNode}{stem} += 1 if($$conn_ref{$currentNode}{stem});
				}
			}
		}
	}

	foreach my $node(sort keys %nodes){
		$nodes{$node}{stem} = 0 if(!$$conn_ref{$node}{stem});
	}

	return %nodes;
}

#update %finishTime, $$conn_ref{$nodeName}{stem},
sub slDfs(){
	my ($conn_ref,$dfsQueue_ref,$finishTime_ref,$sgNode) = @_;
	return if(@$dfsQueue_ref == 0);
	my $currentNode = pop(@$dfsQueue_ref);
	my $trace = $$conn_ref{$currentNode}{trace};
	#if input or sgnode, then finish
	if(defined $$finishTime_ref{$currentNode}){
		$$conn_ref{$currentNode}{stem} = 1;
	}elsif(!$trace){
		$$finishTime_ref{$currentNode} = $dfsCnt++;
	}elsif($$conn_ref{$currentNode}{isSg} && ($currentNode ne $sgNode)){
		$$finishTime_ref{$currentNode} = $dfsCnt++;
	}else{
		$trace  =~ s/(^\(|\)$)//g;
		#print "trace:$trace\n";
		my @inputs = split(/\s+/,$trace);
		my $input;
		while(@inputs){
			$input = shift(@inputs);
			$input =~ s/^\w+\=(.*)/$1/;
			push(@$dfsQueue_ref,$input);
			slDfs($conn_ref,$dfsQueue_ref,$finishTime_ref,$sgNode);
		}
		$$finishTime_ref{$currentNode} = $dfsCnt++;
	}
}

1;
