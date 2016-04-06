#!/usr/bin/perl

@trans1=qw(1 2 3 4 5);
@time1=qw(1 2 3 4 5);
$prob = 1;
@trans2=qw(t1 t2 t3 t4 t5);
@time2=qw(01 02 03 04 05);
$prob = 0;
my %event1 = {
	time => @time1,
	trans => @trans1,
	prob => 1
};
my %event2 = {
	time => @time2,
	trans => @trans2,
	prob => 0
};
#$array{a}{event}[0]{time} = @time;
#$array{a}{event}[0]{trans} = @trans;
#$array{a}{event}[0]{prob} = 1;
$array{a}{event}[0] = %event1;
push(@{$array{a}{event}},%event2);
print "a event scalar:".scalar(@{$array{a}{event}})."\n";
#for(my $i=1;$i<scalar(@array);$i++){
#print "enter  loop\n";
#	splice(@array,$i-1,4);
#	print "i:$i,array size:".scalar(@array)."\n";
#}
