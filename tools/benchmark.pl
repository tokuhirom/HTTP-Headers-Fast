use strict;
use warnings;
use Benchmark qw/cmpthese/;
use HTTP::Headers;
use HTTP::Headers::Fast;

my @cases = (
    get_content_length => sub {
        my $h = HTTP::Headers->new;
        my $f = HTTP::Headers::Fast->new;

        cmpthese(
            1000000 => {
                orig => sub { $h->content_length },
                fast => sub { $f->content_length },
            },
        );
    },
    as_string => sub {
        my $h = HTTP::Headers->new(foo => "bar", foo => "baaaaz", Foo => "baz");
        my $f = HTTP::Headers::Fast->new(foo => "bar", foo => "baaaaz", Foo => "baz");
        cmpthese(
            100000 => {
                orig => sub { $h->as_string },
                fast => sub { $f->as_string },
            },
        );
    },
);
my $only = shift @ARGV;
while (my ($name, $code) = splice(@cases, 0, 2)) {
    next if $only && $only ne $name;
    print "-- $name\n";
    $code->();
    print "\n\n";
}

