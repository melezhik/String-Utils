# Since this distribution is about providing optimized functionality
# that can also be achieved by e.g. using regular expressions, it was decided
# to use NQP in here.  All of these subroutines could easily be rewritten
# in pure Raku if necessary, should that be needed for Raku implementations
# that are not based on NQP.
use nqp;

my sub between(str $string, str $before, str $after) {
    nqp::if(
      nqp::iseq_i((my int $left = nqp::index($string,$before)),-1),
      Nil,
      nqp::if(
        nqp::iseq_i(
          (my int $right = nqp::index(
            $string,$after,(my $offset = nqp::add_i($left,nqp::chars($before)))
          )),
          -1
        ),
        Nil,
        nqp::substr($string,$offset,nqp::sub_i($right,$offset))
      )
    )
}

my sub between-included(str $string, str $before, str $after) {
    nqp::if(
      nqp::iseq_i((my int $left = nqp::index($string,$before)),-1),
      Nil,
      nqp::if(
        nqp::iseq_i(
          (my int $right = nqp::index(
            $string,$after,nqp::add_i($left,nqp::chars($before))
          )),
          -1
        ),
        Nil,
        nqp::substr(
          $string,
          $left,
          nqp::sub_i(nqp::add_i($right,nqp::chars($after)),$left)
        )
      )
    )
}

my sub around(str $string, str $before, str $after) {
    nqp::if(
      nqp::iseq_i((my int $left = nqp::index($string,$before)),-1),
      $string,
      nqp::if(
        nqp::iseq_i(
          (my int $right = nqp::index(
            $string,$after,nqp::add_i($left,nqp::chars($before))
          )),
          -1
        ),
        $string,
        nqp::concat(
          nqp::substr($string,0,$left),
          nqp::substr($string,nqp::add_i($right,nqp::chars($after)))
        )
      )
    )
}

my sub before(str $string, str $before) {
    nqp::iseq_i((my int $left = nqp::index($string,$before)),-1)
      ?? Nil
      !! nqp::substr($string,0,$left)
}

my sub after(str $string, str $after) {
    nqp::iseq_i((my int $right = nqp::index($string,$after)),-1)
      ?? Nil
      !! nqp::substr($string,nqp::add_i($right,nqp::chars($after)))
}

my sub root(*@s) {
    if @s > 1 {
        my str $base = @s.shift.Str;
        my $same := nqp::clone(nqp::strtocodes(  # MUST be a clone
          $base,nqp::const::NORMALIZE_NFC,nqp::create(array[uint32])
        ));
        my int $elems = nqp::elems($same);
        my $next := nqp::create(array[uint32]);

        nqp::while(
          $elems && @s,
          nqp::stmts(
            nqp::strtocodes(@s.shift.Str,nqp::const::NORMALIZE_NFC,$next),
            (my int $i = -1),
            nqp::while(
              nqp::islt_i(++$i,$elems),
              nqp::if(
                nqp::isne_i(nqp::atpos_i($same,$i),nqp::atpos_i($next,$i)),
                nqp::setelems($same, $elems = $i)
              )
            )
          )
        );

        nqp::substr($base, 0, $elems)
    }
    else {
        @s.head // ""
    }
}

my sub leaf(*@s) {
    if @s > 1 {
        my str $base = nqp::flip(@s.shift.Str);
        my $same := nqp::clone(nqp::strtocodes(  # MUST be a clone
          $base,nqp::const::NORMALIZE_NFC,nqp::create(array[uint32])
        ));
        my int $elems = nqp::elems($same);
        my $next := nqp::create(array[uint32]);

        nqp::while(
          $elems && @s,
          nqp::stmts(
            nqp::strtocodes(
              nqp::flip(@s.shift.Str),nqp::const::NORMALIZE_NFC,$next
            ),
            (my int $i = -1),
            nqp::while(
              nqp::islt_i(++$i,$elems),
              nqp::if(
                nqp::isne_i(nqp::atpos_i($same,$i),nqp::atpos_i($next,$i)),
                nqp::setelems($same, $elems = $i)
              )
            )
          )
        );

        nqp::flip(nqp::substr($base, 0, $elems))
    }
    else {
        @s.head // ""
    }
}

my sub chomp-needle(str $haystack, str $needle) {
    my int $offset = nqp::sub_i(nqp::chars($haystack),nqp::chars($needle));
    nqp::eqat($haystack,$needle,$offset)
      ?? nqp::substr($haystack,0,$offset)
      !! $haystack
}

my sub is-sha1(str $needle) {
    my int $i = -1;
    if nqp::chars($needle) == 40 {
        my $map := BEGIN {
            my int @map;
            @map[.ord] = 1 for "0123456789ABCDEF".comb;
            @map;
        }

        nqp::while(
          nqp::isle_i(++$i,40)
            && nqp::atpos_i($map,nqp::ordat($needle,$i)),
          nqp::null
        )
    }

    nqp::hllbool(nqp::iseq_i($i,41))
}

my sub stem(str $basename, $parts = *) {
    (my @indices := indices($basename, '.'))
      ?? nqp::substr(
           $basename,
           0,
           nqp::istype($parts,Whatever) || $parts > @indices
            ?? @indices[0]
            !! @indices[@indices - $parts]
         )
      !! $basename
}

