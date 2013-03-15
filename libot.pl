#!/usr/bin/env perl
use strict;
use warnings;

use lib 'lib';
use LiBot;
use Furl;
use URI::Escape qw(uri_escape_utf8);
use JSON qw(decode_json);
use Encode qw(decode_utf8 encode_utf8);
use Text::Shorten qw(shorten_scalar);
use Getopt::Long;
use AE;
use AnyEvent::IRC::Client;
use GDBM_File;
use Data::OptList;

my $host = '127.0.0.1';
my $port = 6000;
my $config_file = 'config.pl';
GetOptions(
    'host=s' => \$host,
    'port=s' => \$port,
    'c=s' => \$config_file,
) or die;

my $irc = setup_irc();
my $bot = setup_bot();
my $server = $bot->run( host => $host, port => $port );
print "http://$host:$port/\n";

AE::cv->recv;

sub setup_bot {
    my $bot = LiBot->new();
    {
        my $config = do $config_file or die "Cannot load $config_file";
        for my $plugin (@{Data::OptList::mkopt($config->{plugins})}) {
            my $module = $plugin->[0];
            my $config = $plugin->[1];

            print "Loading $module\n";
            $bot->load_plugin($module, $config);
        }
    }
    $bot->register(
        qr/^!\s*(.*)/ => sub {
            my ( $cb, $event, $code ) = @_;

            unless ( $code =~ m{^(print|say)} ) {
                $code = "print sub { ${code} }->()";
            }
            my $res = lleval($code);
            if ( defined $res->{error} ) {
                $cb->( shorten_scalar( $res->{error}, 80 ) );
            }
            else {
                $cb->( shorten_scalar( $res->{stdout} . $res->{stderr}, 80 ) );
            }
        }
    );
    $bot->register(
        qr/^perldoc\s+(.*)/ => sub {
            my ( $cb, $event, $arg ) = @_;

            pipe( my $rh, my $wh );

            my $pid = fork();
            $pid // do {
                close $rh;
                close $wh;
                die $!;
            };

            if ($pid) {

                # parent
                close $wh;

                my $ret = '';
                my $sweep;
                my $timer = AE::timer(
                    10, 0,
                    sub {
                        kill 9, $pid;
                    }
                );
                my $child;
                $child = AE::child(
                    $pid,
                    sub {
                        undef $timer;
                        $ret =~ s/NAME\n//;
                        $ret =~ s/\nDESCRIPTION\n/\n/;
                        $ret = shorten_scalar( decode_utf8($ret), 120 );
                        if ( $arg =~ /\A[\$\@\%]/ ) {
                            $ret .= "\n\nhttp://perldoc.jp/perlvar";
                        }
                        elsif ( $arg =~ /\A-[a-z]\s+(.+)/ ) {
                            $ret .= "\n\nhttp://perldoc.jp/$1";
                        }
                        else {
                            $ret .= "\n\nhttp://perldoc.jp/$arg";
                        }
                        $cb->($ret);
                        undef $sweep;
                        undef $child;
                    }
                );
                $sweep = AE::io(
                    $rh, 0,
                    sub {
                        $ret .= scalar(<$rh>);
                    }
                );
            }
            else {
                # child
                close $rh;

                open STDERR, '>&', $wh
                  or die "failed to redirect STDERR to logfile";
                open STDOUT, '>&', $wh
                  or die "failed to redirect STDOUT to logfile";

                eval {
                    require Pod::PerldocJp;
                    local @ARGV = split /\s+/, $arg;
                    if ( @ARGV == 1 && $ARGV[0] =~ /^[\$\@\%]/ ) {
                        unshift @ARGV, '-v';
                    }
                    unshift @ARGV, '-J';
                    @ARGV = map { encode_utf8($_) } @ARGV;
                    Pod::PerldocJp->run();
                };
                warn $@ if $@;

                exit 0;
            }
        }
    );
    $bot->register(
        qr/@[a-zA-Z_-]+/ => sub {
            my ( $cb, $event, $arg ) = @_;
            print "Send mention\n";
            my $nickname = $event->{message}->{nickname};
            substr($nickname, 1, 1) = '*'; # do not highlight me.
            my $msg = sprintf("(%s) %s", $nickname, $event->{message}->{text});
            $irc->send_chan('#hiratara', 'PRIVMSG', '#hiratara', encode_utf8($msg));
            $cb->('');
        }
    );
    $bot;
}

sub setup_irc {
    my $irc = AnyEvent::IRC::Client->new;
    $irc->reg_cb (registered => sub {
        my $con = shift;
        print "I'm in!\n";
        $con->enable_ping(10);
        $con->send_srv('JOIN', '#hiratara');
    });
    $irc->reg_cb (join => sub {
        print "Join\n";
    });
    if ($ENV{DEBUG}) {
        $irc->reg_cb(
            debug_recv => sub {
                my $ircmsg = shift;
                print "[DEBUG-RECV] $ircmsg\n";
            },
            debug_send => sub {
                my $ircmsg = shift;
                print "[DEBUG-SEND] $ircmsg\n";
            },
        );
    }
    $irc->reg_cb (disconnect => sub { print "I'm out!\n"; });
    $irc->reg_cb (connect => sub {
        my ($con, $err) = @_;
        if (defined $err) {
            warn "IRC connect error: $err\n";
            exit 0;
        }
        print "Connected.\n";
    });
    $irc->reg_cb (error => sub {
        my ($code, $message, $ircmsg) = @_;
        print "Error: $code, $message, $ircmsg\n";
    });
    $irc->connect('chat.freenode.net', 6667, {nick => 'perl_lingr_bot'});
    return $irc;
}

sub lleval {
    my $src = shift;
    my $ua = Furl->new(agent => 'lleval2lingr', timeout => 5);
    my $res = $ua->get('http://api.dan.co.jp/lleval.cgi?l=pl&s=' . uri_escape_utf8($src));
    $res->is_success or die $res->status_line;
    print $res->content, "\n";
    return decode_json($res->content);
}
