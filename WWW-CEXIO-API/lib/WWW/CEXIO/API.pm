package WWW::CEXIO::API;

=head1 NAME

WWW::CEXIO::API - The great new WWW::CEXIO::API!

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use WWW::CEXIO::API;

    my $api = WWW::CEXIO::API->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=cut

our $VERSION = '0.01';

use common::sense;

use Moose;

use Carp;
use JSON;
use LWP::UserAgent;

# Number of calls allowed ...
use constant RESTRICT_CALL_NUM => 600;
# ... in this number of seconds.
use constant RESTRICT_CALL_INTERVAL => 10 * 60;

use constant DEFAULT_TIMEOUT => 10;
use constant API_BASE => 'https://cex.io/api/';

sub BUILD
{
    my ($self, $args_ref) = @_;

    $self->{_ua} = LWP::UserAgent->new
    (
        agent   => "www-cexio-api-perl/$VERSION",
        timeout => $self->timeout(),
    );
    $self->{_json} = JSON->new();
    $self->{_nonce} = 0;
}

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

=head1 SUBROUTINES/METHODS

=head2 function1

=cut

sub get_ticker
{
    my ($self, $currencies) = @_;
    confess 'Currency pair must be defined' unless defined $currencies;
    confess 'Currency pair must contain a slash' unless $currencies =~ m|/|;
    my $action = "ticker/$currencies";
    return $self->_get_url($action);
}

=head2 function2

=cut

sub get_order_book
{
    my ($self, $currencies) = @_;
    confess 'Currency pair must be defined' unless defined $currencies;
    confess 'Currency pair must contain a slash' unless $currencies =~ m|/|;
    my $action = "order_book/$currencies";
    return $self->_get_url($action);
}

# Perform an HTTP GET request against the specified URL (API_BASE concatenated
# with $action) and return the decoded JSON as a Perl data structure.  Return
# undef if something goes wrong.
sub _get_url
{
    my ($self, $action) = @_;
    confess 'Action must be defined' unless $action;
    my $url = API_BASE . $action;
    my $resp = $self->{_ua}->get($url);
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

Copyright 2013 Colin Wetherbee.

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
