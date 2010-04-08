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

__END__

=head1 NAME

RVP::Line - manage lines and all associated data

=head1 SYNOPSIS

 # Load all data
 my $line_13 = RVP::Line::from_file(file => "data/13");
 # I'm not interested in full schedules
 my $line_4  = RVP::Line::from_file(file => "data/4", no => ["schedules"]); # can also no => "schedules"

=head1 DESCRIPTION

This module provides a convenient way to load all available data for a line.
Data is stored in a text file.  The text file refers to some other files for
bulk data like full schedule data.  The format is described below.

Data is loaded by using the B<from_file> method, which takes a mandatory
named parameter I<file>, which is the name of the file from which the data
will be loaded.

The optional I<no> parameter can be used to omit loading data that is not
needed by the caller.  For example, a program might be uninterested in the
full schedule data, so it would be pointless to spend a lot of time loading
and parsing all schedule files.  The argument can be a string or an arrayref
of strings, describing the features that should not be loaded.  Currently
I<schedules>, for the complete schedule data, and I<physical_distances>,
for the list of approximate distances between stations, are valid values.

=head1 LINE DATA FILE FORMAT

The file that describes a line is a YAML document.  It has the following
fields:

=over

=item name

Friendly name for the line.  This should be short, without expanding
any acronyms, and not contain destination information.  Examples: "4",
"NE3", "RB33".

=item physical_distances_file

A filename where information about the distances between stations is
loaded from.  The path is relative to the directory that the line file
is in.

=item schedules

Contains information about the files where the schedule data can be
found.  It is a list of hashes describing one schedule file.

Currently all listed files will be used unconditionally.  In the future,
more fields will be added, so that individual files can be declared to
be only valid on certain weekdays or so.

The fields in the sub-hashes are:

=over

=item name

Friendly name for this sub-line.  The name of the line should appear in
it, followed by the commonly used method of referring to its destination.
The name of the destination doesn't need to match the true destination
station name - it can contain additional information like the name of
the district.  Example:  "903 Walsum Watereck".

=item file

Filename where the schedule data is found.  Relative to the directory
of the line data file.

=back

=back

=cut
