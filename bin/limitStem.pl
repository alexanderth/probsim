#!/usr/bin/perl

#require "src/topoSortNetwork.pl";

# input is fresh network
# output is annotated network with isSg

# if stem level>stemlimit, set it to isSg to break
sub limitStem(){
	my($network_href,$outNode,$stemlimit)=@_;
	
	my %sortInfo = topoSortNetwork($network_href,$outNode);
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
			}
		}
	}

	#if isSg>1, return 1 else 0(out is isSg)
	foreach my $net(keys %sortInfo){
		$sgCnt++ if($$network_href{$net}{isSg});
	}
	my $addSg = $sgCnt>2 ? 1 : 0;#outNode is sg

	return($addSg);
}

1;
