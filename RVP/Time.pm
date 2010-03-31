package RVP::Time;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT = qw(ts_2datetime datetime_2ts isotr_2datetime isotr_2ts datetime_2isotr ts_2isotr);

use DateTime;
use DateTime::Format::Strptime;

# convert a timestamp to a DateTime object, with the timezone of the station name.
# (NOTE: currently always assumes CE(S)T, so semantics of the context may change. it is currently ignored.)
sub ts_2datetime {
	my ($timestamp, $context) = @_;
	my $dt = DateTime->from_epoch(epoch => $timestamp, time_zone => "Europe/Berlin");
	$dt;
}

# convert a DateTime object to a proper timestamp (UTC or TAI or so)
sub datetime_2ts {
	my ($datetime) = @_;
	$datetime->epoch();
}

# parse an iso-something like date/time string into a DateTime object.
# timezone of optional context argument. (NOTE: currently assumes CE(S)T - like ts_2datetime)
sub isotr_2datetime {
	my ($isotr, $context) = @_;
	my $dt = DateTime::Format::Strptime::strptime("%Y-%m-%d %H:%M:%S", $isotr);
	$dt->set_time_zone("Europe/Berlin");
	$dt;
}

# iso timestamp to timestamp, with all weirdnesses of involved functions
sub isotr_2ts {
	datetime_2ts(isotr_2datetime(@_));
}

# datetime object to iso-something string
sub datetime_2isotr {
	my ($datetime) = @_;
	$datetime->strftime("%Y-%m-%d %H:%M:%S");
}

# timestamp to iso-something string, weirdnesses for free
sub ts_2isotr {
	datetime_2isotr(ts_2datetime(@_));
}

1;
