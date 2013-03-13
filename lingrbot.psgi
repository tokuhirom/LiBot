use strict;
use Plack::Builder;
use Plack::Util qw(load_psgi);

builder {
    enable 'ReverseProxy';
    mount '/lingr-bot/lleval' => Plack::Util::load_psgi('lleval.psgi');
};
