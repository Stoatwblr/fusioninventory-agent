#!/usr/bin/perl

use strict;
use warnings;
use lib 't/lib';

use English qw(-no_match_vars);
use List::Util qw(first);
use Test::Deep;
use Test::More;

use FusionInventory::Agent::Task::Deploy::P2P;
use FusionInventory::Test::Server;
use FusionInventory::Test::Utils;

my @tests = (
    {
        name    => 'Ignore',
        address => { ip  => '127.0.0.1', mask => '255.0.0.0' },
        result  => [ ]
    },
    {
        name    => 'Ignore-Large-Range',
        address => { ip  => '10.0.0.10', mask => '255.0.0.0' },
        result  => [ ]
    },
    {
        name    => '192.168.5.5',
        address => { ip => '192.168.5.5', mask => '255.255.255.0' },
        result  => [
          '192.168.5.2',
          '192.168.5.3',
          '192.168.5.4',
          '192.168.5.6',
          '192.168.5.7',
          '192.168.5.8'
        ]
    },
    {
        name    => '10.5.6.200',
        address => { ip => '10.5.6.200', mask => '255.255.252.0' },
        result  => [
          '10.5.6.197',
          '10.5.6.198',
          '10.5.6.199',
          '10.5.6.201',
          '10.5.6.202',
          '10.5.6.203'
        ]
    },
    {
        name    => '192.168.1.2/24',
        address => { ip => '192.168.1.2', mask => '255.255.255.0' },
        result  => [
          '192.168.1.0',
          '192.168.1.1',
          '192.168.1.3',
          '192.168.1.4',
          '192.168.1.5',
          '192.168.1.6'
        ]
    },
    {
        name    => '192.168.2.254/24',
        address => { ip => '192.168.2.254', mask => '255.255.255.0' },
        result  => [
          '192.168.2.249',
          '192.168.2.250',
          '192.168.2.251',
          '192.168.2.252',
          '192.168.2.253',
          '192.168.2.255'
        ]
    },
    {
        name    => '192.168.3.1/22',
        address => { ip => '192.168.3.1', mask => '255.255.252.0' },
        result  => [
          '192.168.2.254',
          '192.168.2.255',
          '192.168.3.0',
          '192.168.3.2',
          '192.168.3.3',
          '192.168.3.4'
        ]
    },
    {
        name    => '192.168.4.254/22',
        address => { ip => '192.168.4.254', mask => '255.255.252.0' },
        result  => [
          '192.168.4.251',
          '192.168.4.252',
          '192.168.4.253',
          '192.168.4.255',
          '192.168.5.0',
          '192.168.5.1'
        ]
    },
);

my %find_tests = (
    "Expecting one peer" => {
        addresses      => [ '127.0.0.1','127.0.0.2','127.0.0.3','127.0.0.4' ],
        expected_peers => 1
    },
    "Expecting no peer" => {
        port => 62000,
        addresses => [ '127.0.0.1','127.0.0.2','127.0.0.3','127.0.0.4' ],
        expected_peers => 0
    },
);

plan tests => scalar @tests + keys(%find_tests);

my $p2p = FusionInventory::Agent::Task::Deploy::P2P->new();

foreach my $test (@tests) {
    my @peers = $p2p->_getPotentialPeers($test->{address}, 6);
    cmp_deeply(\@peers, $test->{result}, $test->{name});
}

# find an available port on loopback
my $port = first { test_port($_) } 62354 .. 62400;

my $server = FusionInventory::Test::Server->new(
    port     => $port,
);
eval {
    $server->background();
};
BAIL_OUT("can't launch a default server: $EVAL_ERROR") if $EVAL_ERROR;

foreach my $test (keys(%find_tests)) {
    my @found = $p2p->_scanPeers(
        $find_tests{$test}->{port} || $port,
        @{$find_tests{$test}->{addresses}}
    );
    ok( scalar(@found) == $find_tests{$test}->{expected_peers}, $test )
}

$server->stop();
