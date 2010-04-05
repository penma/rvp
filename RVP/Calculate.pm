package RVP::Calculate;

use strict;
use warnings;

use Data::Dumper;
use Storable qw(dclone);
use List::Util qw(sum);
use List::MoreUtils qw(indexes firstidx);

use FastaGraph;

use RVP::Schedule;

sub new {
	my ($class) = @_;
	return bless({
		graph => FastaGraph->new(),
	}, $class);
}

sub add_wait_nodes {
	my ($self, $station, $from, $to) = @_;
	for my $time ($from..$to) {
		$self->{graph}->addedge("$time $station", ($time + 1) . " $station", 1, { line => "WAIT" });
	}
}

sub add_route_data {
	my ($self, @routes) = @_;
	foreach my $route (@routes) {
		for (my $si = 0; $si <= @{$route->{route}} - 2; $si++) {
			$self->{graph}->addedge(
				"$route->{route}->[$si]->{depart} $route->{route}->[$si]->{station}",
				"$route->{route}->[$si+1]->{arrive} $route->{route}->[$si+1]->{station}",
				$route->{route}->[$si+1]->{arrive} - $route->{route}->[$si]->{depart},
				{ line => "unknown $route->{route}->[-1]->{station} (RS $route->{route}->[0]->{depart})" },
			);
		}
	}
}

sub recursive_dijkstra {
	my ($graph, $from, $to, $level, $del_to) = @_;
	my @d = ([ $graph->dijkstra($from, $to, $del_to) ]);

	if (!defined($d[0]->[0])) {
		return ();
	}

	if ($level > 0) {
		foreach (0..(@{$d[0]}-1)) {
			# from copies of the graph, remove one edge from the result path,
			# and continue finding paths on that tree.
			my $g2 = dclone($graph);
			$g2->deledge($d[0]->[$_]->[0], $d[0]->[$_]->[1]);
			my @new = recursive_dijkstra($g2, $from, $to, $level - 1, $d[0]->[$_]->[1]);

			# add all new paths, unless they are already present in the result set
			foreach my $n (@new) {
				push(@d, $n) unless (grep { $n ~~ $_ } @d);
			}
		}
	}

	@d;
}

sub calculate {
	my ($self, $from, $to, $depth) = @_;
	recursive_dijkstra($self->{graph}, $from, $to, $depth);
}

sub gid_parse {
	my ($gid) = @_;
	$gid =~ /^(?<time>\S+) (?<station>.*)$/;
	{
		time    => sprintf("%02d:%02d", int($+{time} / 60), $+{time} % 60),
		station => $+{station},
	};
}

sub gid_2time    { gid_parse(@_)->{time} }
sub gid_2station { gid_parse(@_)->{station} }

sub connection_as_events {
	my @conn = @_;
	my @stuff = grep { $_->[3]->{line} ne "WAIT" } @conn;
	my @ev;

	push(@ev, {
		event   => "depart",
		station => gid_2station($stuff[0]->[0]),
		time    => gid_2time($stuff[0]->[0]),
		line    => $stuff[0]->[3]->{line},
	});

	for (my $i = 1; $i <= @stuff - 1; $i++) {
		if ($stuff[$i]->[3]->{line} ne $stuff[$i-1]->[3]->{line}) {
			push(@ev, {
				event    => "arrive",
				station  => gid_2station($stuff[$i-1]->[1]),
				time     => gid_2time($stuff[$i-1]->[1]),
			}, {
				event    => "depart",
				station  => gid_2station($stuff[$i]->[0]),
				time     => gid_2time($stuff[$i]->[0]),
				line     => $stuff[$i]->[3]->{line},
			});
		}
	}

	push(@ev, {
		event    => "arrive",
		station  => gid_2station($stuff[-1]->[1]),
		time     => gid_2time($stuff[-1]->[1]),
	});

	@ev;
}

1;
