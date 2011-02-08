#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use open qw(:std :utf8);
use lib qw(lib ../lib);

use Test::More tests    => 11;
use Encode qw(decode encode);
use Time::HiRes qw(time);
use AnyEvent;

BEGIN {
    # Подготовка объекта тестирования для работы с utf8
    my $builder = Test::More->builder;
    binmode $builder->output,         ":utf8";
    binmode $builder->failure_output, ":utf8";
    binmode $builder->todo_output,    ":utf8";

    use_ok 'AnyEvent::Tools', 'buffer';
}

{
    my @res;
    my $cv = condvar AnyEvent;
    my $number = 1;
    my $b = buffer
        size => 5,
        on_flush => sub { my ($g, $a) = @_; push @res, $a  };

    my $idle;
    $idle = AE::idle sub {
        $b->push($number++);
        if ($number > 100) {
            $b->flush;
            undef $idle;
            $cv->send;
        }
    };

    $cv->recv;

    ok @res == grep({@$_ == 5} @res), "Flush buffer after overflow";
}

{
    my @res;
    my $cv = condvar AnyEvent;
    my $number = 1;
    my $count = 0;
    my $start_time = time;
    my $idle;
    my $b = buffer
        interval => 0.5,
        on_flush => sub {
            my ($g, $a) = @_;
            push @res, { time => time, obj => $a };

            return if $count++ < 3;
            undef $idle;
            $cv->send;
        };

    $idle = AE::idle sub {  $b->push($number++); };

    $cv->recv;

    ok @res == 4, "Flush buffer after overflow";
    my @time = (0.45, .95, 1.45, 1.95, 2.45);
    for (0 .. 3) {
        my $delay = $res[$_]{time} - $start_time;
        my $count = @{ $res[$_]{obj} };
        ok $delay >= $time[$_], "$_ flush was in time (count: $count)";
        ok $delay <  $time[$_ + 1], "$_ flush was in time";
    }
}
