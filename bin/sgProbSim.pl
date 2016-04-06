#!/usr/bin/perl

require "src/waveformPropagation.pl";
require "src/mergeWaveform.pl";
use lib '/home/xiaoliac/bin/perl/lib/';
use lib '/home/xiaoliac/bin/perl/lib/lib/perl5/site_perl/5.8.5/';                                                                                                   
use Time::HiRes;
use POSIX;

use List::Util 'shuffle';

# use event trigger to update waveforms
#initialize inputs
#    send request for loads
#get the smallest net from request queue(get)
#    process curNet
#    send request for loads
sub sgProbSim(){
	my($outNode,$network_href,$eventlimit,$wavelimit,$glitchTh,$noMergeNet)=@_;
	print "********************************\n" if($prtMsgSgProbSim);
	print "sgProbSim:outNode $outNode eventlimit $eventlimit wavelimit $wavelimit glitchTh $glitchTh\n" if($prtMsgSgProbSim);
	print "********************************\n" if($prtMsgSgProbSim);
	my $stime = Time::HiRes::time;
	my $propcnt = 0;
	$|=1;
	if($prtMsgSgProbSim){
		print "1.sgProbSim network include \n";
		print join(",",sort keys %{$network_href})."\n";
	}

	#%netInfo: $netInfo{<net>}{finishTime},{multidrive}
	my %netInfo=topoSortNetwork($network_href,$outNode);
	#add $netInfo{<net>}{stem}, stem level starts from 0 which means not stem
	#  assign input stem level, populate and calculate other stem
	#add $netInfo{<net>}{loads}, load signals of <net>
	foreach my $net(sort {$netInfo{$a}{finishTime}<=>$netInfo{$b}{finishTime}} keys %netInfo){
		if($$network_href{$net}{type} eq "input"){
			$netInfo{$net}{stem} = $netInfo{$net}{multidrive} ? 1 : 0;
		}else{
			my $trace = $$network_href{$net}{trace};
			$trace  =~ s/^\(|\)$//g;
			foreach my $input(split(/\s+/,$trace)){
				$input =~ s/^\w+\=(.*)/$1/;
				if(!exists $netInfo{$net}{stem} or $netInfo{$net}{stem}<$netInfo{$input}{stem}){
					$netInfo{$net}{stem} = $netInfo{$input}{stem};
				}
				$netInfo{$input}{loads} = $netInfo{$input}{loads} ? "$netInfo{$input}{loads},$net" : $net;
			}
			$netInfo{$net}{stem}++ if($netInfo{$net}{multidrive});
		}
	}
	foreach my $net(keys %netInfo){
		$netInfo{$net}{stem} = 0 if(!$netInfo{$net}{multidrive});
	}
	#add $netInfo{<net>}{waveform}
	foreach my $net(keys %{$network_href}){
		#if($$network_href{$net}{type} eq "input" && $netInfo{$net}{multidrive})
		if($$network_href{$net}{type} eq "input"){
			$netInfo{$net}{waveform} = $$network_href{$net}{waveform};
		}
	}
	if($prtMsgSgProbSim){
	print "2.initialize netInfo stem\n";
	foreach my $net(sort {$netInfo{$a}{finishTime}<=>$netInfo{$b}{finishTime}} keys %netInfo){
		print "    finishTime $netInfo{$net}{finishTime} net $net stem $netInfo{$net}{stem}";
		print " multidrive $netInfo{$net}{multidrive} waveformNum ".scalar(keys %{$netInfo{$net}{waveform}})."\n";
	}
	}
	if($assertion){
		foreach my $net(keys %netInfo){
			foreach my $wave(keys %{$netInfo{$net}{waveform}}){
				my $prob = $netInfo{$net}{waveform}{$wave};
				if($prob<=0 or $prob>1){
					print "sgProbSim assertion:net $net wave $wave prob $prob is invalid\n";
					exit();
				}
			}
		}
	}

	#initilize %stems
	#for all stem nodes, set update to 1, curCnt = 0, cpNum = 1, not include stem 0
	my %stems;
	$stems{hlevel} = 0;
	$stems{backtrace} = 0;
	foreach my $net(sort {$netInfo{$a}{finishTime}<=>$netInfo{$b}{finishTime}} keys %netInfo){
		my $stemLevel = $netInfo{$net}{stem};
		#initialize if $net is stem
		if($stemLevel){
			$stems{hlevel} = $stemLevel if($stemLevel>$stems{hlevel});
			$stems{$stemLevel}{curCnt} = 0; 
			$stems{$stemLevel}{cpNum}  = 1;
			$stems{$stemLevel}{nets}   .= ",$net";
			$stems{$stemLevel}{nets}   =~ s/^,//;
		}
	}
	#initilize %waveformInUse
	#update %stems if stem net
	my %waveformInUse;
	foreach my $net(sort keys %$network_href){
		#assign initial wave for stem input
		if($$network_href{$net}{type} eq "input" && $netInfo{$net}{multidrive}){
			my $waveform = (sort keys %{$netInfo{$net}{waveform}})[0];
			my $prob = $netInfo{$net}{waveform}{$waveform};
			$waveformInUse{$net}{$waveform} = $prob;
			$stems{1}{cpNum} *= scalar(keys %{$$network_href{$net}{waveform}});
		}
	}
	if($prtMsgSgProbSim){
	print "3.initilize \%stems\n";
	foreach my $level(sort keys %stems){
		if($level =~ /\d+/){
			print "stem $level, cpNum $stems{$level}{cpNum}, curCnt $stems{$level}{curCnt} nets $stems{$level}{nets}\n";
		}else{
			print "$level $stems{$level}\n";
		}
	}

	print "4:initilize \%waveformInUse\n";
	foreach my $net(sort {$netInfo{$a}{stem}<=>$netInfo{$b}{stem}} keys %waveformInUse){
		my $wave = (sort keys %{$waveformInUse{$net}})[0];
		my $prob = $waveformInUse{$net}{$wave};
		print "net $net stem $netInfo{$net}{stem} waveformInUse $wave,$prob\n";
	}
	}
	if($assertion){
		foreach my $net(keys %waveformInUse){
			if(scalar(keys %{$waveformInUse{$net}})>1){
				print "sgProbSim assertion:waveformInUse for net $net has more than one wave\n";
				exit();
			}else{
				foreach my $wave(keys %{$waveformInUse{$net}}){
					my $prob = $waveformInUse{$net}{$wave};
					if($prob<=0 or $prob>1){
						print "sgProbSim assertion:waveformInuse net $net wave $wave prob $prob is invalid\n";
						exit();
					}
				}
			}
		}
	}

	#initilize %request
	my %request;
	foreach my $net(sort keys %{$network_href}){
		if($$network_href{$net}{type} eq "input"){
			foreach my $load(split(",",$netInfo{$net}{loads})){
				$request{$load} = 1;
			}
		}
	}
	if($prtMsgSgProbSim){
	print "5: initialize \%requests\n";
	foreach my $net(sort {$netInfo{$a}{finishTime}<=>$netInfo{$b}{finishTime}} keys %request){
		print "$netInfo{$net}{finishTime} $net\n";
	}
	}

	#if($prtMsgSgProbSim){
	print "sgProbSim: $outNode";
	print " nets num = ".scalar(keys %netInfo);
	print " stem hlevel = ".$stems{hlevel};
	my $etime = Time::HiRes::time;
	print " elapsed ".($etime-$stime)."\n";
	#}
	while(my $curNet=getNextNode(\%netInfo,\%stems,\%request,\%waveformInUse)){
		#end loop if can't get $curNet
		last if(!$curNet);

		#delete old waveforms of current net if not outNode
		if($curNet ne $outNode){
			if($netInfo{$curNet}{stem}){
				my $curWaveCnt = scalar(keys %{$netInfo{$curNet}{waveform}});
				$stems{$netInfo{$curNet}{stem}}{cpNum} /= $curWaveCnt if($curWaveCnt);
				foreach my $wave(sort keys %{$waveformInUse{$curNet}}){
			print "delete InUse wave $wave:$waveformInUse{$curNet}{$wave}\n" if($prtMsgSgProbSim);
					delete $waveformInUse{$curNet}{$wave};
				}
			}
			foreach my $wave(sort keys %{$netInfo{$curNet}{waveform}}){
			print "delete netInfo wave $wave:$netInfo{$curNet}{waveform}{$wave}\n" if($prtMsgSgProbSim);
				delete $netInfo{$curNet}{waveform}{$wave};
			}
		}

		##keep output waveforms to $network_href
		print "propagate $curNet\n" if($prtMsgSgProbSim);
		$propcnt++;
		propagate($curNet,$outNode,\%netInfo,\%waveformInUse,$network_href,$wavelimit,$eventlimit,$glitchTh);

		#update if stem net
		if($netInfo{$curNet}{multidrive}){
			my $wave = (sort keys %{$netInfo{$curNet}{waveform}})[0];
			my $prob = $netInfo{$curNet}{waveform}{$wave};
			$waveformInUse{$curNet}{$wave} = $prob;
			$stems{$netInfo{$curNet}{stem}}{cpNum} *= scalar(keys %{$netInfo{$curNet}{waveform}});
			if($prtMsgSgProbSim){
				print "    stem:$curNet updates stemLevel $stems{curStemLevel} cpNum by x ".scalar(keys %{$netInfo{$curNet}{waveform}}).",";
				print "from $oriCpNum to $stems{$netInfo{$curNet}{stem}}{cpNum}\n";
			}
		}

		#request for loads
		#my $newWave = $netInfo{$curNet}{waveform};
		#if($newWave ne $prevWave){
			foreach my $load(split(",",$netInfo{$curNet}{loads})){
			print "request load $load\n" if($prtMsgSgProbSim);
				$request{$load} = 1;
			}
		#}

		if($curNet eq $outNode){
			print "-N-\n" if($prtMsgSgProbSim);
		}
		print "\n"  if($prtMsgSgProbSim);
	}

	#if($prtMsgSgProbSim){
	$etime = Time::HiRes::time;
	print " propgate = ".$propcnt;
	print " elapsed ".($etime-$stime)."\n";
	#}
	# merge wave and write back to %network
	# %group, $group{<token>}{waveform}, $group{<token>}{ntoken}{<ntoken>}, $group{<token>}{diversity}
	if($assertion){
		foreach my $wave(sort keys %{$netInfo{$outNode}{waveform}}){
			if(!$wave){
				print "sgProbSim:outNode $outNode wave $wave is invalid. empty\n";
				exit();
			}else{
				my $prob = $netInfo{$outNode}{waveform}{$wave};
				if($prob<=0 or $prob>1){
				print "sgProbSim:outNode $outNode wave $wave prob $prob is invalid.\n";
				exit();
				}
			}
		}
	}
	if(scalar(keys %{$netInfo{$outNode}{waveform}})>$wavelimit && $outNode ne $noMergeNet){
		#my @waveforms=keys %{$netInfo{$outNode}{waveform}};
		#for(my $i=0;$i<scalar(@waveforms);$i++){
		#	if(!$waveforms[$i]){
		#		delete $waveforms[$i];
		#	}
		#}
		#my @randWaveforms = shuffle(@waveforms);
		#for(my $i=0;$i<$wavelimit;$i++){
		#	print "randwave $i $randWaveforms[$i]\n" if($prtMsgSgProbSim);
		#	if(!$randWaveforms[$i] or !$netInfo{$outNode}{waveform}{$randWaveforms[$i]}){
		#		print "error\n";
		#		exit();
		#	}
		#}
		#my $probSum=0;
		#for(my $i=0;$i<$wavelimit;$i++){
		#	$probSum += $netInfo{$outNode}{waveform}{$randWaveforms[$i]};
		#	print "probSum $probSum. increased by $randWaveforms[$i],$netInfo{$outNode}{waveform}{$randWaveforms[$i]}\n" if($prtMsgSgProbSim);
		#}
		#for(my $i=0;$i<$wavelimit;$i++){
		#	$$network_href{$outNode}{waveform}{$randWaveforms[$i]} = $netInfo{$outNode}{waveform}{$randWaveforms[$i]}/$probSum;
		#}

		#calculate new wavelimit (finishTime/timeScale)^2
		my %group;
		my $maxTime=0;
		#initial clustering
		foreach my $waveform(reverse sort keys %{$netInfo{$outNode}{waveform}}){
			my($times,$events)=split(",",$waveform);
			my @times=split("/",$times);
			my @events=split("/",$events);
			$maxTime = $times[-1] if($times[-1]>$maxTime);
		}
		my $time1 = $maxTime * 0.9;
		my $time2 = $maxTime * 0.7;
		my $time3 = $maxTime * 0.4;

		foreach my $waveform(reverse sort keys %{$netInfo{$outNode}{waveform}}){
			my($times,$events)=split(",",$waveform);
			my @times=split("/",$times);
			my @events=split("/",$events);
			#my $token = (split("",$events[-1]))[1]."_".(split("",$events[0]))[0];
			#$token .= "_".$times[-1]."_".$times[0];
			my $etime = $times[-1];
			my $stime = $times[0];
			my $etime = ($etime>$time1) ? ceil($etime/2)*2 :
				    ($etime>$time2) ? ceil($etime/8)*8 :
				    ceil($etime/16)*16;
				    #($etime>$time2) ? ceil($etime/16)*16 : ceil($etime/8)*8;
			my $stime = ($stime>$time1) ? ceil($stime/2)*2 :
				    ($stime>$time2) ? ceil($stime/8)*8 :
				    ceil($stime/16)*16;
				    #($stime>$time2) ? ceil($stime/6)*6 : ceil($stime/8)*8;
			my $token = (split("",$events[-1]))[1]."_".(split("",$events[0]))[0]."_".$etime."_".$stime;
			#worst-case based sampling
			if(scalar(@times)==1){
				$group{$token}{waveform} = $waveform;
			}
			elsif($times[-2]>$group{$token}{maxTime}){
				$group{$token}{maxTime} = $times[-2];
				$group{$token}{waveform} = $waveform;
			}
			$group{$token}{prob} += $netInfo{$outNode}{waveform}{$waveform};
		}
		foreach my $token(keys %group){
			my $wave = $group{$token}{waveform};
			my $prob = $group{$token}{prob};
			$$network_href{$outNode}{waveform}{$wave} = $prob;
			print "w:$wave p: $prob\n" if($prtMsgSgProbSim);
		}
	print "----merge waveform for net $outNode from ".scalar(keys %{$netInfo{$outNode}{waveform}})." to ".scalar(keys %group)." assigned to network_href ".scalar(keys %{$$network_href{$outNode}{waveform}})."\n";
	}else{
	       $$network_href{$outNode}{waveform} = $netInfo{$outNode}{waveform};
	print "----no merge waveform for net $outNode , keep ".scalar(keys %{$netInfo{$outNode}{waveform}}).", assigned to network_href ".scalar(keys %{$$network_href{$outNode}{waveform}})."\n";
	}

	if($assertion){
		if(scalar(keys %{$network_href->{$outNode}->{waveform}}) <1){
			print "waveform propagation is invalid. 0 waves\n";
			exit();
		}
		foreach my $waveform(sort keys %{$network_href->{$outNode}->{waveform}}){
			if(!$waveform){
				print "sgProbSim: outnode $outNode wave $waveform is invalid. empty wave\n";
				exit();
			}
			my $waveProb = $network_href->{$outNode}->{waveform}->{$waveform};
			#print "$waveform:$waveProb\n" if($prtMsgSgProbSim);
			$waveProb = 1 if($waveProb>1 && $waveProb<1.000001);
			if($waveProb>1){
				print "ERROR: net $outNode waveform $waveform prop $waveProb is invalid, >1\n";
				exit(1);
			}elsif($waveProb <= 0){
				print "ERROR: net $outNode waveform $waveform prop $waveProb is invalid, <=0\n";
				exit(1);
			}
		}
	}
	print "finish $outNode with ".scalar(keys %{$network_href->{$outNode}->{waveform}})." waveforms\n\n" if($prtMsgSgProbSim);
}

