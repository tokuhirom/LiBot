package LiBot::Handler::Corelist;
use strict;
use warnings;
use utf8;

use Module::CoreList;

use Mouse;
no Mouse;

sub init {
    my ($self, $bot) = @_;
    $bot->register(
        qr/^corelist\s+([A-Za-z:_]+)$/ => \&_handler
    );
}

sub _handler {
    my ($cb, $event, $module) = @_;
    my $r = Module::CoreList->first_release($module);
    if (defined $r) {
        $cb->("${module} was first released with perl $r");
    } else {
        $cb->("${module} was not in CORE (or so I think)");
    }
}

1;

