package HashPQ;

our $VERSION = '0.01';

use strict;
use warnings;

use List::Util qw(min);

sub new {
	return bless {
		queue => {},     # payloads by prio
		prios => {},     # prios by payload
	}, shift();
}

sub delete {
	my ($self, $payload) = @_;
	my $op = $self->{prios}->{$payload};
	if (defined($op)) {
		$self->{queue}->{$op} = [ grep { $_ ne $payload } @{$self->{queue}->{$op}} ];
		if (!@{$self->{queue}->{$op}}) {
			delete($self->{queue}->{$op});
		}
	}
}

sub pop {
	my ($self) = @_;
	my $bucket = min keys(%{$self->{queue}});
	if (!defined($bucket)) {
		return undef;
	}
	my $elem = shift(@{$self->{queue}->{$bucket}});
	if (!@{$self->{queue}->{$bucket}}) {
		delete($self->{queue}->{$bucket});
	}
	delete($self->{prios}->{$elem});
	return $elem;
}

sub update {
	my ($self, $payload, $priority) = @_;
	$self->delete($payload);
	$self->{prios}->{$payload} = $priority;
	push(@{$self->{queue}->{$priority}}, $payload);
}

*insert = \&update;

1;

__END__

=head1 NAME

HashPQ - priority queue based on perl hashes

=head1 SYNOPSIS

 my $prio = new HashPQ;
 $prio->insert("foo", 2);
 $prio->insert("bar", 1);
 $prio->insert("baz", 3);
 my $next = $prio->pop(); # "bar"
 # I decided that "foo" isn't as important anymore
 $prio->update("foo", 99);

=head1 DESCRIPTION

This module implements a high-performance priority queue. It's written in pure
Perl.

Available functions are:

=head2 B<new>()

Obvious.

=head2 B<insert>(I<$payload>, I<$priority>)

=head2 B<update>(I<$payload>, I<$new_priority>)

Adds the specified payload (anything fitting into a scalar) to the priority
queue, using the specified priority. Smaller means more important.

If the item already exists in the queue, it is assigned the new priority.

These names are actually the same function. The alternative name is provided
so you can make clear which operation you intended to be executed.

=head2 B<pop>()

Removes the most important item (numerically lowest priority) from the queue
and returns it. If no element is there, returns I<undef>.

=head2 B<delete>(I<$payload>)

Deletes an item known by the specified payload from the queue.

=head1 BUGS

Maybe.

=head1 AUTHORS & COPYRIGHTS

Made 2010 by Lars Stoltenow.
HashPQ is free software; you may redistribute it and/or modify it
under the same terms as Perl itself.

=cut
