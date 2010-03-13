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
	my $op = $self->{prios}->{$payload};
	if (defined($op)) {
		$self->{queue}->{$op} = [ grep { $_ ne $payload } @{$self->{queue}->{$op}} ];
		if (!@{$self->{queue}->{$op}}) {
			delete($self->{queue}->{$op});
		}
	}
	$self->{prios}->{$payload} = $priority;
	push(@{$self->{queue}->{$priority}}, $payload);
}

*insert = \&update;

1;

__END__

=head1 NAME

List::PriorityQueue - high performance priority list (pure perl)

=head1 SYNOPSIS

 my $prio = new List::PriorityQueue;
 $prio->insert("foo", 2);
 $prio->insert("bar", 1);
 $prio->insert("baz", 3);
 my $next = $prio->pop(); # "bar"
 # I decided that "foo" isn't as important anymore
 $prio->update("foo", 99);

=head1 DESCRIPTION

This module implements a high-performance priority list. It's written in pure
Perl.

Available functions are:

=head2 B<new>()

Obvious.

=head2 B<insert>(I<$payload>, I<$priority>)

=head2 B<update>(I<$payload>, I<$new_priority>)

Adds the specified payload (anything fitting into a scalar) to the priority
queue, using the specified priority. Smaller means more important.

If the item already exists in the queue, it is assigned the new priority.
It's optimized to perform better than a delete followed by insert.

These names are actually the same function. The alternative name is provided
so you can make clear which operation you intended to be executed.

=head2 B<pop>()

Removes the most important item (numerically lowest priority) from the queue
and returns it. If no element is there, returns I<undef>.

=head2 B<delete>(I<$payload>)

Deletes an item known by the specified payload from the queue.

=head2 B<unchecked_insert>(I<$payload>, I<$priority>)

=head2 B<unchecked_update>(I<$payload>, I<$new_priority>)

These functions are provided as an alternative to the safe (or "checked")
functions described above. By bypassing some checks, they gain you a speed
advantage, but if you don't know what you're doing, using these might
corrupt/confuse the queue.

You can use these if you I<definitely> know that the element doesn't exist
yet for B<unchecked_insert>, or that the element definitely already exists
for B<unchecked_update>.

=head1 DIFFERENCES TO POE::QUEUE::ARRAY

There are some things I disliked about POE::Queue::Array, which ultimately
led to the creation of this derivative.

First, it stores data in a package global variable. The author brings up a
valid argument why this is not bad in this case. However I still was somehow
not happy with the fact it used a global variable. For example, serializing
a queue would not work as the actual queue reference only stores numerical
IDs into the package variable containing all the data, but that one wouldn't
be saved.

Second, for some operations to be carried out efficiently, you have to carry
the internal IDs around in your program, else you have to do a full search
for your element everytime you want to delete or update it. While carrying it
around is relatively simple, there is no reason why the class itself shouldn't
manage this and relieve the programmer from this work.

A benchmark with POE::Queue::Array and the described payload-to-ID mapping and
this module revealed that they are equally fast.

=head1 BUGS

Maybe.

=head1 SEE ALSO

L<POE::Queue::Array>

=head1 AUTHORS & COPYRIGHTS

Made 2009 by Lars Stoltenow.
List::PriorityQueue is free software; you may redistribute it and/or modify it
under the same terms as Perl itself.

POE::Queue::Array is Copyright 1998-2007 Rocco Caputo. All rights reserved.
Same license.

=cut
