#!perl

use strict;
use warnings;

use Test::More 'no_plan';

use lib 'lib';
use App::Pgrep;

#
# Test constructor
#

ok my $pgrep = App::Pgrep->new(
    {
        files => [ 't/lib/quotes/quote1.pl', 't/lib/Pgrep/PodAndComments.pm' ],
        look_for => [qw/pod comments/],
    }
  ),
  '... and calling it with "files" should succeed';
isa_ok $pgrep, 'App::Pgrep', '... and the object it returns';

ok !defined $pgrep->dir, '... and dir should not be defined';

can_ok $pgrep, 'files';
ok my $files = $pgrep->files, '... and files should be defined';
is_deeply $files, [ 't/lib/quotes/quote1.pl', 't/lib/Pgrep/PodAndComments.pm' ],
  '... and it should return the files it will search';
ok my @files = $pgrep->files, '... and even if called in list context';
is_deeply \@files, $files, '... it should return the correct files';

#
# search()
#

can_ok $pgrep, 'search';
ok my @search = $pgrep->search, '... and it should return results';
is scalar @search, 2, '... with two result objects';

my $found = shift @search;
isa_ok $found, 'App::Pgrep::Results';
is $found->file, 't/lib/quotes/quote1.pl',
  '... and it should tell us the file it found results in';

ok my $results = $found->next, 'We should be able to call next()';
is $results->token, 'comments', '... and quote elements were matched';
is $results->next, "#!/usr/bin/perl\n",
  '... and we can get the first comment match';
__END__
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

__END__
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

ok my $pgrep = App::Pgrep->new( { file => 't/' } ),
  '... and calling it with valid arguments should succeed';
