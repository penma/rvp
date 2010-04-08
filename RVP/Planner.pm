package RVP::Planner;

use strict;
use warnings;

use FastaGraph;

sub new {
	my ($class) = @_;
	return bless({
		graph => FastaGraph->new(),
		lines => [],
	}, $class);
}

sub add_lines {
	my ($self, @lines) = @_;
	foreach my $line (@lines) {
		if (!$line->{physical_distances} or !@{$line->{physical_distances}}) {
			die("Line data of $line->{line} unusable for planner - doesn't contain physical distances information");
		}
		foreach my $conn (@{$line->{physical_distances}}) {
			$self->{graph}->addedge(@{$conn}, { line => $line->{line} });
		}
		push(@{$self->{lines}}, $line);
	}
}

sub plan {
	my ($self, $from, $to) = @_;
	my $plan = {};
	$plan->{trips} = [ $self->{graph}->recursive_dijkstra($from, $to, 1) ];
	$plan->{physical_distances} = $self->{graph}->{d_dist};
	$plan;
}

1;
