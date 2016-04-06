#!/usr/bin/perl

package PROBSIM;

use Exporter;
@ISA = qw(Exporter);
#@EXPORT = qw(readConn readBench readVerilog readWave buildNetwork findSgNet topoSortNetwork limitStem limitDepth mprint);
@EXPORT = qw(readConn readBench readVerilog readWave buildNetwork findSgNet topoSortNetwork limitStem limitDepth);

#require "src/readConn.pl";
#require "src/readBench.pl";
#require "src/readWave.pl";
#require "src/buildNetwork.pl";
#require "src/topoSortNetwork.pl";
#require "src/findSgNet.pl";
#require "src/limitStem.pl";
#require "src/limitDepth.pl";
  
#require "src/hierPartitionAndSim.pl";

#connection information
# %conn
#      ->{pin}{type}   input/output/internal
#      ->{pin}{order}  order in input line
#      ->{pin}{gate}   XOR2X1...
#      ->{pin}{trace}  (A=in0 B=[125])
sub readConn{
	my ($connfile) = @_;
	my %conn;
	my $inOrder = 1;
	my $outOrder = 0;
	local(*INFILE);
	open(INFILE,"$connfile") or die("Can't open infile $connfile\n$!");
	while(!eof(INFILE)){
		my $line = <INFILE>;
		next if($line =~ /^\/\/|^\s*$/);
		if($line =~ /primary (input|output)s:\s*(.*)/){
			my $type = $1;
			foreach my $pin(split(/\s+/,$2)){
				$pin =~ s/(\{|\}|\s)//g;
				$conn{$pin}{type} = $type;
				if($type =~ /input/){
					$conn{$pin}{order} = $inOrder;
					$inOrder++;
				}
			}
		}
		elsif($line =~ /^\s*(\S+)\s+(\S+)\s+\S+\s+(.*)$/){
			my $pin = $1;
			my $gate = $2;
			my $trace = $3;
			#$pin =~ s/(\{|\}|\s|_)//g;
			#$trace =~ s/_//g;
			$conn{$pin}{type}  = "internal" if(!$conn{$pin}{type});
			$conn{$pin}{gate}  = $gate;
			$conn{$pin}{trace} = $trace;
		}
		else{
			print "ERROR: can't handle line $line";
		}
	}
	close(INFILE);

	return %conn;
}

