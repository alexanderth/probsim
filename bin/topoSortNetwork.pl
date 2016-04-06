#!/usr/bin/perl

# input is $network_href and $output
# output is %sortInfo -> $sortInfo{<netName>}{finishTime}
#                     -> $sortInfo{<netName>}{multidrive}

sub topoSortNetwork(){
	my($network_href,$outNode) = @_;
	#topological sort
	my(%sortInfo);
	local $dfsCnt = 1;
	topoSortNetworkDfs($outNode,$network_href,\%sortInfo);

	if($prtMsgTopoSortNetwork){
		print "topoSortNetwork($outNode)\n";
		foreach my $net(sort {$sortInfo{$a}{finishTime}<=>$sortInfo{$b}{finishTime}} keys %sortInfo){
			print "finishTime $sortInfo{$net}{finishTime} net $net multidrive $sortInfo{$net}{multidrive}\n";
		}
		print "end of toposortNetwork\n\n";
	}

	return %sortInfo;
}

sub topoSortNetworkDfs(){
	my ($curNode,$network_href,$sortInfo_href) = @_;
	if(defined $$sortInfo_href{$curNode}{finishTime}){
		$$sortInfo_href{$curNode}{multidrive}++;
		return;
	}
	my $trace = $$network_href{$curNode}{trace};
	#if input, then finish
	if($trace){
		$trace  =~ s/^\(|\)$//g;
		foreach my $input(split(/\s+/,$trace)){
			$input =~ s/^\w+\=(.*)/$1/;
			topoSortNetworkDfs($input,$network_href,$sortInfo_href);
		}
	}
	$$sortInfo_href{$curNode}{finishTime} = $dfsCnt;
	#$$network_href{$curNode}{finishTime} = $dfsCnt;
	$dfsCnt++;
}

1;
