#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use open qw(:std :utf8);
use lib qw(lib ../lib);

use Test::More tests    => 5;
use Time::HiRes qw(time);
use Encode qw(decode encode);
use AnyEvent;

BEGIN {
    my $builder = Test::More->builder;
    binmode $builder->output,         ":utf8";
    binmode $builder->failure_output, ":utf8";
    binmode $builder->todo_output,    ":utf8";


    use_ok 'AnyEvent::Tools', 'pool';
}

{
    my $cv = condvar AnyEvent;
    my $pool = pool qw( a b );
    my $order = 0;
    my @res;


    for (0 .. 8) {
        $pool->get(sub {
            my ($guard, $object) = @_;
            my $timer;
            $timer = AE::timer 0.5, 0 => sub {
                push @res, { obj => $object, time => time, order => $order++ };
                undef $timer;
                undef $guard;
                $cv->send if @res == 9;
            };
        });
    }

    my $t;
    $t = AE::timer 0.2, 0 => sub {
        $pool->push('c');
        undef $t;
    };



    $cv->recv;

    my $ok = 1;

    for (0 .. 2) {
        my $idx = $_ * 3;

        $ok = 0 unless $res[$idx + 1]{time} - $res[$idx]{time} < 0.1;
        $ok = 0 unless $res[$idx + 2]{time} - $res[$idx + 1]{time} >= 0.2;

        next if $_ == 2;
        $ok = 0 unless $res[$idx + 3]{time} - $res[$idx + 2]{time} >= 0.3;
    }

    ok $ok, "Pool works fine";

    my @a = qw(a b c);

    $ok = 1;
    for (@res) {
        my $c = shift @a;
        $ok = 0 unless $c eq $_->{obj};
        push @a, $c;
    }

    ok $ok, "Sequence order is right";
}

{
    my $cv = condvar AnyEvent;
    my $pool = pool qw( a b );
    my $order = 0;
    my @res;

    my $ano = $pool->push('c');
    my $t;
    $t = AE::timer 0.7, 0 => sub {
        $pool->delete($ano);
        undef $t;
    };

    for (0 .. 10) {
        $pool->get(sub {
            my ($guard, $object) = @_;
            my $timer;
            $timer = AE::timer 0.5, 0 => sub {
                push @res, { obj => $object, time => time, order => $order++ };
                undef $timer;
                undef $guard;
                $cv->send if @res == 11;
            };
        });
    }


    $cv->recv;

    ok 2 == grep({ $_->{obj} eq 'c' } @res), "delete method works fine";
    my ($f, $s) = grep { $_->{obj} eq 'c' } @res;

    ok $s->{time} - $f->{time} >= 0.5, "Sequence order is right";
}
