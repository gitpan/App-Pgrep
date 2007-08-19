#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'App::Pgrep' );
}

diag( "Testing App::Pgrep $App::Pgrep::VERSION, Perl $], $^X" );
