package WWW::CEXIO::API;

=head1 NAME

WWW::CEXIO::API - Client implementation of the API exposed by cex.io.

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

    use WWW::CEXIO::API;

    my $api = WWW::CEXIO::API->new();
    # Available symbols are:
    # GHS/BTC NMC/BTC GHS/NMC
    my $ticker = $api->get_ticker('GHS/BTC');
    my $order_book = $api->get_order_book('GHS/BTC');

    # Public API calls may be accessed with a private-enabled object, too.
    my $priv_api = WWW::CEXIO::API->new
    ({
        api_key    => 'foo',
        api_secret => 'bar',
        username   => 'baz',
    });
    my $acct_balance = $priv_api->get_account_balance();

=head1 DESCRIPTION

    This module exposes the cex.io API.  For the sake of speed, no returned
    objects are encapsulated; they are simply Perl array refs or hash refs
    representing the JSON returned by the API call.

    For more information about the API, please see L<https://cex.io/api>.

=cut

our $VERSION = '0.01';

use common::sense;

use Moose;

use Carp;
use Digest::SHA;
use JSON;
use LWP::UserAgent;

# Number of calls allowed ...
use constant RESTRICT_CALL_NUM => 600;
# ... in this number of seconds.
use constant RESTRICT_CALL_INTERVAL => 10 * 60;

use constant DEFAULT_TIMEOUT => 10;
use constant API_BASE => 'https://cex.io/api/';

