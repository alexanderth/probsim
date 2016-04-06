#!/usr/bin/perl

#connection information
# %conn
#      ->{pin}{type}   input/output/internal
#      ->{pin}{order}  order in input line
#      ->{pin}{gate}   XOR2X1...
#      ->{pin}{trace}  (A=in0 B=[125])
sub readConn{
	my ($connfile) = @_;
	my %conn=();
	my $inOrder = 1;
	my $outOrder = 0;
	local(*INFILE);
	open(INFILE,"$connfile") or die("Can't open infile $connfile\n$!");
	while(!eof(INFILE)){
		my $line = <INFILE>;
		next if($line =~ /^\/\/|^\s*$/);
		if($line =~ /primary (input|output)s:\s*(.*)/){
			my $type = $1;
			foreach my $pin(split(/\s+/,$2)){
				$pin =~ s/(\{|\}|\s)//g;
				$conn{$pin}{type} = $type;
				if($type =~ /input/){
					$conn{$pin}{order} = $inOrder;
					$inOrder++;
				}
			}
		}
		elsif($line =~ /^\s*(\S+)\s+(\S+)\s+\S+\s+(.*)$/){
			my $pin = $1;
			my $gate = $2;
			my $trace = $3;
			#$pin =~ s/(\{|\}|\s|_)//g;
			#$trace =~ s/_//g;
			$conn{$pin}{type}  = "internal" if(!$conn{$pin}{type});
			$conn{$pin}{gate}  = $gate;
			$conn{$pin}{trace} = $trace;
		}
		else{
			print "ERROR: can't handle line $line";
		}
	}
	close(INFILE);

	return %conn;
}

1;
