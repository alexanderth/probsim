#!/usr/bin/perl

# input is fresh $network_href
# output is annotated $network_href with isSg
sub findSgNet(){
	my($network_href,$outNet)=@_;

	# build %lcgraph
	my %lcgraph = network2lcgraph($network_href);
	#if($verbose > 10){
	#	foreach my $net(sort keys %$conn_ref){
	#		print "\t$net";
	#	}
	#	print "\n";
	#	foreach my $curNet(sort keys %$conn_ref){
	#	print "$curNet\t";
	#		foreach my $net(sort keys %$conn_ref){
	#			if($lcgraph{"$curNet\=$net"}){
	#				print "Y\t";
	#			}else{
	#				print "N\t";
	#			}
	#		}
	#	print "\n";
	#	}
	#}

	# sgDfs to find sg node
	local $dfsCnt = 1;
	my (%visited, %dfs, %low, %parent, %sgNodes);
	findSgNetDfs(\%lcgraph,$outNet,\%visited,\%dfs,\%low,\%parent,\%sgNodes);
	#update $network_href
	my $sgCnt=0;
	foreach my $node(keys %sgNodes){
		$$network_href{$node}{isSg} = 1;
		$sgCnt++;
	}
	my $addSg = $sgCnt>2 ? 1 : 0;#outNode is sg
	
	return($addSg);
}

sub findSgNetDfs(){
	my ($lcgraph_ref,$curNode,$visited_ref,$dfs_ref,$low_ref,$parent_ref,$sgNodes_ref) = @_;
	my $curNodeDfs = $dfsCnt++;
	my $curNodeLow = $curNodeDfs;
	$$dfs_ref{$curNode} = $curNodeDfs;
	$$low_ref{$curNode} = $curNodeLow;
	$$visited_ref{$curNode} = 1;
#print "sg dfs $curNode\n";
	foreach my $edge(sort keys %$lcgraph_ref){
		next if(!$$lcgraph_ref{$edge});
		next if($edge !~ /^$curNode\=/);
		$edge =~ /^$curNode\=(.*)/;
		my $neighNode = $1;
		#print "curNode is $curNode: neighNode is $neighNode, visited is $$visited_ref{$neighNode}\n";
		$$parent_ref{$neighNode} = $curNode if(!$$visited_ref{$neighNode});
		#dfs if notvisited
		#else update current low
		if(!$$visited_ref{$neighNode}){
			findSgNetDfs($lcgraph_ref,$neighNode,$visited_ref,$dfs_ref,$low_ref,$parent_ref,$sgNodes_ref);
			$$low_ref{$curNode} = $$low_ref{$neighNode} if($$low_ref{$curNode} > $$low_ref{$neighNode});
			#print "curnode dfs is $$dfs_ref{$curNode}, neighbour low is $$low_ref{$neighNode}\n";
			$$sgNodes_ref{$curNode} = 1 if($$low_ref{$neighNode} >= $$dfs_ref{$curNode});
		}
		elsif($$parent_ref{$curNode} ne $neighNode){
			$$low_ref{$curNode} = $$dfs_ref{$neighNode} if($$low_ref{$curNode} > $$dfs_ref{$neighNode});
			#print "low $curNode is $$low_ref{$curNode}\n";
		}
	}
}

#input is a ref to %network
#transform a %$network_href to lc-graph
#lc-graph
#1. all inputs to output have connections
#2. all inputs of the same gate have connections
sub network2lcgraph(){
	print "network2lcgraph started at ".(localtime)."\n" if($verbose>1);
	my ($network_href) = @_;
	my %lcgraph;
	
	foreach my $net(sort keys %$network_href) {
		next if($$network_href{$net}{type} =~ /input/);
		my @inputs = split(/\s+/,$$network_href{$net}{trace});
		#create edge between input and output
		foreach my $input(@inputs){
			$input =~ s/(\(|\))//g;
			$input =~ s/^[^\=]\=(.*)/$1/;
			$lcgraph{"$input\=$net"} = 1;
			$lcgraph{"$net\=$input"} = 1;
		}
		#create edge between inputs
		foreach my $curInput(@inputs){
			foreach my $input(@inputs){
				$lcgraph{"$curInput\=$input"} = 1;
			}
		}
	}
	print "network2lcgraph finished at ".(localtime)."\n" if($verbose>1);
	
	if($prtMsgNetwork2lcgraph){
		foreach my $net(sort keys %$network_href){
			print "\t$net";
		}
		print "\n";
		foreach my $curNet(sort keys %$network_href){
		print "$curNet\t";
			foreach my $net(sort keys %$network_href){
				if($lcgraph{"$curNet\=$net"}){
					print "Y\t";
				}else{
					print "N\t";
				}
			}
		print "\n";
		}
	}

	return %lcgraph;
}

1;
