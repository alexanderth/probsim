#!/usr/bin/perl

#$scrDir = "/home/xiaoliac/bin";
#require "$scrDir/readConn.pl";
#my %conn = readConn($conn);
#conn2lcgraph(\%conn);

#input is a ref to %conn
#transform a %$conn network to lc-graph
#lc-graph
#1. all inputs to output have connections
#2. all inputs of the same gate have connections
sub conn2lcgraph(){
	my ($conn) = @_;
	my %lcgraph;
	
	foreach my $net(sort keys %$conn) {
		next if($$conn{$net}{type} =~ /input/);
		my @inputs = split(/\s+/,$$conn{$net}{trace});
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
	
	#if($debug){
	#	foreach my $net(sort keys %$conn){
	#		print "\t$net";
	#	}
	#	print "\n";
	#	foreach my $curNet(sort keys %$conn){
	#	print "$curNet\t";
	#		foreach my $net(sort keys %$conn){
	#			if($lcgraph{"$curNet\=$net"}){
	#				print "Y\t";
	#			}else{
	#				print "N\t";
	#			}
	#		}
	#	print "\n";
	#	}
	#}

	return %lcgraph;
}

1;
