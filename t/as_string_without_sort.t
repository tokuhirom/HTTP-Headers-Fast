use strict;
use Test qw(plan ok);
require HTTP::Headers::Fast;

plan tests => 1;

my $h = HTTP::Headers::Fast->new(foo => "bar", foo => "baaaaz", Foo => "baz");
ok($h->as_string_without_sort(), "Foo: bar\nFoo: baaaaz\nFoo: baz\n");

