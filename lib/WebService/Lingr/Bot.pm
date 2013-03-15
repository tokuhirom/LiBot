package WebService::Lingr::Bot;
use strict;
use warnings;
use utf8;

use Plack::Request;
use JSON qw(decode_json);
use Encode qw(encode_utf8 decode_utf8);
use Twiggy::Server;
use Plack::Builder;

sub new {
    my $class = shift;
    bless {
        handlers => [],
    }, $class;
}

sub register {
    my ($self, $re, $code) = @_;
    push @{$self->{handlers}}, [$re, $code];
}

sub handle_request {
    my ($self, $json) = @_;

    my $ret = '';
    if ( $json && $json->{events} ) {
        LOOP: for my $event ( @{ $json->{events} } ) {
            for my $handler (@{$self->{handlers}}) {
                if (my @matched = ($event->{message}->{text} =~ $handler->[0])) {
                    $ret = $handler->[1]->(@matched);
                    last LOOP;
                }
            }
        }
    }
    $ret =~ s!\n+$!!;
    return [200, ['Content-Type' => 'text/plain'], [encode_utf8($ret || '')]];
}

sub to_app {
    my $self = shift;

    warn "TO APP";
    sub {
        warn "APP";
        my $req = Plack::Request->new(shift);

        if ($req->method eq 'POST') {
            my $json = decode_json($req->content);
            return $self->handle_request($json);
        } else {
            # とくによばれない
            return [200, ['Content-Type' => 'text/plain'], ["I'm lingr bot"]];
        }
    };
}

sub run {
    my $self = shift;
    warn @_;
    my $server = Twiggy::Server->new(@_);
    $server->register_service(builder {
        enable 'AccessLog';
        $self->to_app
    });
    return $server;
}

1;