my sub EXPORT(*@names) {
    Map.new: UNIT::{@names
      ?? @names.map: { '&' ~ $_ }
      !! UNIT::.keys.grep({
             .starts-with('&') && $_ ne '&EXPORT'
         })
    }:p
}

=begin pod

=head1 NAME

String::Utils - Provide some optimized string functions

=head1 SYNOPSIS

=begin code :lang<raku>

use String::Utils;

say before("foobar","bar");            # foo

say between("foobarbaz","foo","baz");  # bar

say between-included("foobarbaz","oo","baz");  # oobarbaz

say around("foobarbaz", "ob", "rb");   # foaz

say after("foobar","foo");             # bar

say chomp-needle("foobarbaz", "baz");  # foobar

say root <abcd abce abde>;             # ab

say leaf <zip.txt zop.txt ff.txt>;     # .txt

say is-sha1 "foo bar baz";             # False

say stem "foo.tar.gz";                 # foo
say stem "foo.tar.gz", 1;              # foo.tar

use String::Utils <before after>;  # only import "before" and "after"

=end code

=head1 DESCRIPTION

String::Utils provides some simple string functions that are not (yet)
provided by the core Raku Programming Language.

These functions are implemented B<without> using regexes for speed.

By default all utility functions are exported.  But you can limit this to
the functions you actually need by specifying the names in the C<use>
statement.

=head1 SUBROUTINES

=head2 after

=begin code :lang<raku>

say after("foobar","foo");   # bar

say "foobar".&after("foo");  # bar

say after("foobar","goo");   # Nil

=end code

Return the string B<after> a given string, or C<Nil> if the given string could
not be found.  The equivalent of the stringification of C</ <?after foo> .* />.

=head2 around

=begin code :lang<raku>

say around("foobarbaz","ob","rb");     # foaz

say "foobarbaz".&around("ob","rb");    # foaz

say around("foobarbaz","goo","baz");   # foobarbaz

=end code

Return the string B<around> two given strings, or the string itself if either
of the bounding strings could not be found.  The equivalent of
C<.subst: / <?after ob> .*? <?before rb> />.

=head2 before

=begin code :lang<raku>

say before("foobar","bar");   # foo

say "foobar".&before("bar");  # foo

say before("foobar","baz");   # Nil

=end code

Return the string B<before> a given string, or C<Nil> if the given string could
not be found.  The equivalent of the stringification of
C</ .*? <?before bar> />.

=head2 between

=begin code :lang<raku>

say between("foobarbaz","foo","baz");   # bar

say "foobarbaz".&between("foo","baz");  # bar

say between("foobarbaz","goo","baz");   # Nil

=end code

Return the string B<between> two given strings, or C<Nil> if either of the
bounding strings could not be found.  The equivalent of the stringification of
C</ <?after foo> .*? <?before baz> />.

=head2 between-included

=begin code :lang<raku>

say between-included("foobarbaz","oo","baz");   # oobarbaz

say "foobarbaz".&between-included("oo","baz");  # oobarbaz

say between-included("foobarbaz","goo","baz");  # Nil

=end code

Return the string B<between> two given strings B<including> the given strings,
or C<Nil> if either of the bounding strings could not be found.  The equivalent
of the stringification of C</ o .*? baz />.

=head2 chomp-needle

=begin code :lang<raku>

say chomp-needle("foobarbaz","baz");   # foobar

say "foobarbaz".&chomp-needle("baz");  # foobar

say chomp-needle("foobarbaz","bar");   # foobarbaz

=end code

Return the string without the given target string at the end, or the string
itself if the target string is not at the end.  The equivalent of
C<.subst(/ baz $/)>.

=head2 root

=begin code :lang<raku>

say root <abcd abce abde>;  # ab

=end code

Return the common B<beginning> of the given strings, or the empty string if
no common string could be found.  See also C<leaf>.

=head2 leaf

=begin code :lang<raku>

say leaf <zip.txt zop.txt ff.txt>;  # .txt

=end code

Return the common B<end> of the given strings, or the empty string if no
common string could be found.  See also C<root>.

=head2 is-sha1

=begin code :lang<raku>

say is-sha1 "abcd abce abde";  # False
say is-sha1 "356A192B7913B04C54574D18C28D46E6395428AB";  # True

=end code

Return a C<Bool> indicating whether the given string is a SHA1 string
(40 chars and only containing 0123456789ABCDEF).

=head2 stem

=begin code :lang<raku>

say stem "foo.tar.gz";     # foo
say stem "foo.tar.gz", 1;  # foo.tar
say stem "foo.tar.gz", *;  # foo

=end code

Return the stem of a string with all of its extensions removed.
Optionally accepts a second argument indicating the number of extensions
to be removed.  This may be C<*> (aka C<Whatever>) to indicate to
remove all extensions.

=head1 AUTHOR

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/String-Utils . Comments and
Pull Requests are welcome.

If you like this module, or what I’m doing more generally, committing to a
L<small sponsorship|https://github.com/sponsors/lizmat/>  would mean a great
deal to me!

=head1 COPYRIGHT AND LICENSE

Copyright 2022 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

# vim: expandtab shiftwidth=4
