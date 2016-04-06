#!/usr/bin/perl

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

1;
