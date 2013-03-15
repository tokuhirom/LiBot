package LiBot::Plugin::LLEval;
use strict;
use warnings;
use utf8;
use JSON qw(decode_json);
use URI::Escape qw(uri_escape_utf8);
use Text::Shorten qw(shorten_scalar);

sub new {
    my ($class, %args) = @_;
    bless \%args, $class;
}

sub init {
    my ($self, $bot) = @_;

    print "Registering lleval bot\n";
    $bot->register(
        qr/^!\s*(.*)/ => sub {
            my ( $cb, $event, $code ) = @_;

            unless ( $code =~ m{^(print|say)} ) {
                $code = "print sub { ${code} }->()";
            }
            my $res = lleval($code);
            if ( defined $res->{error} ) {
                $cb->( shorten_scalar( $res->{error}, 80 ) );
            }
            else {
                $cb->( shorten_scalar( $res->{stdout} . $res->{stderr}, 80 ) );
            }
        }
    );
}

sub lleval {
    my $src = shift;
    my $ua = Furl->new(agent => 'lleval2lingr', timeout => 5);
    $ua->env_proxy;
    my $res = $ua->get('http://api.dan.co.jp/lleval.cgi?l=pl&s=' . uri_escape_utf8($src));
    $res->is_success or die $res->status_line;
    print $res->content, "\n";
    return decode_json($res->content);
}

1;

