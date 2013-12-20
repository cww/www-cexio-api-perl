package Test::Constructor;

use common::sense;
use base 'Test::Class';

use Test::Most;

use WWW::CEXIO::API;

sub construct : Tests(1)
{
    my $api = WWW::CEXIO::API->new();
    ok(defined($api), 'object is defined');
}

1;
