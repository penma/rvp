package RVP::Schedule;

use strict;
use warnings;

# parse timestamp with all fancy features
sub _parse_time {
	my ($time, $prev_time) = @_;
	$time =~ /^(?:((?#hour)\d+)\.)?0*((?#minute)\d+)$/;
	if (!defined($1) and !defined($prev_time)) {
		die("Error in data: need a previous time when omitting hour information");
	}
	my $hour = $1 // int($prev_time / 60);

	return ($hour * 60 + $2, $hour * 60 + $2);
}

sub from_lines {
	my @lines = @_;

	my @stations;          # preserves the order
	my %times_by_station;
	foreach my $line (@lines) {
		chomp($line);
		my ($station, @times) = split(/\s*\|\s*/, $line);
		push(@stations, $station);
		if (exists($times_by_station{$station})) {
			die("Duplicate station \"$station\" in schedule data");
		}
		$times_by_station{$station} = \@times;
	}

	# now transpose the table, generating routes from it.
	my @routes;
	my $ri = 0;
	while (grep { exists($_->[$ri]) } values(%times_by_station)) {
		my @stations_def = grep { ($times_by_station{$_}->[$ri] // "") ne "" } @stations;
		my $prev_depart;
		my (undef, $first_depart) = parse_time($times_by_station{$stations_def[0]}->[$ri]);
		my $route = { route => [], stations => {} };
		@{$route->{route}} = map {
			my $station = $_;

			# calculate arrive/depart times
			my ($arrive, $depart) = parse_time($times_by_station{$station}->[$ri], $prev_depart);
			$prev_depart = $depart;

			# track offset to first station
			$route->{stations}->{$station} = $depart - $first_depart;
			$route->{stations}->{$station} += 60*24 if ($route->{stations}->{$station} < 0); # can happen if route goes through midnight

			{ station => $station, arrive => $arrive, depart => $depart }
		} @stations_def;

		push(@routes, $route);
		$ri++;
	}

	@routes;
}

sub from_file {
	my ($filename) = @_;
	open(my $schedule, "<:utf8", $filename) or die("Couldn't open schedule file \"$filename\": $!");
	from_lines(<$schedule>);
}

1;

__END__

=head1 NAME

RVP::Schedule - load textual schedule data and generate route templates

=head1 SYNOPSIS

 my @routes = RVP::Schedule::from_file("data/stuff.csv");

=head1 DESCRIPTION

This module reads a schedule description (from a file or from a list of
strings) and generates a set of route templates from that.

It offers two functions: B<from_lines> takes a list of lines and returns
a list of routes.  These lines have the format described below.

B<from_file> opens the specified file for you, parses it and returns the
data.

Future versions might cache the results for you.

=head1 FILE FORMATS

Currently there is one supported format.

=head2 Tabular VRR-Style

This format represents all data in a tabular format.  It is encoded in
a format similar to CSV:  one line contains one row of data, columns
are separated by pipe (C<|>) characters and there is no fancy escaping
stuff. Whitespace at the start or end of a field is ignored and can
be used to align fields.

The file format is very close to the format of the official schedules
published by the VRR.  One column describes exactly one trip.  The
rows describe exactly one station.  Every field contains the arrival
or departure time of one particular route at one particular station.

In the VRR schedules, differing arrival and departure times are represented
by inserting an additional station line (in some cases a footnote is added
stating that arrival at station X will be Y minutes earlier).  The format
used by RVP allows two times to be specified in one field, separated by a
slash (C</>). In that case, the first is arrival and the second is departure.

(Note that support for two different times is not implemented yet.)

=cut

