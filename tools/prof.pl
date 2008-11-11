use strict;
use warnings;
use HTTP::Headers::Fast;

my $f = HTTP::Headers::Fast->new(foo => 'bar', baz => 'see', 'moo' => 'yan');

for (0..100) { $f->as_string }
