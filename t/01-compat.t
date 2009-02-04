use strict;
use warnings;
use Test::Warn;
use Test::More;
use HTTP::Headers::Fast;
plan skip_all => 'this test requires HTTP::Headers 5.822 or lator' unless eval "use HTTP::Headers 5.822; 1;";
plan tests => 4;

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

