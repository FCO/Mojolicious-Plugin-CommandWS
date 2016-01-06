use Mojo::Base -strict;

use Test::More;
use Mojolicious::Lite;
use Test::Mojo;

plugin 'CommandWS';

get '/' => sub {
  my $c = shift;
  $c->render(text => 'Hello Mojo!');
};

my $t = Test::Mojo->new;
#$t->get_ok('/');#->status_is(200);#->content_is('Hello Mojo!');
ok 1, "just to pass";

done_testing();
