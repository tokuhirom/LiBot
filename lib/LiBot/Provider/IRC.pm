package LiBot::Provider::IRC;
use strict;
use warnings;
use utf8;

use Mouse;

has irc => (
    is => 'rw',
);

has [qw(host port)] => (
    is => 'ro',
    required => 1,
);

has nick => (
    is => 'ro',
    default => sub { 'libot' },
);

has channels => (
    is => 'rw',
);

no Mouse;

sub run {
    my ($self, $bot) = @_;

    my $irc = AnyEvent::IRC::Client->new;
    $con->reg_cb(
        connect => sub {
            my ( $con, $err ) = @_;
            if ( defined $err ) {
                warn "connect error: $err\n";
                return;
            }
            for (@{Data::OptList::mkopt($self->channels)}) {
                $con->send_srv(JOIN => $_->[0], $_->[1]->{key});
            }
        }
    );
    $con->reg_cb( registered => sub { print "I'm in!\n"; } );
    $con->reg_cb( disconnect => sub { print "I'm out!\n"; } );
    $irc->reg_cb(
        publicmsg => sub {
            my ( $irc, $channel, $msg ) = @_;
            use Data::Dumper;
            warn Dumper($msg);
            my $text = decode_utf8( $msg->{params}->[1] );
            my ( $nickname, ) = split '!', ( $msg->{prefix} || '' );
            my $msg = LiBot::Message->new(
                text     => $text,
                nickname => $nickname,
            );
            my $proceeded = eval {
                $bot->handle_message(
                    sub {
                        $irc->send_chan( $channel, "NOTICE", $channel, $_[0] );
                    },
                    $msg
                );
            };
            if ($@) {
                print STDERR $@;
                die $@;
            }
            else {
                if ($proceeded) {
                    return;
                }
            }
        }
    );
    $irc->connect( $self->host, $self->port, { nick => $self->nick } );
    $irc->enable_ping(10);
    $self->irc($irc);
}

1;

