#!/usr/bin/perl

#connection information
# %conn
#      ->{pin}{type}   input/output/internal
#      ->{pin}{order}  order in input line
#      ->{pin}{gate}   XOR2X1...
#      ->{pin}{trace}  (A=in0 B=[125])
sub readVerilog{
	my($netlist) = @_;
	my %conn=();
	my $inOrder = 1;
	my $outOrder = 0;
	local(*INFILE);
	open(INFILE,"$netlist") or die("Can't open infile $netlist\n$!");
	while(my $line=get_a_verilog_line(INFILE)){
		next if($line =~ /^\s*(\/\/|$)/);
		if($line =~ /^\s*(input|output)([^\;]+);/){
			my $type = $1;
			my $pins = $2;
			foreach my $pin(split(/[,\s]+/,$pins)){
				$conn{$pin}{type} = $type;
				if($type =~ /input/){
					$conn{$pin}{order} = $inOrder;
					$inOrder++;
				}
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

1;
