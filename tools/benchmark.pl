use strict;
use warnings;
use Benchmark qw/cmpthese/;
use HTTP::Headers;
use HTTP::Headers::Fast;

my %source = (
    'Connection'     => 'close',
    'Date'           => 'Tue, 11 Nov 2008 01:16:37 GMT',
    'Content-Length' => 3744,
    'Content-Type'   => 'text/html',
    'Status'         => 200,
);

my @cases = (
    push_header => sub {
        my $h = HTTP::Headers->new;
        my $f = HTTP::Headers::Fast->new;

        cmpthese(
            1000000 => {
                orig => sub { $h->push_header('X-Foo' => 1) },
                fast => sub { $f->push_header('X-Foo' => 1) },
            },
        );
    },
    scan => sub {
        my $h = HTTP::Headers->new(%source);
        my $f = HTTP::Headers::Fast->new(%source);

        cmpthese(
            1000000 => {
                orig => sub { $h->scan(sub { }) },
                fast => sub { $f->scan(sub { }) },
            },
        );
    },
    get_header => sub {
        my $h = HTTP::Headers->new;
        my $f = HTTP::Headers::Fast->new;

        cmpthese(
            1000000 => {
                orig => sub { $h->header('Content-Length') },
                fast => sub { $f->header('Content-Length') },
            },
        );
    },
    set_header => sub {
        my $h = HTTP::Headers->new;
        my $f = HTTP::Headers::Fast->new;

        cmpthese(
            1000000 => {
                orig => sub { $h->header('Content-Length' => 100) },
                fast => sub { $f->header('Content-Length' => 100) },
            },
        );
    },
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
        my $h = HTTP::Headers->new(%source);
        my $f = HTTP::Headers::Fast->new(%source);
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

