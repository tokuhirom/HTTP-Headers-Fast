use strict;
use warnings;
use Test::Warn;
use Test::More tests => 4;
use HTTP::Headers::Fast;
use HTTP::Headers;

sub test($&) {
    my ($title, $code) = @_;
    is $code->('HTTP::Headers::Fast'), $code->('HTTP::Headers'), $title;
}

test 'header' => sub {
    my $klass = shift;
    my $h = $klass->new;
    $h->header('foo' => 'bar');
    $h->push_header('foo' => undef);

    return warning_like {
        $h->header('foo');
    } qr/uninitialized/;
};

test "push_header's return value" => sub {
    my $klass = shift;
    my $h = $klass->new;
    $h->header('foo' => 'bar');
    $h->push_header('foo' => 'baz');
};

