#!/usr/bin/perl

# return a smaller network with output node related net only
# inputs are input or sg net only
# only one output
sub buildNetwork(){
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
	}
	$networkOut{$outNet}{type} = "output";

	return(%networkOut);
}

sub copyNetworkBfs(){
	my($networkOut_href,$curNet,$networkIn_href,$outNet)=@_;

	if(!$curNet or defined $$networkOut_href{$curNet}){
		#$$networkOut_href{$curNet}{multidrive} = 1;
		return;
	}

	$$networkOut_href{$curNet} = $$networkIn_href{$curNet};

	return if($$networkIn_href{$curNet}{type} eq "input" 
		or ($$networkIn_href{$curNet}{isSg} && $curNet ne $outNet));

	if(defined $$networkIn_href{$curNet}{trace}){
		foreach my $drive(split(/\s+/,$$networkIn_href{$curNet}{trace})){
			$drive =~ s/(\(|\))//g;
			$drive =~ s/^[^\=]\=(.*)/$1/;
			copyNetworkBfs($networkOut_href,$drive,$networkIn_href,$outNet);
		}
	}else{
		print "ERROR: copyNetworkBfs can't handle net $curNet. Net $curNet trace $$networkIn_href{$curNet}{trace} is invalid.\n";
		exit(1);
	}
}

1;
