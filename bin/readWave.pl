#!/usr/bin/perl

sub readWave(){
	my($wavefile,$network_href)=@_;

	my $nodeName = "";
	my $wavestart = 0;
	local(*FP);
	open(FP,"$wavefile") or die("Can't open file $wavefile\n$!");
	while(my $line=<FP>){
		if($line =~ /^node\s+:\s+([^\s]+)/){
			$nodeName = $1;
			$wavestart = 1;
		}elsif($line =~ /^end of node events$/){
			$nodeName = "";
			$wavestart = 0;
		}elsif($wavestart && $line =~ /([^:\s]+)\s*:\s*([\w\.-]+)/){
			my $events = $1;
			my $prob  = $2;
			$$network_href{$nodeName}{waveform}{$events} = $prob;
		}
	}
	close(FP);
}

1;
