package App::wordlist;

our $DATE = '2014-12-18'; # DATE
our $VERSION = '0.07'; # VERSION

use 5.010001;
use strict;
use warnings;

our %SPEC;

sub _list_installed {
    require Module::List;
    my $mods = Module::List::list_modules(
        "Games::Word::Wordlist::",
        {
            list_modules  => 1,
            list_pod      => 0,
            recurse       => 1,
        });
    my $modsp = Module::List::list_modules(
        "Games::Word::Phraselist::",
        {
            list_modules  => 1,
            list_pod      => 0,
            recurse       => 1,
        });
    my $res = {}; # key=name, val=full module name
    for my $fullname (keys %$mods, keys(%$modsp)) {
        (my $shortname = $fullname) =~ s/^Games::Word::\w+list:://;
        if ($res->{$shortname}) {
            ($shortname = $fullname) =~ s/^Games::Word:://;
        }
        $res->{$shortname} = $fullname;
    }
    $res;
}

$SPEC{wordlist} = {
    v => 1.1,
    summary => 'Grep words from Games::Word::{Wordlist,Phraselist}::*',
    args => {
        arg => {
            schema => ['array*' => of => 'str*'],
            pos => 0,
            greedy => 1,
        },
        ignore_case => {
            schema  => 'bool',
            default => 1,
        },
        len => {
            schema  => 'int*',
        },
        min_len => {
            schema  => 'int*',
        },
        max_len => {
            schema  => 'int*',
        },
        wordlist => {
            schema => ['array*' => of => 'str*'],
            summary => 'Select one or more wordlist modules',
            cmdline_aliases => {w=>{}},
            element_completion => sub {
                require Complete::Util;

                my %args = @_;
                Complete::Util::complete_array_elem(
                    word  => $args{word},
                    array => [sort keys %{ _list_installed() }],
                    ci    => 1,
                );
            },
        },
        or => {
            summary => 'Use OR logic instead of the default AND',
            schema  => 'bool',
        },
        action => {
            schema  => ['str*', in=>[
                'list_cpan', 'list_installed', 'install', 'uninstall',
                'grep',
            ]],
            default => 'grep',
            cmdline_aliases => {
                l => {
                    summary=>'List installed Games::Word::Wordlist::* modules',
                    is_flag => 1,
                    code => sub { my $args=shift; $args->{action} = 'list_installed' },
                },
                L => {
                    summary=>'List Games::Word::Wordlist::* modules on CPAN',
                    is_flag => 1,
                    code => sub { my $args=shift; $args->{action} = 'list_cpan' },
                },
                I => {
                    summary=>'Install Games::Word::Wordlist::* module',
                    code => sub { my $args=shift; $args->{action} = 'install' },
                },
                U => {
                    summary=>'Uninstall Games::Word::Wordlist::* module',
                    code => sub { my $args=shift; $args->{action} = 'uninstall' },
                },
            },
        },
        detail => {
            summary => 'Display more information when listing modules',
            schema  => 'bool',
        },
    },
    examples => [
        {
            argv => [],
            summary => 'By default print all words from all wordlists',
        },
        {
            argv => [qw/foo bar/],
            summary => 'Print all words matching /foo/ and /bar/',
        },
        {
            argv => [qw/--or foo bar/],
            summary => 'Print all words matching /foo/ or /bar/',
        },
        {
            argv => [qw/-w KBBI foo/],
            summary => 'Select a specific wordlist (multiple -w allowed)',
        },
        {
            argv => [qw|/fof[aeiou]/|],
            summary => 'Filter by regex',
        },
    ],
    'cmdline.default_format' => 'text-simple',
};
sub wordlist {
    my %args = @_;

    my $action = $args{action} // 'grep';
    my $list_installed = _list_installed();
    my $ci = $args{ignore_case} // 1;
    my $or = $args{or};
    my $arg = $args{arg} // [];

    if ($action eq 'grep') {

        # convert /.../ in arg to regex
        for (@$arg) {
            if (m!\A/(.*)/\z!) {
                $_ = $ci ? qr/$1/i : qr/$1/;
            } else {
                $_ = lc($_) if $ci;
            }
        }

        my @res;
        my $wordlists = $args{wordlist};
        if (!$wordlists || !@$wordlists) {
            $wordlists = [sort keys %$list_installed];
        }
        for my $wl (@$wordlists) {
            my $mod = $list_installed->{$wl} or
                return [400, "Unknown wordlist '$wl', see 'wordlist -l' ".
                            "for list of installed wordlists"];
            (my $modpm = $mod . ".pm") =~ s!::!/!g;
            require $modpm;
            my $obj = $mod->new;
            $obj->each_word(
                sub {
                    my $word = shift;

                    return if defined($args{len}) &&
                        length($word) != $args{len};
                    return if defined($args{min_len}) &&
                        length($word) < $args{min_len};
                    return if defined($args{max_len}) &&
                        length($word) > $args{max_len};

                    my $cmpword = $ci ? lc($word) : $word;
                    for (@$arg) {
                        my $match =
                            ref($_) eq 'Regexp' ? $cmpword =~ $_ :
                                index($cmpword, $_) >= 0;
                        if ($or) {
                            # succeed early when --or
                            if ($match) {
                                push @res, $word;
                                return;
                            }
                        } else {
                            # fail early when and (the default)
                            if (!$match) {
                                return;
                            }
                        }
                    }
                    if (!$or || !@$arg) {
                        push @res, $word;
                    }
                }
            );
        }
        [200, "OK", \@res];

    } elsif ($action eq 'list_installed') {

        my @res;
        for (sort keys %$list_installed) {
            if ($args{detail}) {
                push @res, {
                    name   => $_,
                    module => $list_installed->{$_},
                };
            } else {
                push @res, $_;
            }
        }
        [200, "OK", \@res,
         {('cmdline.default_format' => 'text') x !!$args{detail}}];

    } elsif ($action eq 'list_cpan') {

        [501, "Not yet implemented"];

    } elsif ($action eq 'install') {

        [501, "Not yet implemented"];

    } elsif ($action eq 'uninstall') {

        [501, "Not yet implemented"];

    } else {

        [400, "Unknown action '$action'"];

    }
}

