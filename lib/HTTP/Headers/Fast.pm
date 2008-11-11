package HTTP::Headers::Fast;
use strict;
use warnings;
use 5.00800;
our $VERSION = '0.01';
use Carp ();
use base qw/HTTP::Headers/;

our $TRANSLATE_UNDERSCORE = 1;

# "Good Practice" order of HTTP message headers:
#    - General-Headers
#    - Request-Headers
#    - Response-Headers
#    - Entity-Headers

use Readonly;
Readonly::Scalar my $OP_GET    => 0;
Readonly::Scalar my $OP_SET    => 1;
Readonly::Scalar my $OP_INIT   => 2;
Readonly::Scalar my $OP_PUSH   => 3;
Readonly::Scalar my $OP_PUSH_H => 4;

my @general_headers = qw(
  Cache-Control Connection Date Pragma Trailer Transfer-Encoding Upgrade
  Via Warning
);

my @request_headers = qw(
  Accept Accept-Charset Accept-Encoding Accept-Language
  Authorization Expect From Host
  If-Match If-Modified-Since If-None-Match If-Range If-Unmodified-Since
  Max-Forwards Proxy-Authorization Range Referer TE User-Agent
);

my @response_headers = qw(
  Accept-Ranges Age ETag Location Proxy-Authenticate Retry-After Server
  Vary WWW-Authenticate
);

my @entity_headers = qw(
  Allow Content-Encoding Content-Language Content-Length Content-Location
  Content-MD5 Content-Range Content-Type Expires Last-Modified
);

my %entity_header = map { lc($_) => 1 } @entity_headers;

my @header_order =
  ( @general_headers, @request_headers, @response_headers, @entity_headers, );

# Make alternative representations of @header_order.  This is used
# for sorting and case matching.
my %header_order;
my %standard_case;

{
    my $i = 0;
    for (@header_order) {
        my $lc = lc $_;
        $header_order{$lc}  = ++$i;
        $standard_case{$lc} = $_;
    }
}

sub new {
    my ($class) = shift;
    my $self = bless {}, $class;
    $self->header(@_) if @_;    # set up initial headers
    $self;
}

sub header {
    my $self = shift;
    Carp::croak('Usage: $h->header($field, ...)') unless @_;
    my (@old);
    my %seen;
    while (@_) {
        my $field = shift;
        my $op = @_ ? ( $seen{ lc($field) }++ ? $OP_PUSH : $OP_SET ) : $OP_GET;
        @old = $self->_header( $field, shift, $op );
    }
    return @old    if wantarray;
    return $old[0] if @old <= 1;
    join( ", ", @old );
}

sub clear {
    my $self = shift;
    %$self = ();
}

sub push_header {
    my $self = shift;
    return $self->_header( @_, $OP_PUSH_H ) if @_ == 2;
    while (@_) {
        $self->_header( splice( @_, 0, 2 ), $OP_PUSH_H );
    }
}

sub init_header {
    Carp::croak('Usage: $h->init_header($field, $val)') if @_ != 3;
    shift->_header( @_, $OP_INIT );
}

sub remove_header {
    my ( $self, @fields ) = @_;
    my $field;
    my @values;
    for my $field (@fields) {
        $field =~ tr/_/-/ if $field !~ /^:/ && $TRANSLATE_UNDERSCORE;
        my $v = delete $self->{ lc $field };
        push( @values, ref($v) eq 'ARRAY' ? @$v : $v ) if defined $v;
    }
    return @values;
}

sub remove_content_headers {
    my $self = shift;
    unless ( defined(wantarray) ) {

        # fast branch that does not create return object
        delete @$self{ grep $entity_header{$_} || /^content-/, keys %$self };
        return;
    }

    my $c = ref($self)->new;
    for my $f ( grep $entity_header{$_} || /^content-/, keys %$self ) {
        $c->{$f} = delete $self->{$f};
    }
    $c;
}

my $standardize_field_name = sub {
    my $field = shift;
    $field =~ tr/_/-/ if $TRANSLATE_UNDERSCORE;
    my $old = $field;
    $field = lc $field;
    unless ( defined $standard_case{$field} ) {
        # generate a %standard_case entry for this field
        $old =~ s/\b(\w)/\u$1/g;
        $standard_case{$field} = $old;
    }
    return $field;
};