#get the smallest net from request queue(get)
sub getNextNode(){
print "----getNextNode\n"  if($prtMsgSgProbSim);
	my($netInfo_href,$stems_href,$request_href,$waveformInUse_href)=@_;
	my $nextNet;
	if(scalar(keys %{$request_href})){
		$nextNet = (sort {$$netInfo_href{$a}{finishTime}<=>$$netInfo_href{$b}{finishTime}} keys %{$request_href})[0];
	}else{
		print "    get new cp\n" if($prtMsgSgProbSim);
		for(my $stemLevel = $stems_href->{hlevel};$stemLevel>0;$stemLevel--){
			$stems_href->{$stemLevel}->{curCnt} += 1;
			$stems_href->{backtrace} = $stemLevel;
			print "    getNextNode: check stemLevel $stemLevel; curCnt $stems_href->{$stemLevel}->{curCnt}, cp $stems_href->{$stemLevel}->{cpNum}\n" if($prtMsgSgProbSim);
			if($stems_href->{$stemLevel}->{curCnt} >= $stems_href->{$stemLevel}->{cpNum}){
				#reset current stem level if it has been fully visited
				print "    current stemLevel $stemLevel is full, reset and go back\n" if($prtMsgSgProbSim);
				#$stems_href->{$stemLevel}->{cpNum}	= 1;
				$stems_href->{$stemLevel}->{curCnt}	= 0;
				#foreach my $net(split(",",$stems_href->{$stemLevel->{nets}})){
				#	if($net ne $outNode){
				#		foreach my $wave(sort keys %{$$netInfo_href{$net}{waveform}}){
				#			delete $$netInfo_href{$net}{waveform}{$wave} if();
				#		}
				#		foreach my $wave(sort keys %{$$waveformInUse_href{$net}}){
				#			delete $$waveformInUse_href{$net}{$wave};
				#		}
				#	}
				#}
				updateStemWaveforms($stemLevel,$netInfo_href,$stems_href,$request_href,$waveformInUse_href);
				#foreach my $net(split(",",$$stems_href{$stemLevel}{nets})){
				#	foreach my $load(split(",",$$netInfo_href{$net}{loads})){
				#		$$request_href{$load} = 1;
				#	}
				#}
				next;
			}else{
				#re-assign stem value, request loads if value changed
				updateStemWaveforms($stemLevel,$netInfo_href,$stems_href,$request_href,$waveformInUse_href);
				#$nextNet=getNextNode($netInfo_href,$stems_href,$request_href);
				$nextNet = (sort {$$netInfo_href{$a}{finishTime}<=>$$netInfo_href{$b}{finishTime}} keys %{$request_href})[0];
				last;
			}
		}
	}
	delete $$request_href{$nextNet} if($nextNet);
	print "    get net $nextNet\n" if($prtMsgSgProbSim);
	return $nextNet;
}

