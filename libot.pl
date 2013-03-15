#!/usr/bin/env perl
use strict;
use warnings;

use lib 'lib';
use LiBot;
use Furl;
use Encode qw(decode_utf8 encode_utf8);
use Text::Shorten qw(shorten_scalar);
use Getopt::Long;
use AE;
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
            my $config = $plugin->[1] || +{};

            print "Loading $module\n";
            $bot->load_plugin($module, $config);
        }
    }
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
    $bot;
}

