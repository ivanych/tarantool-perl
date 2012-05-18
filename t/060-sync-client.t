#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use open qw(:std :utf8);
use lib qw(lib ../lib);
use lib qw(blib/lib blib/arch ../blib/lib ../blib/arch);

use constant PLAN       => 15;
use Test::More tests    => PLAN;
use Encode qw(decode encode);


BEGIN {
    # Подготовка объекта тестирования для работы с utf8
    my $builder = Test::More->builder;
    binmode $builder->output,         ":utf8";
    binmode $builder->failure_output, ":utf8";
    binmode $builder->todo_output,    ":utf8";

    use_ok 'DR::Tarantool::LLClient', 'tnt_connect';
    use_ok 'DR::Tarantool::StartTest';
    use_ok 'DR::Tarantool', ':constant';
    use_ok 'File::Spec::Functions', 'catfile';
    use_ok 'File::Basename', 'dirname', 'basename';
    use_ok 'AnyEvent';
    use_ok 'DR::Tarantool::SyncClient';
}

my $cfg_dir = catfile dirname(__FILE__), 'test-data';
ok -d $cfg_dir, 'directory with test data';
my $tcfg = catfile $cfg_dir, 'llc-easy2.cfg';
ok -r $tcfg, $tcfg;

my $tnt = run DR::Tarantool::StartTest( cfg => $tcfg );

my $spaces = {
    0   => {
        name            => 'first_space',
        fields  => [
            {
                name    => 'id',
                type    => 'NUM',
            },
            {
                name    => 'name',
                type    => 'UTF8STR',
            },
            {
                name    => 'key',
                type    => 'NUM',
            },
            {
                name    => 'password',
                type    => 'STR',
            }
        ],
        indexes => {
            0   => 'id',
            1   => 'name',
            2   => [ 'key', 'password' ],
        },
    }
};

SKIP: {
    unless ($tnt->started and !$ENV{SKIP_TNT}) {
        diag $tnt->log unless $ENV{SKIP_TNT};
        skip "tarantool isn't started", PLAN - 9;
    }

    my $client = DR::Tarantool::SyncClient->connect(
        port    => $tnt->primary_port,
        spaces  => $spaces
    );

    isa_ok $client => 'DR::Tarantool::SyncClient';
    ok $client->ping, 'ping';

    my $t = $client->insert(
        first_space => [ 1, 'привет', 2, 'test' ], TNT_FLAG_RETURN
    );

    cmp_ok $t->id, '~~', 1, 'id';
    cmp_ok $t->name, '~~', 'привет', 'name';
    cmp_ok $t->key, '~~', 2, 'key';
    cmp_ok $t->password, '~~', 'test', 'password';


    for (my $no = 0; ; $no++) {
#         my $client = DR::Tarantool::SyncClient->connect(
#             port    => $tnt->primary_port,
#             spaces  => $spaces
#         );
        printf "$no: ping %s\n", $client->ping ? 'ok': 'fatal';
        my $t = $client->insert(
            first_space => [ 1, 'привет', 2, 'test' ], TNT_FLAG_RETURN
        );

        printf "$no: inserted %s\n", $t->iter->count;

        system sprintf "ls /proc/%d/fd", $tnt->tarantool_pid;

    }
}