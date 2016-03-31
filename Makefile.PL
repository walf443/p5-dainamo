use inc::Module::Install;
use Module::Install::ReadmeFromPod;
use Module::Install::Repository;
name 'Dainamo';
all_from 'lib/Dainamo.pm';
readme_from 'lib/Dainamo.pm';

# requires '';

tests_recursive 't';
author_tests 'xt';

build_requires 'Test::More';
build_requires 'Test::LoadAllModules';
build_requires 'Module::Install::ReadmeFromPod';

requires 'Furl';
requires 'Log::Minimal';
requires 'Mouse';
requires 'Parallel::Prefork';
requires 'Proc::Daemon';
requires 'Try::Tiny';
requires 'Class::Load';
requires 'opts';
requires 'parent';

install_script 'scripts/dainamo';
install_script 'scripts/dainamo-top';

auto_include;
auto_set_repository;
WriteAll;
