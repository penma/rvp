package RVP::Line;

use strict;
use warnings;

use Data::Dumper;
use File::Basename;
use YAML qw();

use RVP::Schedule;
use RVP::PhysicalDistances;

sub from_file {
	my %args = @_;

	# load all the description stuff
	my $line_data = YAML::LoadFile($args{file});

	# load physical distances
	if (not "physical_distances" ~~ $args{no}) {
		@{$line_data->{physical_distances}} = RVP::PhysicalDistances::from_file(dirname($args{file}) . "/" . $line_data->{physical_distances_file});
	}

	# load the associated schedules
	if (not "schedules" ~~ $args{no}) {
		foreach my $schedule (@{$line_data->{schedules}}) {
			@{$schedule->{routes}} = RVP::Schedule::from_file(dirname($args{file}) . "/" . $schedule->{file});
		}
	}

	$line_data;
}

1;
