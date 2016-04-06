sub aps{
my %conn = readConn(<connfile>);
my %network=buildNetwork(\%conn,$outnode);
readWave($wavefile,\%network);
hierPartitionAndSim(\%network,$outnode,$stemlimit,$depthlimit,$wavelimit,$eventlimit,$glitchTh);
}

sub hierPartitionAndSim{
    $partition = findSgNet($network_href,$outNode);
    $partition = limitStem($network_href,$outNode,$stemlimit);
    $partition = limitDepth($network_href,$outNode,$depthlimit);
    if($partition){
        my %nodeInfo=topoSortNetwork($network_href,$outNode);#added mutlidrive
        foreach my $net(sort {$nodeInfo{$a}{finishTime}<=>$nodeInfo{$b}{finishTime}} keys %nodeInfo){
            if($$network_href{$net}{isSg}){
                hierPartitionAndSim(\%networkPartitioned,$net,$stemlimit,$depthlimit,$wavelimit,$eventlimit,$glitchTh);
                $$network_href{$net}{waveform} = $networkPartitioned{$net}{waveform};
            }
        }
    }
    else{
        sgProbSim($outNode,$network_href,$eventlimit,$wavelimit,$glitchTh) if($sgProbSim);
    }
}

sub sgProbSim{
    my($outNode,$network_href,$eventlimit,$wavelimit,$glitchTh)=@_;
    my %netInfo=topoSortNetwork($network_href,$outNode);
    #%netInfo: $netInfo{<net>}{finishTime},{multidrive}
    #add $netInfo{<net>}{waveform}
    #initilize %stems
    #initilize %waveformInUse
    #initilize %request
    while(my $curNet=getNextNode(\%netInfo,\%stems,\%request,\%waveformInUse)){
        #delete old waveforms of current net if not outNode
        ##keep output waveforms to $network_href
        propagate($curNet,$outNode,\%netInfo,\%waveformInUse,$network_href,$eventlimit,$glitchTh);
        #update if stem net
        #request for loads
        !!!## merge wave and write back to %network
    }
}

sub getNextNode{
    my($netInfo_href,$stems_href,$request_href,$waveformInUse_href)=@_;
    if(scalar(keys %{$request_href})){
        $nextNet = (sort {$$netInfo_href{$a}{finishTime}<=>$$netInfo_href{$b}{finishTime}} keys %{$request_href})[0];
    }else{
        for(my $stemLevel = $stems_href->{hlevel};$stemLevel>0;$stemLevel--){
            $stems_href->{$stemLevel}->{curCnt} += 1;
            if($stems_href->{$stemLevel}->{curCnt} >= $stems_href->{$stemLevel}->{cpNum}){
                updateStemWaveforms($stemLevel,$netInfo_href,$stems_href,$request_href,$waveformInUse_href);
            }else{
                updateStemWaveforms($stemLevel,$netInfo_href,$stems_href,$request_href,$waveformInUse_href);
                $nextNet = (sort {$$netInfo_href{$a}{finishTime}<=>$$netInfo_href{$b}{finishTime}} keys %{$request_href})[0];
                last;
            }
        }
    }
    delete $$request_href{$nextNet} if($nextNet);
}

sub updateStemWaveforms{
    my($stemLevel,$netInfo_href,$stems_href,$request_href,$waveformInUse_href)=@_;
    foreach my $net(split(",",$$stems_href{$stemLevel}{nets})){
        #get $newWave, $newProb
        #assign and request if different from exiting value/prob
    }
}

sub propagate{
    my($curNet,$outNode,$netInfo_href,$waveformInUse_href,$network_href,$eventlimit,$glitchTh)=@_;
    #get waveforms for inputs
    foreach cross-product{
        my %out=waveformPropagation($in1Wave,$in1Prob,$in2Wave,$in2Prob,$gate,$gateDelay,$eventlimit,$glitchTh);
    }
}

sub waveformPropagation{
    my($waveform1,$waveProb1,$waveform2,$waveProb2,$gate,$gateDelay,$eventlimit,$glitchTh)=@_;
    %out=eventPropagation($evalTime[$i],$in1Trans[$i],$in2Trans[$i],$gate,$gateDelay);
    # get time need to be evaluated
    # get in1 in2 state @ evalTime
    # calc output events
    # filter out no changes
    # filter output glitches
    # merge x events
    # keep k events
    # output
}
