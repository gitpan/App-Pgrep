#!perl

use strict;
use warnings;

use Test::More 'no_plan';

use lib 'lib';
use App::Pgrep;

#
# Test constructor
#

can_ok 'App::Pgrep', 'new';

ok my $pgrep = App::Pgrep->new( { dir => 't/' } ),
  '... and calling it with valid arguments should succeed';
isa_ok $pgrep, 'App::Pgrep', '... and the object it returns';

#
# Test dir()
#

can_ok $pgrep, 'dir';
is $pgrep->dir, 't/',
  '... and it should return the value passed in the constructor';

ok $pgrep->dir(undef), 'We should be able to unset dir()';
ok !defined $pgrep->dir, '... and it will now return undef';

ok $pgrep->dir('t/lib/quotes/'),
  'We should be able to set dir() to a new directory';
is $pgrep->dir, 't/lib/quotes/', '... and have it return that directory';

#
# search()
#

can_ok $pgrep, 'search';
ok my @search = $pgrep->search, '... and it should return results';
is scalar @search, 1, '... but only one result object';

my $found = shift @search;
isa_ok $found, 'App::Pgrep::Results';
is $found->file, 't/lib/quotes/quote1.pl',
  '... and it should tell us the file it found results in';

ok my $results = $found->next, 'We should be able to call next()';
is $results->token, 'quote', '... and quote elements were matched';
is $results->next, 'double quoted string',
  '... and we can get the first quote match';
is $results->next, 'single quoted string',
  '... and we can get the second quote match';
is $results->next, 'q{} quoted string',
  '... and we can get the third quote match';
is $results->next, 'qq{} quoted string',
  '... and we can get the last quote match';
ok !defined $results->next, '... and we should have no more results';

ok $results = $found->next, 'We should be able to call next()';
is $results->token, 'heredoc', '... and heredoc elements were matched';
is $results->next, "heredoc string\n   with two lines\n",
  '... and we can get the first herdoc match';
ok !defined $results->next, '... and we should have no more results';
ok !defined $found->next,   'found() should return undef when done';

$pgrep->pattern('q+{');
ok @search = $pgrep->search, 'We should be able to do a new search';

$found = shift @search;
isa_ok $found, 'App::Pgrep::Results';
is $found->file, 't/lib/quotes/quote1.pl',
  '... and it should tell us the file it found results in';

ok $results = $found->next, 'We should be able to call next()';
is $results->token, 'quote', '... and quote elements were matched';
is $results->next, 'q{} quoted string',
  '... and we can get the first string match';
is $results->next, 'qq{} quoted string',
  '... and we can get the second string match';
ok !defined $results->next, '... and we should have no more results';

ok $pgrep = App::Pgrep->new,
  '... and calling it with no arguments should succeed';
is $pgrep->dir, '.', '... and it should default to searching the current dir';
