package LiBot::Message;
use strict;
use warnings;
use utf8;

use Mouse;

has text => (is => 'ro', isa => 'Str', required => 1);
has nickname => (is => 'ro', isa => 'Str', required => 1);

no Mouse;

1;

