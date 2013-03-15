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
    $bot;
}

