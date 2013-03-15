package LiBot;
use strict;
use warnings;
use utf8;

our $VERSION = '0.0.1';

use Log::Pony;

use Mouse;

has providers => (
    is => 'ro',
    default => sub { [] },
);

has handlers => (
    is => 'ro',
    default => sub { +[ ] },
);

has log_level => (
    is => 'ro',
    default => 'info',
);

has log => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        Log::Pony->new(log_level => $self->log_level)
    },
);

no Mouse;

use Module::Runtime;

sub register {
    my ($self, $re, $code) = @_;
    push @{$self->{handlers}}, [$re, $code];
}

sub load_provider {
    my ($self, $name, $args) = @_;
    push @{$self->{providers}}, $self->load_plugin('Provider', $name, $args);
}

sub load_plugin {
    my ($self, $prefix, $name, $args) = @_;

    my $klass = $name =~ s!^\+!! ? $name : "LiBot::${prefix}::$name";
    Module::Runtime::require_module($klass);
    $self->log->info("Loading $klass");
    my $obj = $klass->new($args || +{});
    $obj->init($self) if $obj->can('init');
    $obj;
}

sub run {
    my $self = shift;

    for my $provider (@{$self->providers}) {
        $provider->run($self);
    }
}

1;
