#!/usr/bin/env perl
use strict;
use warnings;

use Furl;
use URI::Escape qw(uri_escape_utf8);
use Plack::Request;
use JSON qw(decode_json);
use Encode qw(encode_utf8 decode_utf8);
use Text::Shorten qw(shorten_scalar);

sub lleval {
    my $src = shift;
    my $ua = Furl->new(agent => 'lleval2lingr', timeout => 5);
    my $res = $ua->get('http://api.dan.co.jp/lleval.cgi?l=pl&s=' . uri_escape_utf8($src));
    $res->is_success or die $res->status_line;
    print $res->content, "\n";
    return decode_json($res->content);
}


my @HANDLERS;
sub register_hook($&) {
    my ($re, $code) = @_;
    push @HANDLERS, [$re, $code];
}

register_hook(qr/^!perl\s(.*)/ => sub {
    my $res = lleval($1);
    if (defined $res->{error}) {
        return shorten_scalar($res->{error}, 80);
    } else {
        return shorten_scalar($res->{stdout} . $res->{stderr}, 80);
    }
});


register_hook(qr/^perldoc\s+(.*)/ => sub {
    my ($arg) = @_;

    pipe(my $rh, my $wh);

    my $pid = fork();
    $pid // do {
        close $rh;
        close $wh;
        die $!;
    };

    if ($pid) {
        # parent
        close $wh;

        local $SIG{ALRM} = sub { kill 9, $pid; waitpid($pid, 0); die "Timeout\n" };
        my $ret = '';
        eval {
            alarm 3;
            $ret .= $_ while <$rh>;
            close $rh;
            1 while wait == -1;
        };
        return $@ if $@;
        $ret =~ s/NAME\n//;
        $ret =~ s/\nDESCRIPTION\n/\n/;
        $ret = shorten_scalar(decode_utf8($ret), 120);
        if ($arg =~ /\A[\$\@\%]/) {
            $ret .= "\n\nhttp://perldoc.jp/perlvar";
        } elsif ($arg =~ /\A-[a-z]\s+(.+)/) {
            $ret .= "\n\nhttp://perldoc.jp/$1";
        } else {
            $ret .= "\n\nhttp://perldoc.jp/$arg";
        }
    } else {
        # child
        close $rh;

        open STDERR, '>&', $wh
          or die "failed to redirect STDERR to logfile";
        open STDOUT, '>&', $wh
          or die "failed to redirect STDOUT to logfile";

        eval {
            require Pod::PerldocJp;
            local @ARGV = split /\s+/, $arg;
            if (@ARGV == 1 && $ARGV[0] =~ /^[\$\@\%]/) {
                unshift @ARGV, '-v';
            }
            unshift @ARGV, '-J';
            Pod::PerldocJp->run();
        };
        warn $@ if $@;

        exit 0;
    }
});

sub handler {
    my $json = shift;
    my $ret = '';
    if ( $json && $json->{events} ) {
        LOOP: for my $event ( @{ $json->{events} } ) {
            for my $handler (@HANDLERS) {
                if (my @matched = ($event->{message}->{text} =~ $handler->[0])) {
                    $ret = $handler->[1]->(@matched);
                    last LOOP;
                }
            }
        }
    }
    return [200, ['Content-Type' => 'text/plain'], [encode_utf8($ret || '')]];
}

no warnings 'void';
sub {
    my $req = Plack::Request->new(shift);

    if ($req->method eq 'POST') {
        my $json = decode_json($req->content);
        return handler($json);
    } else {
        # とくによばれない
        return [200, ['Content-Type' => 'text/plain'], ["I'm lleval2lingr bot"]];
    }
};
