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

__END__

=head1 NAME

RVP::Planner - control the planning process

=head1 SYNOPSIS

 my $planner = RVP::Planner->new();
 $planner->add_lines($l1, $l2, ...); # RVP::Line objects
 my $plan = $planner->plan($station_from => $station_to);

=head1 DESCRIPTION

This class implements the planner component of RVP.

The planner is responsible for generating physical routes that can be
simulated thoroughly by the simulator.

=head1 LIMITATIONS

Currently it is not known or defined if or how a planner can be executed to
plan multiple trips during its lifetime.

=cut

