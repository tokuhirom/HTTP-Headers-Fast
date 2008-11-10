use strict;
use warnings;
use HTTP::Headers::Fast;

my $f = HTTP::Headers::Fast->new;

for (0..100) { $f->content_length }