#update %waveformInUse based on $stems_href->{$stemLevel}->{curCnt}
#request for loads if waveform change
sub updateStemWaveforms{
	my($stemLevel,$netInfo_href,$stems_href,$request_href,$waveformInUse_href)=@_;
print "updateStemWave:" if($prtMsgSgProbSim);
	my($quotient,$remainder,$waveNum);
	$quotient = $$stems_href{$stemLevel}{curCnt};
	foreach my $net(split(",",$$stems_href{$stemLevel}{nets})){
		my $waveNum  = scalar(keys %{$$netInfo_href{$net}{waveform}});
		last if(!$waveNum);
		$remainder = $quotient%$waveNum;
		$quotient  = $quotient/$waveNum;
		#get $newWave, $newProb
		my $newWave   = (sort keys %{$$netInfo_href{$net}{waveform}})[$remainder];
		my $newProb  = $$netInfo_href{$net}{waveform}{$newWave};
		my $prevWave=(sort keys %{$$waveformInUse_href{$net}})[0];
		my $prevProb = $$waveformInUse_href{$net}{$prevWave};
		#assign and request if different from exiting value/prob
		if($newWave ne $prevWave or $newProb != $prevProb){
			delete $$waveformInUse_href{$net}{$prevWave};
			$$waveformInUse_href{$net}{$newWave}=$newProb;
			print "\ndelete $net prevWave $prevWave,$prevProb add newWave $newWave,$newProb" if($prtMsgSgProbSim);
			foreach my $load(split(",",$$netInfo_href{$net}{loads})){
				$$request_href{$load} = 1;
			}
		}
	}
print "\n" if($prtMsgSgProbSim);
}

