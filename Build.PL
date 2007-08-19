use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name       => 'App::Pgrep',
    license           => 'perl',
    dist_author       => 'Curtis Poe <ovid@cpan.org>',
    dist_version_from => 'lib/App/Pgrep.pm',
    build_requires    => {
        'Scalar::Util' => 1.19,
        'Test::More'   => 0,
        'File::Next'   => 0.40,
        'PPI'          => 1.118,
    },
    exe_files          => ['bin/pgrep'],
    add_to_cleanup     => ['App-Pgrep-*'],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
