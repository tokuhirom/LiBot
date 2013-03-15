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

    return sub {
        my $respond = shift;
        my $cb = sub {
            my $ret = shift;
            $ret =~ s!\n+$!!;
            $respond->([200, ['Content-Type' => 'text/plain'], [encode_utf8($ret || '')]]);
        };
        if ( $json && $json->{events} ) {
            for my $event ( @{ $json->{events} } ) {
                for my $handler (@{$self->{handlers}}) {
                    if (my @matched = ($event->{message}->{text} =~ $handler->[0])) {
                        $handler->[1]->($cb, $event, @matched);
                        return;
                    }
                }
            }
        }

        # Not proceeeded.
        $respond->([200, ['Content-Type' => 'text/plain'], ['']]);
    };
}

sub to_app {
    my $self = shift;

    sub {
        my $req = Plack::Request->new(shift);

        if ($req->method eq 'POST') {
            my $json = decode_json($req->content);
            return $self->handle_request($json);
        } else {
            # lingr server always calls me by POST method.
            # This is human's health check page.
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
__END__

=head1 SYNOPSIS

    my $bot = WebService::Lingr::Bot->new();
    $bot->register(qr/^!\s*(.*)/ => sub {
        my ($event, $msg) = @_;
        uc($msg);
    });
    $bot->run(host => '127.0.0.1', port => 5963);

