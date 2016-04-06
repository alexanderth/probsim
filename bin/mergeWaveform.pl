#!/usr/bin/perl


#given a waveform hash, return a reduced waveform hash

sub mergeWaveform{
	my($waveform_href,$mergedWaveform_href)=@_;

	if($assertion){
		if(scalar(keys %{$waveform_href})<1){
			print "input waveform hash ref is invalid. <1\n";
			exit();
		}
	}
	my %group;
	my $maxTime=0;
	#initial clustering
	foreach my $waveform(reverse sort keys %{$waveform_href}){
		my($times,$events)=split(",",$waveform);
		my @times=split("/",$times);
		my @events=split("/",$events);
		$maxTime = $times[-1] if($times[-1]>$maxTime);
	}
	my $time1 = $maxTime * 0.9;
	my $time2 = $maxTime * 0.7;
	my $time3 = $maxTime * 0.4;
	
	foreach my $waveform(reverse sort keys %{$waveform_href}){
		my($times,$events)=split(",",$waveform);
		my @times=split("/",$times);
		my @events=split("/",$events);
		#my $token = (split("",$events[-1]))[1]."_".(split("",$events[0]))[0];
		#$token .= "_".$times[-1]."_".$times[0];
		my $etime = $times[-1];
		my $stime = $times[0];
		my $etime = ($etime>$time1) ? ceil($etime/2)*2 :
			    ($etime>$time2) ? ceil($etime/4)*4 :
			    ceil($etime/8)*8;
			    #($etime>$time2) ? ceil($etime/16)*16 : ceil($etime/8)*8;
		my $stime = ($stime>$time1) ? ceil($stime/2)*2 :
			    ($stime>$time2) ? ceil($stime/4)*4 :
			    ceil($stime/8)*8;
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
		$group{$token}{prob} += $waveform_href->{$waveform};
	}

	foreach my $token(keys %group){
		next if(!$token);
		my $waveform = $group{$token}{waveform};
		my $prob = $group{$token}{prob};
		if($prob>1){
			if($prob<1.0000001){
				$prob=1;
			}else{
				print "token $token wave $waveform prob $prob is invalid.>1\n";
				exit();
			}
		}
		$mergedWaveform_href->{$waveform} = $prob;
	}
	if($assertion){
		if(scalar(keys %{$mergedWaveform_href})<1){
			print "merged waveform is invalid.<1\n";
			exit();
		}
	}

}

1;