#input: $curNet, $
#output: $conn_ref->{$curNode}->{events}->{r/f,t}=p
#algorithm
#get all inputs based on $conn_ref
#if input is input/sg(not curSg), get events
#if input is stem, 
#	if(first time)
#		push to $stems->{stem}
#	else
#		get 1 value based on $stems->{stem}->{curCnt}

# find all inputs
# get all waveforms for inputs
#     waveformPropagation() for each combination
#     prob scaling if outNet

sub propagate{
	my($curNet,$outNode,$netInfo_href,$waveformInUse_href,$network_href,$wavelimit,$eventlimit,$glitchTh)=@_;
	print ".";
	print "----propagate $curNet (outNode is $outNode)\n" if($prtMsgSgProbSim>2);

	#never propagate input
	if($assertion){
		if($netInfo_href->{$curNet}->{type} eq "input"){
			print "net $curNet is input. invalid\n";
			exit();
		}
	}
	#delete previous events first unless sgNode
	delete $netInfo_href->{$curNet}->{waveform} if($curNet ne $outNode);
	#get all waveforms for all inputs
	my @inputs = split(/\s+/,$network_href->{$curNet}->{trace});
	my $gate = $network_href->{$curNet}->{gate};
	my $gateDelay = 1;
	$gate =~ s/2?X1//;
	foreach my $input(@inputs){
		$input =~ s/(\(|\))//g;
		$input =~ s/^[^\=]\=(.*)/$1/;
	}

	my(%inputWaveforms);
	my $probCnt = 1;
	foreach my $input(@inputs){
		if($netInfo_href->{$input}->{multidrive}){
print "input $input stem $netInfo_href->{$input}->{multidrive}\n";
			print "    (stem) assign $input waveform ".scalar(keys %{$waveformInUse_href->{$input}})." values inUse" if($prtMsgSgProbSim);
			$inputWaveforms{$input} = $waveformInUse_href->{$input};
		}else{
			print "    (not stem) assign $input waveform ".scalar(keys %{$netInfo_href->{$input}->{waveform}})." values netInfo" if($prtMsgSgProbSim);
			$inputWaveforms{$input} = $netInfo_href->{$input}->{waveform};
		}
		print ", include ".join(";",sort keys %{$inputWaveforms{$input}})."\n" if($prtMsgSgProbSim);
		$probCnt *= scalar(keys %{$inputWaveforms{$input}});
	}
	if($assertion){
		if($probCnt<=0){
			print "probCnt $probCnt <= 0.invalid\n";
			exit();
		}
	}
	#get cross-product and call waveformPropagation() one by one
	my @in1Waves = sort keys %{$inputWaveforms{$inputs[0]}};
	my @in2Waves = sort keys %{$inputWaveforms{$inputs[1]}};
	if($assertion){
			if(!scalar(@in1Waves)){
				print "ERROR:in1Waves is empty.\n";
				exit(1);
			}
			foreach my $wave(@in1Waves){
				my $prob = $inputWaveforms{$inputs[0]}{$wave};
				if($prob>1 || $prob<=0){
					print "in1wave $wave:$prob is invalide\n";
					exit();
				}
			}
		if($gate !~ /INV|BUF/){
			if(!scalar(@in2Waves)){
				print "ERROR:in2Waves is empty.\n";
				exit(1);
			}
			foreach my $wave(@in2Waves){
				my $prob = $inputWaveforms{$inputs[1]}{$wave};
				if($prob>1 || $prob<=0){
					print "in2wave $wave:$prob is invalide gate is $gate\n";
					exit();
				}
			}
		}
	}
	my $in1WaveCnt = scalar(@in1Waves);
	my $in2WaveCnt = scalar(@in2Waves);
	my $cpCntOri = $in1WaveCnt * $in2WaveCnt;
	print "propagate $curNet, in1 $inputs[0] = $in1WaveCnt, in2 $inputs[1] = $in2WaveCnt, in1 x in2 = $cpCntOri\n" if($prtMsgSgProbSim);
	####non-stem input clustering
	if($in1WaveCnt>$wavelimit){
		if($assertion){
			if($netInfo_href->{$inputs[0]}->{multidrive}){
				print "net $inputs[0] is stem $netInfo_href->{$inputs[0]}->{multidrive} but be assigned more than 1 waveform. invalid\n";
				exit();
			}
		}
		my %mergedWaveform; 
		mergeWaveform(\%{$inputWaveforms{$inputs[0]}},\%mergedWaveform);
		delete $inputWaveforms{$inputs[0]};
		if(scalar(keys %mergedWaveform)<1) {
			print "in1 mergeWaveform failed. return <1 wave\n";
		}
		@in1Waves = sort keys %mergedWaveform;
		foreach my $wave(@in1Waves){
			$inputWaveforms{$inputs[0]}{$wave} = $mergedWaveform{$wave};
			if($assertion){
				if($inputWaveforms{$inputs[0]}{$wave}<=0 or $inputWaveforms{$inputs[0]}{$wave}>1.000001){
					print "merged wave $wave prob $mergedWaveform{$wave} is invalid\n";
					exit();
				}
			}
		}
		print "merge in1 from $in1WaveCnt to ".scalar(@in1Waves)."\n";
	}
	if($in2WaveCnt>$wavelimit){
		if($assertion){
			if($netInfo_href->{$inputs[1]}->{multidrive}){
				print "net $inputs[1] is stem $netInfo_href->{$inputs[1]}->{multidrive} but be assigned more than 1 waveform. invalid\n";
				exit();
			}
		}
		my %mergedWaveform; 
		mergeWaveform(\%{$inputWaveforms{$inputs[1]}},\%mergedWaveform);
		delete $inputWaveforms{$inputs[1]};
		if(scalar(keys %mergedWaveform)<1) {
			print "in2 mergeWaveform failed. return <1 wave\n";
		}
		@in2Waves = sort keys %mergedWaveform;
		foreach my $wave(@in2Waves){
			$inputWaveforms{$inputs[1]}{$wave} = $mergedWaveform{$wave};
			if($assertion){
				if($inputWaveforms{$inputs[1]}{$wave}<=0 or $inputWaveforms{$inputs[1]}{$wave}>1.000001){
					print "merged wave $wave prob $mergedWaveform{$wave} is invalid\n";
					exit();
				}
			}
		}
		print "merge in2 from $in2WaveCnt to ".scalar(@in2Waves)."\n";
	}
	####
	my $waveformPropagationCnt=0;
	push(@in2Waves,"") if(!scalar(@in2Waves));
	foreach my $in1Wave(@in1Waves){
		($in1Time,$in1Trans)	= split(",",$in1Wave);
		$in1Prob		= $netInfo_href->{$inputs[0]}->{multidrive} ? 1 : $inputWaveforms{$inputs[0]}{$in1Wave};
		##skip if prob too small
		#next if($in1Prob<1e-12);
		foreach my $in2Wave(@in2Waves){
			($in2Time,$in2Trans)	= split(",",$in2Wave);
			$in2Prob		= $netInfo_href->{$inputs[1]}->{multidrive} ? 1 : $inputWaveforms{$inputs[1]}{$in2Wave};
			##skip if prob too small
			#next if($in2Prob<1e-12);

			#call waveformPropagation() propagate prob through a gate
			print "    calc: gate $gate, in1 Time/trans/prob, $in1Time/$in1Trans/$in1Prob, in2 Time/trans/prob, $in2Time/$in2Trans/$in2Prob\n" if($prtMsgSgProbSim);
			#my($waveform1,$waveProb1,$waveform2,$waveProb2,$gate,$gateDelay,$eventlimit,$glitchth)=@_;

$waveformPropagationCnt++;
			my %out=waveformPropagation($in1Wave,$in1Prob,$in2Wave,$in2Prob,$gate,$gateDelay,$eventlimit,$glitchTh);
			my $outTime	= $out{time};
			my $outTrans	= $out{trans};
			my $outProb	= $out{prob};
			print " outTime $outTime outTrans $outTrans outProb $outProb\n" if($prtMsgSgProbSim);
			#prob scaling if $outNode
			if($curNet eq $outNode){
				my $stemProbScale = 1;
				foreach my $net(sort keys %$waveformInUse_href){
					if($net ne $outNet){
						my $curStemWave = (sort keys %{$waveformInUse_href->{$net}})[0];
						my $curStemProb = $$waveformInUse_href{$net}{$curStemWave};
						$stemProbScale *= $curStemProb;
						print "    scaling: stem node $net, wave $curStemWave, prob $curStemProb, curStemProbScale $stemProbScale\n" if($verbose>2);
					}
				}
				$outProb *= $stemProbScale;
			}
			print "scaled prob $outProb\n" if($prtMsgSgProbSim);
			if($outProb<=0){
				print "outprob $outProb is invalid. <0\n";
				exit();
			}

			#update $$netInfo_href{$curNet}{waveform}
			if(exists $netInfo_href->{$curNet}->{waveform}->{"$outTime,$outTrans"}){
				$netInfo_href->{$curNet}->{waveform}->{"$outTime,$outTrans"} += $outProb;
			}else{
				$netInfo_href->{$curNet}->{waveform}->{"$outTime,$outTrans"} = $outProb;
			}

			#accuracy error
			#if($netInfo_href->{$curNet}->{waveform}->{"$outTime,$outTrans"}>1 && $netInfo_href->{$curNet}->{waveform}->{"$outTime,$outTrans"}<(1+1e-6))
			if($netInfo_href->{$curNet}->{waveform}->{"$outTime,$outTrans"}>1){
				my $prob = $netInfo_href->{$curNet}->{waveform}->{"$outTime,$outTrans"};
				print "accuracy error correct: net $curNet waveform $outTime,$outTrans, prob $prob to 1\n";
				$netInfo_href->{$curNet}->{waveform}->{"$outTime,$outTrans"} = 1;
			}
			print "  --out time/trans/prob $outTime/$outTrans/$outProb, sum ".$netInfo_href->{$curNet}->{waveform}->{"$outTime,$outTrans"}."\n" if($prtMsgSgProbSim);
		}
	}
print "waveformPropagationCnt is $waveformPropagationCnt\n" if($prtMsgSgProbSim);
print "waveformPropagationCnt is $waveformPropagationCnt\n" if($assertion);
	if($assertion){
		if(scalar(keys %{$netInfo_href->{$curNet}->{waveform}})<1){
			print "net $curNet waveform is invalid.<1\n";
		}else{
			print "----node $curNet has ".scalar(keys %{$netInfo_href->{$curNet}->{waveform}})." waveforms\n";
			if($prtMsgSgProbSim){
			foreach my $waveform (sort keys %{$netInfo_href->{$curNet}->{waveform}}){
				print "    ".$waveform;
				print "    ".$netInfo_href->{$curNet}->{waveform}->{$waveform}."\n";
			}
			}
		}
	}
}

1;
