package FastaGraph;

use strict;
use warnings;
use 5.010;

use Data::Dumper;
use Storable qw(dclone);
use List::Util qw(min);

use constant {
	EDGE_FROM => 0, EDGE_TO => 1, EDGE_WEIGHT => 2,
	VERT_NAME => 0, VERT_EDGES_OUT => 1, VERT_EDGES_IN => 2,
};

use HashPQ;

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

sub dijkstra_worker {
	my ($self, $from, $to) = @_;

	my $vert = $self->{vertices};
	my $suboptimal = new HashPQ;
	$suboptimal->insert($_, $self->{d_suboptimal}->{$_}) foreach (keys(%{$self->{d_suboptimal}}));
	$self->{d_dist}->{$_} = -1 foreach (@{$self->{d_unvisited}});
	$self->{d_dist}->{$from} = 0;

	while (1) {
		# find the smallest unvisited node
		my $current = $suboptimal->pop() // last;

		# update all neighbors
		foreach my $edge (@{$vert->{$current}->[VERT_EDGES_OUT]}) {
			if (($self->{d_dist}->{$edge->[EDGE_TO]} == -1) ||
			($self->{d_dist}->{$edge->[EDGE_TO]} > ($self->{d_dist}->{$current} + $edge->[EDGE_WEIGHT]) )) {
				$suboptimal->update(
					$edge->[EDGE_TO],
					$self->{d_dist}->{$edge->[EDGE_TO]} = $self->{d_dist}->{$current} + $edge->[EDGE_WEIGHT]
				);
			}
		}
	}

	# trace the path from the destination to the start
	my @path = ();
	my $current = $to;
	NODE: while ($current ne $from) {
		foreach my $edge (@{$vert->{$current}->[VERT_EDGES_IN]}) {
			if ($self->{d_dist}->{$current} == $self->{d_dist}->{$edge->[EDGE_FROM]} + $edge->[EDGE_WEIGHT]) {
				$current = $edge->[EDGE_FROM];
				unshift(@path, $edge);
				next NODE;
			}
		}
		# getting here means we found no predecessor - there is none.
		# so there's no path.
		return undef;
	}

	return @path;
}

sub dijkstra_first {
	my ($self, $from, $to) = @_;
	$self->{d_from} = $from;
	$self->{d_dist} = {};
	$self->{d_unvisited}  = [ grep { $_ ne $from } keys(%{$self->{vertices}}) ];
	$self->{d_suboptimal} = { $from => 0 };

	dijkstra_worker($self, $from, $to);
}

sub dijkstra_continue {
	my ($self, $from, $to, $del_to) = @_;
	# instead of reinitializing, it should invoke the worker after initializing
	# to a state that assumes that an edge to $del_to has just been deleted.
	goto &dijkstra_first;
}

sub dijkstra {
	my ($self, $from, $to, $del_to) = @_;
	if (!defined($self->{d_from}) or $self->{d_from} ne $from) {
		goto &dijkstra_first;
	} else {
		goto &dijkstra_continue;
	}
}

sub recursive_dijkstra {
	my ($self, $from, $to, $level, $del_to) = @_;
	my @d = ([ $self->dijkstra($from, $to, $del_to) ]);

	if (!defined($d[0]->[0])) {
		return ();
	}

	if ($level > 0) {
		foreach (0..(@{$d[0]}-1)) {
			# from copies of the graph, remove one edge from the result path,
			# and continue finding paths on that tree.
			my $g2 = dclone($self);
			$g2->deledge($d[0]->[$_]->[0], $d[0]->[$_]->[1]);
			my @new = $g2->recursive_dijkstra($from, $to, $level - 1, $d[0]->[$_]->[1]);

			# add all new paths, unless they are already present in the result set
			foreach my $n (@new) {
				push(@d, $n) unless (grep { $n ~~ $_ } @d);
			}
		}
	}

	@d;
}

sub addedge {
	# my ($self, $from, $to, $weight, $userdata) = @_;
	my $g = shift;
	deledge($g, @_[0,1]);
	my $v = $g->{vertices};
	my $v_from = $v->{$_[0]} // $g->addvertex($_[0]);
	my $v_to   = $v->{$_[1]} // $g->addvertex($_[1]);

	my $edge = [ @_ ];

	push(@{$g->{edges}}, $edge);
	push(@{$v_from->[VERT_EDGES_OUT]}, $edge);
	push(@{$v_to->[VERT_EDGES_IN]}, $edge);
}

sub deledge {
	# my ($self, $from, $to) = @_;
	my $v = $_[0]->{vertices};
	my $v_from = $v->{$_[1]};
	my $v_to   = $v->{$_[2]};

	# DEBUG FIXME
	push(@{$_[0]->{dd_del}}, $_[2])
		unless ((caller(1))[3] eq "FastaGraph::addedge");

	# find the edge. assume it only exists once -> only delete the first.
	# while we're at it, delete the edge from the source vertex...
	my $e;
	@{$v_from->[VERT_EDGES_OUT]} = grep { $_->[EDGE_TO] ne $_[2] or ($e = $_, 0) } @{$v_from->[VERT_EDGES_OUT]};
	return undef if (!defined($e));

	# now search it in the destination vertex' list, delete it there
	# also only delete the first matching one here (though now there
	# shouldn't be any duplicates at all because now we're matching the
	# actual edge, not just its endpoints like above.
	@{$v_to->[VERT_EDGES_IN]} = grep { $_ != $e } @{$v_to->[VERT_EDGES_IN]};

	# and remove it from the graph's vertex list
	@{$_[0]->{edges}} = grep { $_ != $e } @{$_[0]->{edges}}
}

1;

