#!/usr/bin/perl

#use lib '/home/xiaoliac/bin/perl/lib/';
use lib '/projects/analog_oa/users/xiaoliac/cds/digital/probSim/scripts/lib/';
use PROBSIM;
require "src/sgProbSim.pl";

# input clean $network_href, $outNode
sub hierPartitionAndSim(){
	my($network_href, $outNode, $stemlimit, $depthlimit, $wavelimit, $eventlimit, $glitchTh, $noMergeNet)=@_;
	print "\n++++++++++++++++++++\nhierPartitionAndSim \($partitionCnt\)\n++++++++++++++++++++\n" if($prtMsgHierPartitionAndSim);
	foreach my $net(sort keys %{$network_href}){
		print "    hierPartitionAndSim:net $net type $$network_href{$net}{type} isSg $$network_href{$net}{isSg} trace $$network_href{$net}{trace}\n" if($prtMsgHierPartitionAndSim);
	}
	print "outNode $outNode, network_href $network_href, stemlimit $stemlimit, depthlimit $depthlimit wavelimit $wavelimit eventlimit $eventlimit\n" if($prtMsgHierPartitionAndSim);

	my $partition = 0;
	#supergate partition
	if(!$partition){
		$partition = findSgNet($network_href,$outNode);
		$partitionCnt++ if($partition);
		print $partitionCnt x '-'."partition of findSgNet is $partition\n" if($prtMsgHierPartitionAndSim);
	}
	#stem depth partition
	if(!$partition){
		$partition = limitStem($network_href,$outNode,$stemlimit);
		$partitionCnt++ if($partition);
		print $partitionCnt x '-'."partition of limitStem is $partition\n" if($prtMsgHierPartitionAndSim);
	}
	#path depth partition
	if(!$partition){
		$partition = limitDepth($network_href,$outNode,$depthlimit);
		$partitionCnt++ if($partition);
		print $partitionCnt x '-'."partition of limitDepth is $partition\n" if($prtMsgHierPartitionAndSim);
	}
	##stem number partition, not implemented

	# if partition, split %network and do hierPartitionAndSim()
	if($partition){
		my %nodeInfo=topoSortNetwork($network_href,$outNode);#added mutlidrive
		#prt msg
		if($prtMsgHierPartitionAndSim){
			print "partition nodeInfo:";
			foreach my $net(sort {$nodeInfo{$a}{finishTime}<=>$nodeInfo{$b}{finishTime}} keys %nodeInfo){
				print "$net " if($$network_href{$net}{isSg});
			}
			print "\n";
		}
		foreach my $net(sort {$nodeInfo{$a}{finishTime}<=>$nodeInfo{$b}{finishTime}} keys %nodeInfo){
			if($$network_href{$net}{isSg}){
				my %networkPartitioned=buildNetwork($network_href,$net);
				#if($prtMsgHierPartitionAndSim){
				#	print "->partitioned sgNet $net includes net" if($prtMsgHierPartitionAndSim);
				#	foreach my $n(sort keys %networkPartitioned){
				#		print " $n" if($networkPartitioned{$n}{isSg} or $networkPartitioned{$n}{type} eq "input");
				#	}
				#	print "\n" if($prtMsgHierPartitionAndSim);
				#}
				hierPartitionAndSim(\%networkPartitioned,$net,$stemlimit,$depthlimit,$wavelimit,$eventlimit,$glitchTh, $noMergeNet);
				$$network_href{$net}{waveform} = $networkPartitioned{$net}{waveform};
			}
		}
		$partitionCnt--;
	}
	# else sim and back annotate sim results
	else{
		print "<-sgProbsim $outNode\n" if($prtMsgHierPartitionAndSim);
		sgProbSim($outNode,$network_href,$eventlimit,$wavelimit,$glitchTh,$noMergeNet) if($sgProbSim);
	}
}

1;
