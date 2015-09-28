#!/usr/bin/perl
use lib "./lib";
use Mojo::Util qw/dumper/;
use Mojolicious::Lite;

plugin("CommandWS" => {path => "/ws"})
   ->schema({
      type		=> "object",
      required		=> [qw/auth_key api_key/],
      properties	=> {
	      auth_key		=> {type => "string"},
	      api_key		=> {type => "string"},
      }
   })
   ->command(cmd1 => sub {
      my $self = shift;
      my $data = shift;

      print "DATA: ", dumper $data->data, $/;
      $data->reply("echo: " . dumper $data->data)
   });





app->start
