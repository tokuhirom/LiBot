package LiBot::Handler::Karma;
use strict;
use warnings;
use utf8;
use Mouse;
use DB_File;

has path => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has dict => (
    is => 'ro',
    required => 1,
    lazy => 1,
    default => sub {
        my $self = shift;
        tie my %karma_dict, 'DB_File', $self->path;
        \%karma_dict;
    },
);

no Mouse;

sub init {
    my ($self, $bot) = @_;

    print "Registering karma bot\n";
    $bot->register(
        qr/(\w+)(\+\+|--)/ => sub {
            my ($cb, $event, $name, $op) = @_;

            print "Processing karma\n";
            $self->dict->{$name} += 1 if $op eq '++';
            $self->dict->{$name} -= 1 if $op eq '--';
            $cb->(sprintf("$name: %s", $self->dict->{$name}));
        }
    );
}

1;

