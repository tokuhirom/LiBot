#!/usr/bin/env perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";
use LiBot;
use Getopt::Long;
use AE;
use Data::OptList;

my $config_file = 'config.pl';
GetOptions(
    'c=s' => \$config_file,
) or die;

my $bot = setup_bot();
my $server = $bot->run();

AE::cv->recv;

sub setup_bot {
    my $bot = LiBot->new();

    my $config = do $config_file or die "Cannot load $config_file";

    # load providers
    for (@{Data::OptList::mkopt($config->{providers})}) {
        $bot->load_provider($_->[0], $_->[1]);
    }

    # load handlers
    for (@{Data::OptList::mkopt($config->{handlers})}) {
        $bot->load_plugin('Handler', $_->[0], $_->[1]);
    }

    $bot;
}