sub _header_get {
    my ($self, $field) = @_;

    $field = $standardize_field_name->($field) unless $field =~ /^:/;

    my $h = $self->{$field};
    my @old = ref($h) eq 'ARRAY' ? @$h : ( defined($h) ? ($h) : () );
    return @old;
}

sub _header {
    my ( $self, $field, $val, $op ) = @_;

    $field = $standardize_field_name->($field) unless $field =~ /^:/;

    $op ||= defined($val) ? $OP_SET : $OP_GET;
    if ( $op == $OP_PUSH_H ) {

        # Like PUSH but where we don't care about the return value
        if ( exists $self->{$field} ) {
            my $h = $self->{$field};
            if ( ref($h) eq 'ARRAY' ) {
                push( @$h, ref($val) eq "ARRAY" ? @$val : $val );
            }
            else {
                $self->{$field} = [ $h, ref($val) eq "ARRAY" ? @$val : $val ];
            }
            return;
        }
        $self->{$field} = $val;
        return;
    }

    my $h = $self->{$field};
    my @old = ref($h) eq 'ARRAY' ? @$h : ( defined($h) ? ($h) : () );

    unless ( $op == $OP_GET || ( $op == $OP_INIT && @old ) ) {
        if ( defined($val) ) {
            my @new = ( $op == $OP_PUSH ) ? @old : ();
            if ( ref($val) ne 'ARRAY' ) {
                push( @new, $val );
            }
            else {
                push( @new, @$val );
            }
            $self->{$field} = @new > 1 ? \@new : $new[0];
        }
        elsif ( $op != $OP_PUSH ) {
            delete $self->{$field};
        }
    }
    @old;
}

sub _sorted_field_names {
    my $self = shift;
    return sort {
        ( $header_order{$a} || 999 ) <=> ( $header_order{$b} || 999 )
          || $a cmp $b
    } keys %$self;
}

sub header_field_names {
    my $self = shift;
    return map $standard_case{$_} || $_, $self->_sorted_field_names
      if wantarray;
    return keys %$self;
}

sub scan {
    my ( $self, $sub ) = @_;
    my @sorted = $self->_sorted_field_names;
    for my $key ( @sorted ) {
        next if index($key, '_') == 0;
        my $vals = $self->{$key};
        if ( ref($vals) eq 'ARRAY' ) {
            for my $val (@$vals) {
                $sub->( $standard_case{$key} || $key, $val );
            }
        }
        else {
            $sub->( $standard_case{$key} || $key, $vals );
        }
    }
}

sub as_string {
    my ( $self, $endl ) = @_;
    $endl = "\n" unless defined $endl;

    my @result = ();
    my $process_newline = sub {
        local $_ = shift;
        # must handle header values with embedded newlines with care
        s/\s+$//;        # trailing newlines and space must go
        s/\n\n+/\n/g;    # no empty lines
        s/\n([^\040\t])/\n $1/g; # intial space for continuation
        s/\n/$endl/g;    # substitute with requested line ending
        $_;
    };
    my @sorted = $self->_sorted_field_names;
    for my $key ( @sorted ) {
        next if index($key, '_') == 0;
        my $vals = $self->{$key};
        if ( ref($vals) eq 'ARRAY' ) {
            for my $val (@$vals) {
                my $field = $standard_case{$key} || $key;
                $field =~ s/^://;
                if ( index($val, "\n") >= 0 ) {
                    $val = $process_newline->($val);
                }
                push @result, $field . ': ' . $val;
            }
        } else {
            my $field = $standard_case{$key} || $key;
            $field =~ s/^://;
            if ( index($vals, "\n") >= 0 ) {
                $vals = $process_newline->($vals);
            }
            push @result, $field . ': ' . $vals;
        }
    }

    join( $endl, @result, '' );
}

if ( eval { require Storable; 1 } ) {
    *clone = \&Storable::dclone;
}
else {
    *clone = sub {
        my $self  = shift;
        my $clone = new HTTP::Headers::Fast;
        $self->scan( sub { $clone->push_header(@_); } );
        $clone;
    };
}

