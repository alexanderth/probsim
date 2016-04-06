#!/usr/bin/perl

#connection information
# %conn
#      ->{pin}{type}   input/output/internal
#      ->{pin}{order}  order in input line
#      ->{pin}{gate}   XOR2X1...
#      ->{pin}{trace}  (A=in0 B=[125])
sub readNetlist{
	my($netlist) = @_;
	my %conn=();
	my $inOrder = 1;
	my $outOrder = 0;
	local(*INFILE);
	open(INFILE,"$netlist") or die("Can't open infile $netlist\n$!");
	while(!eof(INFILE)){
		my $line = <INFILE>;
		next if($line =~ /^\s*(\#|$)/);
		if($line =~ /^(input|output)\((\w+)\)/){
			my $type = $1;
			my $pin = $2;
			$conn{$pin}{type} = $type;
			if($type =~ /input/){
				$conn{$pin}{order} = $inOrder;
				$inOrder++;
			}
		}elsif($line =~ /^(\w+)\s+(\w+)\s*\(\.A\((\w+)\),\s*(\.B\((\w+)\),\s*)?\.Y\((\w+)\)\)\;$/){
		#1:gate 2:inst 3:netA 4:connB 5:netB 6:netY
			my $pin = $6;
			my $gate = $1;
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

1;