has 'force_restrict' =>
(
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

has 'timeout' =>
(
    is      => 'ro',
    isa     => 'Int',
    default => DEFAULT_TIMEOUT,
);

has 'api_key' =>
(
    is       => 'ro',
    isa      => 'Str',
    required => 0,
);

has 'api_secret' =>
(
    is       => 'ro',
    isa      => 'Str',
    required => 0,
);

has 'username' =>
(
    is       => 'ro',
    isa      => 'Str',
    required => 0,
);

has 'nonce_start' =>
(
    is       => 'ro',
    isa      => 'Int',
    required => 0,
);

sub BUILD
{
    my ($self, $args_ref) = @_;

    $self->{_ua} = LWP::UserAgent->new
    (
        agent   => "www-cexio-api-perl/$VERSION",
        timeout => $self->timeout(),
    );
    $self->{_json} = JSON->new();
    $self->{_nonce} = $self->nonce_start() // time();
}

=head1 METHODS

=head2 get_ticker($currencies)

Get the current ticker data for the specified currency pair.

=cut

sub get_ticker
{
    my ($self, $currencies) = @_;
    __validate_currency_pair($currencies);
    my $action = "ticker/$currencies";
    return $self->_get_url($action);
}

=head2 get_order_book($currencies)

Get the current order book for the specified currency pair.

=cut

sub get_order_book
{
    my ($self, $currencies) = @_;
    __validate_currency_pair($currencies);
    my $action = "order_book/$currencies";
    return $self->_get_url($action);
}

=head2 get_account_balance

Get the account balance for the account specified by the api_key, api_secret,
and username constructor parameters.

The returned hash ref will contain the following keys.

NMC, DVC, IXC, LTC, BTC, GHS:

=over

    The values for each of these keys is a hash ref, always with an
    "available" key and also with an "orders" key if the
    corresponding currency/commodity is tradeable on cex.io.  The values for
    these keys are floating-point numbers representing the user's balance in
    the respective category.

=back

username:

=over

    The username of the account.

=back

timestamp:

=over

    The timestamp (integer seconds since the epoch) of the API response.

=back

=cut

sub get_account_balance
{
    my ($self) = @_;
    my $action = 'balance/';
    return $self->_get_private_url($action);
}

=head2 get_open_orders($currencies)

Get the current open orders for the specified currency pair and for the
account specified by the api_key, api_secret, and username constructor
parameters.

The returned value is an array ref.  If the account has no open orders, the
array ref will be defined but empty.  If the account has open orders, each
will be represented by a hash ref with the following keys.

type:

=over

"buy" or "sell"

=back

price:

=over

The limit price for the order.

=back

id:

=over

The order ID

=back

pending:

=over

The number of items in the order that still need to be executed.

=back

amount:

=over

The total number of items in the order.

=back

time:

=over

The timestamp of the order, in integer milliseconds since the epoch.

=back

=cut

sub get_open_orders
{
    my ($self, $currencies) = @_;
    __validate_currency_pair($currencies);
    my $action = "open_orders/$currencies";
    return $self->_get_private_url($action);
}

=head2 cancel_order($order_id)

Cancel the order with the specified order ID.  The order ID should be the
value corresponding to the "id" key in the hash ref returned by place_order().

The returned value will evaluate to true if the order was canceled
successfully.

Even though this method returns a boolean value (actually a JSON::XS::Boolean
if your Perl installation uses JSON::XS) on success, it still returns a hash
ref with an error message on failure (e.g. if you provide an order ID that
your account doesn't own).  See the ERRORS section of this document for
more information.

=cut
sub cancel_order
{
    my ($self, $order_id) = @_;

    confess 'must provide order ID' unless defined $order_id;

    my $action = 'cancel_order/';
    return $self->_get_private_url
    (
        $action,
        id => $order_id,
    );
}

=head2 place_order($currencies, $type, $amount, $price)

Place an order on the exchange for the specified currency pair, of the
specified type, amount, and price.  The $type value must be either 'buy' or
'sell'.

The returned value is a hash ref with the following keys.

id:

=over

the order's order ID, which seems to always be an integer

=back

time:

=over

the timestamp, in integer milliseconds since the epoch, at which the order
was placed

=back

type:

=over

"buy" or "sell"

=back

price:

=over

the price at which the order was placed

=back

amount:

=over

the amount of the currency pair to trade in this order

=back

pending:

=over

the amount of currency still pending execution; i.e. the amount of currency
that could not be traded immediately upon order placement

=back

=cut
sub place_order
{
    my ($self, $currencies, $type, $amount, $price) = @_;

    __validate_currency_pair($currencies);
    confess 'must provide order type' unless defined $type;
    confess q{type must be 'buy' or 'sell'} unless
        $type eq 'buy' || $type eq 'sell';
    confess 'must specify amount' unless defined $amount;
    confess 'must specify price' unless defined $price;

    my $action = "place_order/$currencies";
    return $self->_get_private_url
    (
        $action,
        type   => $type,
        amount => $amount,
        price  => $price,
    );
}

# Generate a new nonce.  It is guaranteed to be different from any other nonce
# generated by this object, but it is not guaranteed to be unique across
# multiple instances of this module.
sub _generate_nonce
{
    my ($self) = @_;
    return $self->{_nonce}++;
}

# Generate a private API call signature.  Returns a hash ref containing
# "signature" and "nonce".
sub _generate_signature
{
    my ($self) = @_;

    confess 'must provide username' unless $self->username();
    confess 'must provide api_key' unless $self->api_key();
    confess 'must provide api_secret' unless $self->api_secret();

    my $nonce = $self->_generate_nonce();
    my $message = $nonce  . $self->username() . $self->api_key();

    return
    {
        signature => uc(Digest::SHA::hmac_sha256_hex($message,
                                                     $self->api_secret())),
        nonce => $nonce,
    };
}

# Perform an HTTP POST request against the specified URL (API_BASE
# concatenanted with $action) and return the decoded JSON as a Perl data
# structure.  Return undef if something goes wrong.
#
# Additional form parameters may be specified in the %extra hash.
sub _get_private_url
{
    my ($self, $action, %extra) = @_;
    my $sig = $self->_generate_signature();
    my %form =
    (
        key       => $self->api_key(),
        signature => $sig->{signature},
        nonce     => $sig->{nonce},
        %extra,
    );
    return $self->_get_url($action, 'post', \%form);
}

# Perform an HTTP GET request against the specified URL (API_BASE concatenated
# with $action) and return the decoded JSON as a Perl data structure.  Return
# undef if something goes wrong.
sub _get_url
{
    my ($self, $action, $verb, $form_ref) = @_;
    confess 'Action must be defined' unless $action;
    $verb //= 'get';
    $verb = lc($verb);
    my $url = API_BASE . $action;
    my $resp = $form_ref ?
               $self->{_ua}->$verb($url, $form_ref) :
               $self->{_ua}->$verb($url);
    my $ret;
    if ($resp->is_success())
    {
        my $text = $resp->decoded_content();
        eval
        {
            $ret = $self->{_json}->decode($text);
        };
        if ($@)
        {
            carp "Unable to parse JSON: $@";
        }
    }
    else
    {
        carp "Unable to retrieve URL '$url': " . $resp->status_line();
    }

    return $ret;
}

sub __validate_currency_pair
{
    my ($cur_pair) = @_;
    confess 'Currency pair must be defined' unless defined $cur_pair;
    confess 'Currency pair must contain a slash' unless $cur_pair =~ m|/|;
}

=head1 ERRORS

The API documentation provided by cex.io is poor at best.  I've gathered
that, if an error occurs on the server side (as a result of, for example, an
invalid or incorrect parameter being passed to an API call), then the
resulting API call return value (a hash ref) will contain a single key
named "error" with a value containing a string message that describes the
error.

=head1 LIMITATIONS

cex.io does not provide any service guarantees, SLAs, or even any inkling that
the API won't disappear entirely at any moment.  Indeed, 'sell' could mean
'buy' tomorrow, and we users would be none the wiser.  I don't personally
recommend using this module or any other functionality related to cex.io with
any currency that you actually care about keeping.

(That said, I think cex.io is a great service, and the people running it have
been pretty good about communication for as long as I've been using it.  Have
fun and make some money!)

=head1 AUTHOR

Colin Wetherbee, C<< <cww at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-cexio-api at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-CEXIO-API>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::CEXIO::API

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-CEXIO-API>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-CEXIO-API>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-CEXIO-API>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-CEXIO-API/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2013, 2014 Colin Wetherbee.

This program is distributed under the MIT (X11) License:
L<http://www.opensource.org/licenses/mit-license.php>

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

=cut

no Moose;
__PACKAGE__->meta->make_immutable;

1;
