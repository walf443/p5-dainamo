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

requires 'opts';
requires 'parent';
requires 'Proc::Daemon';
requires 'Mouse';
requires 'Log::Minimal';
requires 'Parallel::Prefork';

auto_include;
auto_set_repository;
WriteAll;
