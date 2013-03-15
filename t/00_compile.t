use strict;
use warnings;
use utf8;
use Test::More;
use Test::AllModules;

all_ok(
    search_path => 'LiBot',
    check       => sub {
        my $class = shift;
        eval "use $class;1;";
    },
);