sub _date_header {
    require HTTP::Date;
    my ( $self, $header, $time ) = @_;
    my ($old) = $self->_header_get($header);
    if ( defined $time ) {
        $self->_header( $header, HTTP::Date::time2str($time) );
    }
    $old =~ s/;.*// if defined($old);
    HTTP::Date::str2time($old);
}

sub date                { shift->_date_header( 'Date',                @_ ); }
sub expires             { shift->_date_header( 'Expires',             @_ ); }
sub if_modified_since   { shift->_date_header( 'If-Modified-Since',   @_ ); }
sub if_unmodified_since { shift->_date_header( 'If-Unmodified-Since', @_ ); }
sub last_modified       { shift->_date_header( 'Last-Modified',       @_ ); }

# This is used as a private LWP extension.  The Client-Date header is
# added as a timestamp to a response when it has been received.
sub client_date { shift->_date_header( 'Client-Date', @_ ); }

# The retry_after field is dual format (can also be a expressed as
# number of seconds from now), so we don't provide an easy way to
# access it until we have know how both these interfaces can be
# addressed.  One possibility is to return a negative value for
# relative seconds and a positive value for epoch based time values.
#sub retry_after       { shift->_date_header('Retry-After',       @_); }

sub content_type {
    my $self = shift;
    my $ct   = $self->{'content-type'};
    $self->{'content-type'} = shift if @_;
    $ct = $ct->[0] if ref($ct) eq 'ARRAY';
    return '' unless defined($ct) && length($ct);
    my @ct = split( /;\s*/, $ct, 2 );
    for ( $ct[0] ) {
        s/\s+//g;
        $_ = lc($_);
    }
    wantarray ? @ct : $ct[0];
}

sub content_is_html {
    my $self = shift;
    return $self->content_type eq 'text/html' || $self->content_is_xhtml;
}

sub content_is_xhtml {
    my $ct = shift->content_type;
    return $ct eq "application/xhtml+xml"
      || $ct   eq "application/vnd.wap.xhtml+xml";
}

sub content_is_xml {
    my $ct = shift->content_type;
    return 1 if $ct eq "text/xml";
    return 1 if $ct eq "application/xml";
    return 1 if $ct =~ /\+xml$/;
    return 0;
}

sub referer {
    my $self = shift;
    if ( @_ && $_[0] =~ /#/ ) {

        # Strip fragment per RFC 2616, section 14.36.
        my $uri = shift;
        if ( ref($uri) ) {
            $uri = $uri->clone;
            $uri->fragment(undef);
        }
        else {
            $uri =~ s/\#.*//;
        }
        unshift @_, $uri;
    }
    ( $self->_header( 'Referer', @_ ) )[0];
}
*referrer = \&referer;    # on tchrist's request

for my $key (qw/content-length content-language content-encoding title user-agent server from warnings www-authenticate authorization proxy-authenticate proxy-authorization/) {
    no strict 'refs';
    (my $meth = $key) =~ s/-/_/g;
    *{$meth} = sub {
        my $self = shift;
        if (@_) {
            ( $self->_header( $key,   @_ ) )[0]
        } else {
            ( $self->_header_get($key) )[0];
        }
    };
}

sub authorization_basic { shift->_basic_auth( "Authorization", @_ ) }
sub proxy_authorization_basic {
    shift->_basic_auth( "Proxy-Authorization", @_ );
}

sub _basic_auth {
    require MIME::Base64;
    my ( $self, $h, $user, $passwd ) = @_;
    my ($old) = $self->_header($h);
    if ( defined $user ) {
        Carp::croak("Basic authorization user name can't contain ':'")
          if $user =~ /:/;
        $passwd = '' unless defined $passwd;
        $self->_header(
            $h => 'Basic ' . MIME::Base64::encode( "$user:$passwd", '' ) );
    }
    if ( defined $old && $old =~ s/^\s*Basic\s+// ) {
        my $val = MIME::Base64::decode($old);
        return $val unless wantarray;
        return split( /:/, $val, 2 );
    }
    return;
}

1;
__END__

=encoding utf8

=head1 NAME

HTTP::Headers::Fast -

=head1 SYNOPSIS

  use HTTP::Headers::Fast;

=head1 DESCRIPTION

HTTP::Headers::Fast is

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
