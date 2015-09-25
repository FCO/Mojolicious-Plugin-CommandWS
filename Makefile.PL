use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'Mojolicious::Plugin::CommandWS',
  VERSION_FROM => 'lib/Mojolicious/Plugin/CommandWS.pm',
  AUTHOR       => 'A Good Programmer <nospam@cpan.org>',
  PREREQ_PM    => {'Mojolicious' => '6.05'},
  test         => {TESTS => 't/*.t'}
);