1;
# ABSTRACT: Grep words from Games::Word::{Wordlist,Phraselist}::*

__END__

=pod

=encoding UTF-8

=head1 NAME

App::wordlist - Grep words from Games::Word::{Wordlist,Phraselist}::*

=head1 VERSION

This document describes version 0.07 of App::wordlist (from Perl distribution App-wordlist), released on 2014-12-18.

=head1 SYNOPSIS

See the included script L<wordlist>.

=head1 FUNCTIONS


=head2 wordlist(%args) -> [status, msg, result, meta]

Grep words from Games::Word::{Wordlist,Phraselist}::*.

Examples:

 wordlist();


By default print all words from all wordlists.


 wordlist( arg => ["foo", "bar"]);


Print all words matching /foo/ and /bar/.


 wordlist( arg => ["foo", "bar"], or => 1);


Print all words matching /foo/ or /bar/.


 wordlist( arg => ["foo"], wordlist => ["KBBI"]);


Select a specific wordlist (multiple -w allowed).


 wordlist( arg => ["'/fof[aeiou]/'"]);


Filter by regex.


Arguments ('*' denotes required arguments):

=over 4

=item * B<action> => I<str> (default: "grep")

=item * B<arg> => I<array>

=item * B<detail> => I<bool>

Display more information when listing modules.

=item * B<ignore_case> => I<bool> (default: 1)

=item * B<len> => I<int>

=item * B<max_len> => I<int>

=item * B<min_len> => I<int>

=item * B<or> => I<bool>

Use OR logic instead of the default AND.

=item * B<wordlist> => I<array>

Select one or more wordlist modules.

=back

Return value:

Returns an enveloped result (an array).

First element (status) is an integer containing HTTP status code
(200 means OK, 4xx caller error, 5xx function error). Second element
(msg) is a string containing error message, or 'OK' if status is
200. Third element (result) is optional, the actual result. Fourth
element (meta) is called result metadata and is optional, a hash
that contains extra information.

 (any)

=head1 TODO

In -l --detail, show summary (extract from POD Name or # ABSTRACT).

Option --random (plus -n) to generate (or n) random word(s).

Option -v (--invert-match) like grep.

Implement -n (max result).

=head1 SEE ALSO

L<Games::Word::Wordlist>

L<Games::Word::Phraselist>

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/App-wordlist>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-App-wordlist>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=App-wordlist>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
