use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'Mojolicious::Plugin::CommandWS',
  VERSION_FROM => 'lib/Mojolicious/Plugin/CommandWS.pm',
  AUTHOR       => 'A Good Programmer <fco@cpan.org>',
  PREREQ_PM    => {
	  'Mojolicious'				=> '6.05',
	  'Mojolicious::Plugin::Browserify'	=> '0.06',
  },
  test         => {TESTS => 't/*.t'}
);
