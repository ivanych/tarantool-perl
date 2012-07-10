#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use open qw(:std :utf8);
use lib qw(lib ../lib);

use Test::More tests    => 42;
use Encode qw(decode encode);


BEGIN {
    # Подготовка объекта тестирования для работы с utf8
    my $builder = Test::More->builder;
    binmode $builder->output,         ":utf8";
    binmode $builder->failure_output, ":utf8";
    binmode $builder->todo_output,    ":utf8";

    use_ok 'DR::Tarantool::Iterator';
}

use constant MODEL => 'DR::Tarantool::Iterator';

is eval { MODEL->new }, undef, 'empty constructor';
like $@, qr{usage:}, 'error message';

my $iter = MODEL->new([1, 2, 3]);
ok $iter, 'constructor';
isa_ok $iter => MODEL;
is $iter->count, 3, '$iter->count';

is $iter->item(0), 1, '$iter->item(0)';
is $iter->item(1), 2, '$iter->item(1)';
is $iter->item(2), 3, '$iter->item(2)';

is $iter->item(-1), 3, '$iter->item(-1)';
is $iter->item(-2), 2, '$iter->item(-2)';
is $iter->item(-3), 1, '$iter->item(-3)';

is eval { $iter->item(3) }, undef, '$iter->item(3) (out of bound)';
like $@, qr{wrong item number: 3}, 'error message';
is eval { $iter->item(-4) }, undef, '$iter->item(-4) (out of bound)';
like $@, qr{wrong item number: -4}, 'error message';
is eval { $iter->item('abc') }, undef, '$iter->item("abc")';
like $@, qr{wrong item number format: abc}, 'error message';
is eval { $iter->item(undef) }, undef, '$iter->item(undef)';
like $@, qr{wrong item number format: undef}, 'error message';

my @res;
while(my $o = $iter->next) { push @res => $o }
is_deeply \@res, [ 1, 2, 3 ], '$iter->next';

is $iter->next, 1, '$iter->next (first)';
is $iter->reset, 0, '$iter->reset returns old iterator position';

@res = ();
while(my $o = $iter->next) { push @res => $o }
is_deeply \@res, [ 1, 2, 3 ], '$iter->next';

$iter->reset;
is_deeply scalar $iter->all, [ 1, 2, 3 ], '$iter->all';
$iter->next;
is_deeply scalar $iter->all, [ 1, 2, 3 ], '$iter->all (after next)';

@res = ();
while(my $o = $iter->next) { push @res => $o }
is_deeply \@res, [ 2, 3 ], '$iter->next after $iter->all';

is_deeply scalar $iter->all(sub { $_[0] + 1 }), [ 2, 3, 4 ],
    '$iter->all(sub { .. })';

is_deeply scalar $iter->all(sub { $_[0] + 1 }, sub { $_[0] + 2 }),
    [ [ 2, 3 ], [ 3, 4 ],  [ 4, 5 ] ],
    '$iter->all(sub { ... }, sub { ... })';

$iter->item_class('Test::Iterator::Class');
$iter->item_constructor('constructor');

my $item = $iter->item(2);
isa_ok $item => 'Test::Iterator::Class';
is eval { $item->value }, 3, '$item->value';

$iter->reset;
$iter->item_constructor(undef);
$item = $iter->next;
isa_ok $item => 'Test::Iterator::Class';
is $$item, 1, 'blessed (not constructed)';

$item = $iter->next;
isa_ok $item => 'Test::Iterator::Class';
is $$item, 2, 'blessed (not constructed)';

$iter->item_class(undef);
$item = $iter->next;
is $item, 3, 'unblessed item';


$iter = MODEL->new([3, 4, 5],
    item_class => [ 'Test::Iterator::Class', 'constructor' ]
);

isa_ok $iter->next, 'Test::Iterator::Class';
is eval { $iter->next->value }, 4, '$iter->item(1)->value';

$iter = MODEL->new([ 5, 6, 7 ],
    item_class => 'Test::Iterator::Class',
    item_constructor => 'constructor'
);

isa_ok $iter->next, 'Test::Iterator::Class';
is eval { $iter->next->value }, 6, '$iter->item(1)->value';

$iter = MODEL->new([ 8, 9, 10 ], item_class => 'Test::Iterator::Class');
isa_ok $iter->next, 'Test::Iterator::Class';
is eval { ${ $iter->next } }, 9, '$iter->item(1) usually blessed';


package Test::Iterator::Class;
use Test::More;

sub constructor {
    my ($class, $v) = @_;
    return bless { value => $v } => ref($class) || $class;
}

sub value {
    my ($self) = @_;
    return $self->{value};
}
