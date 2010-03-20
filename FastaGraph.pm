package FastaGraph;

use strict;
use warnings;
use 5.010;

use Data::Dumper;
use List::Util qw(min);

use constant {
	EDGE_FROM => 0, EDGE_TO => 1, EDGE_WEIGHT => 2,
	VERT_NAME => 0, VERT_EDGES_OUT => 1, VERT_EDGES_IN => 2,

	INFINITY => 2**30, # FIXME
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

sub lpa_calculate_key {
	my ($self, $vertex) = @_;
	return min($self->{lpa_g}->{$vertex}, $self->{lpa_rhs}->{$vertex});
}

sub lpa_init {
	my ($self, $from, $to) = @_;
	$self->{lpa_from} = $from;
	$self->{lpa_to}   = $to;
	$self->{lpa_u} = HashPQ->new();
	foreach my $v (keys(%{$self->{vertices}})) {
		$self->{lpa_rhs}->{$v} = INFINITY;
		$self->{lpa_g}->{$v}   = INFINITY;
	}
	$self->{lpa_rhs}->{$from} = 0;
	$self->{lpa_u}->insert($from, 0); # lpa* would use the heuristic here - it's 0 for us.
}

sub lpa_update_vertex {
	my ($self, $vertex) = @_;
	print "lpa_update_vertex($vertex)\n";
	if ($vertex ne $self->{lpa_from}) {
		$self->{lpa_rhs}->{$vertex} = min(map { $self->{lpa_g}->{$_->[EDGE_FROM]} + $_->[EDGE_WEIGHT] } @{$self->{vertices}->{$vertex}->[VERT_EDGES_IN]});
	}
	$self->{lpa_u}->delete($vertex);
	print "PRIOR TO UPDATING $vertex : g=$self->{lpa_g}->{$vertex} rhs=$self->{lpa_rhs}->{$vertex}\n";
	if ($self->{lpa_g}->{$vertex} != $self->{lpa_rhs}->{$vertex}) {
		$self->{lpa_u}->insert($vertex, lpa_calculate_key($self, $vertex));
	}
}

sub lpa_compute_shortest_path {
	my ($self) = @_;
	my $c = 100;
	while (1) {
		$c-- or last; # XXX XXX XXX
		my $current = $self->{lpa_u}->pop();
		# shall it be popped here? algo pseudocode says different, but who knows.
		last if (!defined($current));

		unless (lpa_calculate_key($self, $current) < lpa_calculate_key($self, $self->{lpa_to})
		or $self->{lpa_rhs}->{$self->{lpa_to}} != $self->{lpa_g}->{$self->{lpa_to}}) {
			last;
		}

		if ($self->{lpa_g}->{$current} > $self->{lpa_rhs}->{$current}) {
			$self->{lpa_g}->{$current} = $self->{lpa_rhs}->{$current};
		} else {
			$self->{lpa_g}->{$current} = INFINITY;
			lpa_update_vertex($self, $current); # XXX can we do this now, or do we have to do this after the loop
		}
		foreach my $succ (map { $_->[EDGE_TO] } @{$self->{vertices}->{$current}->[VERT_EDGES_OUT]}) {
			lpa_update_vertex($self, $succ);
		}
	}
}

sub lpp_trace {
	my ($self) = @_;
	my ($from, $to) = ($self->{lpa_from}, $self->{lpa_to});
	my @path = ();
	my $current = $to;
	NODE: while ($current ne $from) {
		unshift(@path, $current);
		foreach my $edge (@{$self->{vertices}->{$current}->[VERT_EDGES_IN]}) {
			if ($self->{lpa_g}->{$current} == $self->{lpa_g}->{$edge->[EDGE_FROM]} + $edge->[EDGE_WEIGHT]) {
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
	my ($self, $from, $to, $del_to) = @_;
	print "__fake_dijkstra($from, $to, $del_to)\n";
	if (!defined($self->{lpa_from}) or $self->{lpa_from} ne $from) {
		print "__fake_dijkstra> needs to reinitialize\n";
		lpa_init($self, $from, $to);
		lpa_compute_shortest_path($self); # XXX superfluous?
	}
	if (defined($del_to)) { # XXX
		print "__fake_dijkstra> segment $del_to has been deleted\n";
		lpa_update_vertex($self, $del_to);
		lpa_compute_shortest_path($self);
	}

	return lpp_trace($self);
}

sub addedge {
	# my ($self, $from, $to, $weight) = @_;
	deledge(@_[0..2]); # TODO find cleaner method of ensuring that an edge is not added twice.
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

