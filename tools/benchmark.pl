use strict;
use warnings;
use Benchmark qw/cmpthese/;
use HTTP::Headers;
use HTTP::Headers::Fast;

my $h = HTTP::Headers->new;
my $f = HTTP::Headers::Fast->new;

cmpthese(
    1000000 => {
        orig => sub { $h->content_length },
        fast => sub { $f->content_length },
    },
);
