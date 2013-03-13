#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use 5.010000;
use autodie;

use Plack::Util;
use Test::WWW::Mechanize::PSGI;
use JSON;

my $app = Plack::Util::load_psgi('lleval.psgi');
my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);

if (@ARGV) {
    print '**' . doit(shift @ARGV) . '**';
    print "\n";
    exit 0;
}

print "> ";
while (<>) {
    chomp;
    print doit($_) . "\n";
    print "\n> ";
}

sub doit {
    my $msg = shift;
    my $content = encode_json({
        events => [
            {message => { text => $msg } }
        ],
    });
    my $req = HTTP::Request->new(POST => 'http://localhost/', [], $content);
    my $res = $mech->request($req);
    return $res->content;
}
