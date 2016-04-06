#!/usr/bin/perl

# articulation points
#
#       @A = $G->articulation_points()
#
#       Returns the articulation points (vertices) @A of the graph $G.
#
sub articulation_points {
    my $G = shift;
    my $articulate =
        sub {
              my ( $u, $T ) = @_;

              my $ap = $T->{ vertex_found }->{ $u };

              my @S = @{ $T->{ active_list } }; # Current stack.

              $T->{ articulation_point }->{ $u } = $ap
                  unless exists $T->{ articulation_point }->{ $u };

              # Walk back the stack marking the active DFS branch
              # (below $u) as belonging to the articulation point $ap.
              for ( my $i = 1; $i < @S; $i++ ) {
                  my $v = $T[ -$i ];

                  last if $v eq $u;

                  $T->{ articulation_point }->{ $v } = $ap
                      if not exists $T->{ articulation_point }->{ $v } or
                         $ap < $T->{ articulation_point }->{ $v };
            }
        };

    my $unseen_successor =
        sub {
              my ($u, $v, $T) = @_;

              # We need to know the number of children for root vertices.
              $T->{ articulation_children }->{ $u }++;
        };
    my $seen_successor =
        sub {
              my ($u, $v, $T) = @_;

              # If the $v is still active, articulate it.
              $articulate->( $v, $T )
                  if exists $T->{ active_pool }->{ $v };
        };
    my $d =
        Graph::DFS->new($G,
                        articulate       => $articulate,
                        unseen_successor => $unseen_successor,
                        seen_successor   => $seen_successor,
                        );

    $d->preorder; # Traverse.

    # Now we need to find (the indices of) unique articulation points
    # and map them back to vertices.

    my (%ap, @vf);

    foreach my $v ( $G->vertices ) {
        $ap{ $d->{ articulation_point }->{ $v } } = $v;
        $vf[ $d->{ vertex_found       }->{ $v } ] = $v;
    }

    %ap = map { ( $vf[ $_ ], $_ ) } keys %ap;

    # DFS tree roots are articulation points if and only
    # if they have more than one child.
    foreach my $r ( $d->roots ) {
        delete $ap{ $r } if $d->{ articulation_children }->{ $r } < 2;
    }

    keys %ap;
}

use Graph::Undirected;

my $Alphaville = Graph::Undirected->new;

$Alphaville->add_path( qw( University Cemetery BusStation
                           OldHarbor University ) );
$Alphaville->add_path( qw( OldHarbor SouthHarbor Shipyards
                           YachtClub SouthHarbor ) );
$Alphaville->add_path( qw( BusStation CityHall Mall BusStation ) );
$Alphaville->add_path( qw( Mall Airport ) );

my @ap  = $Alphaville->articulation_points;

print "Alphaville articulation points = @ap\n";
