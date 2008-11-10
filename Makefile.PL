use inc::Module::Install;
name 'HTTP-Headers-Fast';
all_from 'lib/HTTP/Headers/Fast.pm';

requires 'HTTP::Headers' => 5.818;
requires 'Readonly'      => 1.03;

tests 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t';
test_requires 'Test::More';
test_requires 'YAML';
author_tests 'xt';
use_test_base;
auto_include;
WriteAll;
