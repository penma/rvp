package FastaGraphOLD;

use strict;
use warnings;

use constant {
	EDGE_FROM => 0, EDGE_TO => 1, EDGE_WEIGHT => 2,
	VERT_NAME => 0, VERT_EDGES_OUT => 1, VERT_EDGES_IN => 2,
};

use List::PriorityQueue;

sub new {
	my ($class) = @_;
	return bless({
		vertices => {},
		edges => [],
	}, $class);
}

sub countedges {
	my ($self) = @_;
	return scalar(@{$self->{edges}});
}

sub countvertices {
	my ($self) = @_;
	return scalar(keys(%{$self->{vertices}}));
}

sub addvertex {
	my ($self, $name) = @_;

	if (!exists($self->{vertices}->{$name})) {
		$self->{vertices}->{$name} = [ $name, [], [] ];
	}
	return $self->{vertices}->{$name};
}

sub dijkstra {
	my ($self, $from, $to) = @_;

	return undef if (!exists($self->{vertices}->{$to}));

	my $vert = $self->{vertices};
	my %dist;                       # distance from start node
	# nodes that have never been touched (where dist == infinity,
	# NOT nodes that just are not optimal yet.)
	my @unvisited = grep { $_ ne $from } keys(%{$vert});
	my $suboptimal = new List::PriorityQueue;
	$suboptimal->insert($from, 0);

	$dist{$_} = -1 foreach (@unvisited);
	$dist{$from} = 0;

	while (1) {
		# find the smallest unvisited node
		my $current = $suboptimal->pop();
		if (!defined($current)) {
			$current = pop(@unvisited);
		}
		last if (!defined($current));

		# update all neighbors
		foreach my $edge (@{$vert->{$current}->[VERT_EDGES_OUT]}) {
			if (($dist{$edge->[EDGE_TO]} == -1) ||
			($dist{$edge->[EDGE_TO]} > ($dist{$current} + $edge->[EDGE_WEIGHT]) )) {
				$suboptimal->update(
					$edge->[EDGE_TO],
					$dist{$edge->[EDGE_TO]} = $dist{$current} + $edge->[EDGE_WEIGHT]
				);
			}
		}
	}

	# trace the path from the destination to the start
	my @path = ();
	my $current = $to;
	NODE: while ($current ne $from) {
		unshift(@path, $current);
		foreach my $edge (@{$vert->{$current}->[VERT_EDGES_IN]}) {
			if ($dist{$current} == $dist{$edge->[EDGE_FROM]} + $edge->[EDGE_WEIGHT]) {
				$current = $edge->[EDGE_FROM];
				next NODE;
			}
		}
		# getting here means we found no predecessor - there is none.
		# so there's no path.
		return undef;
	}
	unshift(@path, $from);

	return @path;
}

sub addedge {
	# my ($self, $from, $to, $weight) = @_;
	deledge(@_[0..2]);
	my $v = $_[0]->{vertices};
	my $v_from = $v->{$_[1]} // $_[0]->addvertex($_[1]);
	my $v_to   = $v->{$_[2]} // $_[0]->addvertex($_[2]);

	my $edge = [ $_[1], $_[2], $_[3] ];

	push(@{$_[0]->{edges}}, $edge);
	push(@{$v_from->[VERT_EDGES_OUT]}, $edge);
	push(@{$v_to->[VERT_EDGES_IN]}, $edge);
}

sub deledge {
	# my ($self, $from, $to) = @_;
	my $v = $_[0]->{vertices};
	my $v_from = $v->{$_[1]};
	my $v_to   = $v->{$_[2]};

	# find the edge. assume it only exists once -> only delete the first.
	# while we're at it, delete the edge from the source vertex...
	my $e;
	my $c = 0;
	foreach (@{$v_from->[VERT_EDGES_OUT]}) {
		if ($_->[EDGE_TO] eq $_[2]) {
			$e = $_;
			splice(@{$v_from->[VERT_EDGES_OUT]}, $c, 1);
			last;
		}
		$c++;
	}
	return undef if (!defined($e));

	# now search it in the destination vertex' list, delete it there
	# also only delete the first matching one here (though now there
	# shouldn't be any duplicates at all because now we're matching the
	# actual edge, not just its endpoints like above.
	$c = 0;
	foreach (@{$v_to->[VERT_EDGES_IN]}) {
		if ($_ == $e) {
			splice(@{$v_to->[VERT_EDGES_IN]}, $c, 1);
			last;
		}
		$c++;
	}

	# and remove it from the graph's vertex list
	$c = 0;
	foreach (@{$_[0]->{edges}}) {
		if ($_ == $e) {
			splice(@{$_[0]->{edges}}, $c, 1);
			last;
		}
		$c++;
	}
}

1;

