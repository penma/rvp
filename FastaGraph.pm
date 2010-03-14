package FastaGraph;

use strict;
use warnings;
use 5.010;

use List::Util qw(min);

use constant {
	EDGE_FROM => 0, EDGE_TO => 1, EDGE_WEIGHT => 2,
	VERT_NAME => 0, VERT_EDGES_OUT => 1, VERT_EDGES_IN => 2,
};

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

sub dijkstra_first {
	my ($self, $from, $to) = @_;
	$self->{d_from} = $from;
	$self->{d_dist} = {};
	$self->{d_unvisited}  = [ grep { $_ ne $from } keys(%{$self->{vertices}}) ];
	$self->{d_suboptimal} = { $from => 0 };

	dijkstra_worker($self, $from, $to);
}

sub dijkstra_worker {
	my ($self, $from, $to) = @_;

	my $vert = $self->{vertices};
	my %sub_prios = %{$self->{d_suboptimal}};
	my $sub_minkey = min values(%sub_prios);
	my %sub_queue;
	while (my ($payload, $prio) = each(%sub_prios)) {
		push(@{$sub_queue{$prio}}, $payload);
	}
	$self->{d_dist}->{$_} = -1 foreach (@{$self->{d_unvisited}});
	$self->{d_dist}->{$from} = 0;

	my $current;
	while (1) {
		# find the smallest unvisited node
		if (!defined($sub_minkey)) {
			$current = pop(@{$self->{d_unvisited}}) // last;
		} else {
			$current = shift(@{$sub_queue{$sub_minkey}});
			if (!@{$sub_queue{$sub_minkey}}) {
				delete($sub_queue{$sub_minkey});
				$sub_minkey = min keys(%sub_queue);
			}
			delete($sub_prios{$current});
		}

		# update all neighbors
		foreach my $edge (@{$vert->{$current}->[VERT_EDGES_OUT]}) {
			if (($self->{d_dist}->{$edge->[EDGE_TO]} == -1) ||
			($self->{d_dist}->{$edge->[EDGE_TO]} > ($self->{d_dist}->{$current} + $edge->[EDGE_WEIGHT]) )) {
				my $new_prio = $self->{d_dist}->{$edge->[EDGE_TO]} = $self->{d_dist}->{$current} + $edge->[EDGE_WEIGHT];
				my $orig_prio = $sub_prios{$edge->[EDGE_TO]};
				if (defined($orig_prio)) {
					$sub_queue{$orig_prio} = [ grep { $_ ne $edge->[EDGE_TO] } @{$sub_queue{$orig_prio}} ];
					if (!@{$sub_queue{$orig_prio}}) {
						delete($sub_queue{$orig_prio});
					}
				}

				$sub_prios{$edge->[EDGE_TO]} = $new_prio;
				push(@{$sub_queue{$new_prio}}, $edge->[EDGE_TO]);
				if (!defined($sub_minkey) or $new_prio < $sub_minkey) {
					$sub_minkey = $new_prio;
				} elsif ($new_prio > $sub_minkey and (defined($orig_prio) and defined($sub_queue{$orig_prio}))) {
					$sub_minkey = min keys(%sub_queue);
				}
			}
		}
	}

	# trace the path from the destination to the start
	my @path = ();
	$current = $to;
	NODE: while ($current ne $from) {
		unshift(@path, $current);
		foreach my $edge (@{$vert->{$current}->[VERT_EDGES_IN]}) {
			if ($self->{d_dist}->{$current} == $self->{d_dist}->{$edge->[EDGE_FROM]} + $edge->[EDGE_WEIGHT]) {
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

sub dijkstra {
	goto &dijkstra_first;
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