#v0.1
#returns error message if there are more than 3 inputs
#connection information
# %conn
#      ->{pin}{type}   input/output/internal
#      ->{pin}{order}  order in input line
#      ->{pin}{gate}   XOR2X1...
#      ->{pin}{trace}  (A=in0 B=[125])
sub readBench{
	my($benchFile) = @_;
	my %conn=();
	my $inOrder = 1;
	my $outOrder = 0;
	local(*INFILE);
	open(INFILE,"$benchFile") or die("Can't open infile $benchFile\n$!");
	while(!eof(INFILE)){
		my $line = <INFILE>;
		next if($line =~ /^\s*(\#|$)/);
		if($line =~ /^(INPUT|OUTPUT)\((\d+)\)/){
			my $type = lc($1);
			my $pin = $2;
			$conn{$pin}{type} = $type;
			if($type =~ /input/){
				$conn{$pin}{order} = $inOrder;
				$inOrder++;
			}
		}elsif($line =~ /^(\d+)\s+\=\s+(\w+)\((\d+)\)/){
			my $pin = $1;
			my $gate = $2;
			my $trace = "(A=$3)";
			$conn{$pin}{type}  = "internal" if(!$conn{$pin}{type});
			$conn{$pin}{gate}  = $gate;
			$conn{$pin}{trace} = $trace;
		}elsif($line =~ /^(\d+)\s+\=\s+(\w+)\((\d+),\s*(\d+)\)/){
			my $pin = $1;
			my $gate = $2;
			my $trace = "(A=$3 B=$4)";
			$conn{$pin}{type}  = "internal" if(!$conn{$pin}{type});
			$conn{$pin}{gate}  = $gate;
			$conn{$pin}{trace} = $trace;
		}else{
			print "Can't handle line $line";
		}
	}
	close(INFILE);

	return(%conn);
}

#connection information
# %conn
#      ->{pin}{type}   input/output/internal
#      ->{pin}{order}  order in input line
#      ->{pin}{gate}   XOR2X1...
#      ->{pin}{trace}  (A=in0 B=[125])
sub readVerilog{
	my($netlist) = @_;
	my %conn=();
	my $order = 1;
	local(*INFILE);
	open(INFILE,"$netlist") or die("Can't open infile $netlist\n$!");
	while(my $line=get_a_verilog_line(INFILE)){
		next if($line =~ /^\s*(\/\/|$)/);
		if($line =~ /^\s*(input|output)([^\;]+);/){
			my $type = $1;
			my $pins = $2;
			foreach my $pin(split(/[,\s]+/,$pins)){
				$conn{$pin}{type} = $type;
				#if($type =~ /input/){
					$conn{$pin}{order} = $order;
					$order++;
				#}
			}
		}
		#1:gate 2:inst 3:netA 4:connB 5:netB 6:netY
		elsif($line =~ /^\s*(\w+)\s+(\w+)\s*\(\.A\((\w+)\),\s*(\.B\((\w+)\),\s*)?\.Y\((\w+)\)\)\;/){
			my $pin = $6;
			my $gate = $1;
			my $trace = "A=$3";
			$trace .= " B=$5" if($5);
			$trace = "($trace)";
			$conn{$pin}{type}  = "internal" if(!$conn{$pin}{type});
			$conn{$pin}{gate}  = $gate;
			$conn{$pin}{trace} = $trace;
		}elsif($line =~ /^\s*(wire|module|endmodule)/){
		}else{
			print "Can't handle line $line\n";
		}
	}
	close(INFILE);

	return(%conn);
}

sub get_a_verilog_line{
	my($fp)=@_;

	my $saveline = <$fp>;
	if($saveline !~ /^\s*$|^\s*\/\/|endmodule/){
		while($saveline !~ /;\s*$/){
			$saveline .= <$fp>;
		}
	}

	$saveline =~ s/\n/ /g;
	return $saveline;
}

# add "timeSeq,transSeq" -> prob to $network_href
sub readWave{
	my($wavefile,$network_href)=@_;

	my $nodeName;
	my $wavestart = 0;
	local(*FP);
	open(FP,"$wavefile") or die("Can't open file $wavefile\n$!");
	while(my $line=<FP>){
		if($line =~ /^node\s+:\s+([^\s]+)/){
			$nodeName = $1;
			$wavestart = 1;
		}elsif($line =~ /^end of node waveforms$/){
			$wavestart = 0;
		}elsif($wavestart && $line =~ /([^:\s]+)\s*:\s*([\w\.-]+)/){
			my $waveform = $1;
			my $prob  = $2;
			if(exists $$network_href{$nodeName}){
				$$network_href{$nodeName}{waveform}{$waveform} = $prob;
			}else{
				print "net $nodeName is ignored because it's not defined in network.\n" if($prtMsgReadWave);
			}
		}
	}
	close(FP);
}

# return a smaller network with output node related net only
# inputs are input or sg net only
# only one output
# !!! DON'T copy property 'isSg'
sub buildNetwork{
	my($networkIn_href,$outNet)=@_;
	my(%networkOut);

	copyNetworkBfs(\%networkOut,$outNet,$networkIn_href,$outNet);
	# fix output network %networkOut
	# set output net to internal is not $outNet 
	# remove isSg is not $outNet
	# if not $outNet, change isSg net type to input, remove isSg
	foreach my $net(keys %networkOut){
		if(($net ne $outNet) && ($networkOut{$net}{type} eq "output")){
			$networkOut{$net}{type} = "internal";
		}
		if(($net ne $outNet) && $networkOut{$net}{isSg}){
			$networkOut{$net}{type} = "input";
			$networkOut{$net}{isSg} = "";
		}
		if($networkOut{$net}{type} eq "input"){
			delete $networkOut{$net}{trace};
		}else{
			delete $networkOut{$net}{waveform};
		}
	}
	$networkOut{$outNet}{type} = "output";

	return(%networkOut);
}

sub copyNetworkBfs{
	my($networkOut_href,$curNet,$networkIn_href,$outNet)=@_;

	if(!$curNet or exists $$networkOut_href{$curNet}){
		return;
	}

	$$networkOut_href{$curNet} = $$networkIn_href{$curNet};

	return if($$networkIn_href{$curNet}{type} eq "input" 
		or ($$networkIn_href{$curNet}{isSg} && $curNet ne $outNet));

	if(exists $$networkIn_href{$curNet}{trace}){
		foreach my $input(split(/\s+/,$$networkIn_href{$curNet}{trace})){
			$input =~ s/(\(|\))//g;
			$input =~ s/^[^\=]\=(.*)/$1/;
			copyNetworkBfs($networkOut_href,$input,$networkIn_href,$outNet);
		}
	}else{
		print "ERROR: copyNetworkBfs can't handle net $curNet. Net $curNet trace $$networkIn_href{$curNet}{trace} is invalid.\n";
		exit(1);
	}
}

# input is $network_href and $output
# output is %sortInfo -> $sortInfo{<netName>}{finishTime}
#                     -> $sortInfo{<netName>}{multidrive}

sub topoSortNetwork{
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

sub topoSortNetworkDfs{
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
	$dfsCnt++;
}

# input is fresh $network_href
# output is annotated $network_href with isSg
sub findSgNet{
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
	foreach my $net(sort keys %sgNodes){
		$$network_href{$net}{isSg} = 1;
		$sgCnt++;
	#print "    findSgNet : net $net isSg $$network_href{$net}{isSg}\n";
	}
	#my $addSg = $sgCnt>1 ? 1 : 0;#outNode is sg
	$sgCnt-- if($sgCnt);
	
	return($sgCnt);
}

sub findSgNetDfs{
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
sub network2lcgraph{
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

# input is fresh network
# output is annotated network with isSg

# if stem level>stemlimit, set it to isSg to break
sub limitStem{
	my($network_href,$outNode,$stemlimit)=@_;
	
	#sortInfo{<net>}{finishTime},{multidrive}
	my %sortInfo = topoSortNetwork($network_href, $outNode);
	my $newSgCnt = 0;
	#assign input stem level, populate and calculate other stem
	foreach $net(sort {$sortInfo{$a}{finishTime}<=>$sortInfo{$b}{finishTime}} keys %sortInfo){
		if($$network_href{$net}{type} eq "input"){
			$sortInfo{$net}{stem} = $sortInfo{$net}{multidrive} ? 1 : 0;
		}else{
			my $trace = $$network_href{$net}{trace};
			$trace  =~ s/^\(|\)$//g;
			foreach my $input(split(/\s+/,$trace)){
				$input =~ s/^\w+\=(.*)/$1/;
				if(!exists $sortInfo{$net}{stem} or $sortInfo{$net}{stem}<$sortInfo{$input}{stem}){
					$sortInfo{$net}{stem} = $sortInfo{$input}{stem};
				}
			}
			$sortInfo{$net}{stem}++ if($sortInfo{$net}{multidrive});
			#if high stem depth found, set it to 1 and set it to isSg
			if($sortInfo{$net}{stem} > $stemlimit){
				$$network_href{$net}{isSg} = 1;
				$sortInfo{$net}{stem} = 1;
				$newSgCnt++;
			}
		}
	}

	#foreach my $net(keys %sortInfo){
	#print "    limitStem: net $net isSg $$network_href{$net}{isSg}\n";
	#	$sgCnt++ if($$network_href{$net}{isSg});
	#}
	#my $addSg = $sgCnt>1 ? 1 : 0;#outNode is sg
	#my $addSg = $newSgCnt>1 ? 1 : 0;#outNode is sg
	$newSgCnt-- if($newSgCnt);

	return($newSgCnt);
}

# input is fresh network
# output is annotated network with isSg
# if path depth>depthlimit, set it to isSg to break
sub limitDepth{
	my($network_href,$outNode,$depthlimit)=@_;
	
	my %sortInfo = topoSortNetwork($network_href,$outNode);
	my $newSgCnt = 0;
	#assign input stem level, populate and calculate other stem
	foreach $net(sort {$sortInfo{$a}{finishTime}<=>$sortInfo{$b}{finishTime}} keys %sortInfo){
		if($$network_href{$net}{type} eq "input"){
			$sortInfo{$net}{depth} = $sortInfo{$net}{multidrive} ? 1 : 0;
		}else{
			my $trace = $$network_href{$net}{trace};
			$trace  =~ s/^\(|\)$//g;
			foreach my $input(split(/\s+/,$trace)){
				$input =~ s/^\w+\=(.*)/$1/;
				if(!exists $sortInfo{$net}{depth} or $sortInfo{$net}{depth}<$sortInfo{$input}{depth}){
					$sortInfo{$net}{depth} = $sortInfo{$input}{depth};
				}
			}
			$sortInfo{$net}{depth}++;
			#if high stem depth found, set it to 1 and set it to isSg
			if($sortInfo{$net}{depth} > $depthlimit){
				$$network_href{$net}{isSg} = 1;
				$sortInfo{$net}{depth} = 1;
				$newSgCnt++;
			}
		}
	}

	#if isSg>1, return 1 else 0(out is isSg)
	#foreach my $net(keys %sortInfo){
	#print "    limitDepth : net $net isSg $$network_href{$net}{isSg}\n";
	#	$sgCnt++ if($$network_href{$net}{isSg});
	#}
	#my $addSg = $sgCnt>1 ? 1 : 0;#outNode is sg
	$newSgCnt-- if($newSgCnt);

	return($newSgCnt);
}

#sub mprint{
#	my($line,@fileHandler)=@_;
#	print $line;
#	foreach my $fp (@fileHandler){
#		print $fp $line;
#	}
#}

1;
