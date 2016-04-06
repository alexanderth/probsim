#!/usr/bin/perl

#input is $conn_ref,$sgNodes_ref and $output
#output is enhanced %sgNodes, includes
#$sgNodes{$nodeName}{order}
#$sgNodes{$nodeName}{inputs}{INPUTNAME}

sub sgsort(){
	my($conn_ref, $sgNodes_ref, $output) = @_;
	#topological sort, record order
	#record dependent inputs
	my(@dfsQueue,%finishTime,%sgNodesOrder,@sgNodesSort);
	local $dfsCnt = 1;
	ssDfs($output,$conn_ref,\%finishTime);

	foreach my $node(keys %$sgNodes_ref){
		$sgNodesOrder{$finishTime{$node}} = $node;
		print "sgnode $node finish time is $finishTime{$node}\n" if($verbose > 2);
	}
	#changed by xiaoliac@20140411
	#should be topological order, first finish higher depth
	foreach my $order(sort {$a<=>$b} keys %sgNodesOrder){
		push(@sgNodesSort,$sgNodesOrder{$order}) if($order =~ /\d+/);
	}

	return @sgNodesSort;
}

sub ssDfs(){
	my ($curNode,$conn_ref,$finishTime_ref) = @_;
	if(defined $$finishTime_ref{$curNode}){
		$$conn_ref{$curNode}{multidrive}  = 1;
		return;
	}
	print "ssDfs start: $curNode\n" if($verbose>3);
	my $trace = $$conn_ref{$curNode}{trace};
	#if input, then finish
	if($trace){
		$trace  =~ s/^\(|\)$//g;
		foreach my $input(split(/\s+/,$trace)){
			$input =~ s/^\w+\=(.*)/$1/;
			ssDfs($input,$conn_ref,$finishTime_ref);
		}
	}
	$$finishTime_ref{$curNode} = $dfsCnt;
	$$conn_ref{$curNode}{finishTime} = $dfsCnt;
	$dfsCnt++;
	print "ssDfs finish: $curNode at $$finishTime_ref{$curNode}\n" if($verbose>3);
}

1;
