package RVP::PhysicalDistances;

use strict;
use warnings;

use Data::Dumper;
use File::Slurp;

sub _from_lines_simple {
	my @lines = @_;
	my @out;
	for (my $c = 0; $c <= @lines - 2; $c++) {
		push(@out, [ $lines[$c], $lines[$c + 1], 1 ], [ $lines[$c + 1], $lines[$c], 1 ]);
	}
	@out;
}

sub _from_lines_sdelim {
	my @lines = @_;
	my @out;
	# extended format: each line is exactly one segment:
	# [from]    [to]   [time_estimate] [dir]
	my $last_to;
	for (my $c = 1; $c < scalar(@lines); $c++) {
		my ($from, $to, $time_estimate, $autoreverse) = ($lines[$c] =~ /^\[(.*?)\]\s+\[(.*?)\]\s+\[(\d+)\]\s+\[(\d)\]$/);
		next if (!defined($from) and !defined($to)); # skip lines without the right format
		if ($from eq "") { $from = $last_to; }
		push(@out, [ $from, $to, $time_estimate ]);
		push(@out, [ $to, $from, $time_estimate ]) if ($autoreverse);
		$last_to = $to;
	}
	@out;
}

sub from_lines {
	my @lines = @_;
	chomp(@lines);
	if ($lines[0] !~ /^#/) {
		_from_lines_simple(@lines);
	} else {
		_from_lines_sdelim(@lines);
	}
}

sub from_file {
	my ($file) = @_;
	my @lines = read_file($file, binmode => ":utf8");
	from_lines(@lines);
}

1;

__END__

=head1 NAME

RVP::PhysicalDistances - read a file describing physical distances between stations

=head1 DESCRIPTION

To speed up route finding, RVP uses a special graph for determining which
routes it will have to take a look at.  In this graph, the edges describe
the approximate time that will be needed to get from one station to another,
only considering raw travel time, without waiting at stations.  From that,
a list of useful routes will be collected, these will be simulated then.

This module reads the data files that contains this data.  It offers one
function, B<from_file>, that reads the data from the specified filename,
automatically figuring out the file format.  It returns a list of
arrayrefs that describe one connection each.  C<[ $from, $to, $minutes ]>

=head1 FILE FORMATS

Currently two file formats are supported.

=head2 Simple

This file format contains the name of one station per line, without any extra
parameters.  All travel times are assumed to be one minute.

The simplicity of this module means that it also is unsuitable for
everything but testing.  It might be removed in future versions.

=head2 SDELIM format

This format describes one connection per line.  It supports comments, on lines
that begin with a C<#> character.  To have the file identified as an SDELIM
file, the first line has to be a comment.  Otherwise, it is formatted like this:

 [from] [to] [time] [flags]

I<from> and I<to> again are station names.  If the I<from> name is empty, then
the name from the last I<to> is substituted instead.  The I<time> is given in
minutes, again.  I<flags> are a combination of logical-ORed values for several
settings, of which there is currently one.  If flags is 1, then a second
connection in the opposite direction is also generated, if it is 0, then this
is omitted (if some stations on a route are only served in one direction).

=cut

