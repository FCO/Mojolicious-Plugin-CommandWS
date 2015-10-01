#!/usr/bin/perl
use lib "./lib";
use Mojo::Util qw/dumper/;
use Mojolicious::Lite;
use Mojolicious::Plugin::CommandWS::Command;

my $cmds = plugin"CommandWS" => {path => "/ws"};

#$cmds
#	->schema({
#		type		=> "string",
#	})
#	->command(cmd2 => sub {
#		my $self = shift;
#		my $data = shift;
#
#		print "DATA: ", dumper $data->data, $/;
#		$data->reply("echo2: " . $data->data)
#	})
#;

$cmds
	->type("REQUEST")
	->schema({
		type		=> "object",
		required	=> [qw/auth_key api_key/],
		properties	=> {
			auth_key	=> {type => "string"},
			api_key		=> {type => "string"},
		}
	})
	->command(cmd1 => sub {
		my $self = shift;
		my $data = shift;

		print "cmd1($data)$/";
		$data->reply("echo: " . dumper $data->data)
	})
;

$cmds
	->type("SUBSCRIBE")
	->command(event1 => sub {
		my $self = shift;
		my $data = shift;

		my $loop = Mojo::IOLoop->singleton;
		my $counter = 0;
		my $id = $loop->recurring(1 => sub {
			$data = $data->reply(++$counter);
		});
		$self->{tx}->on(finish => sub{ Mojo::IOLoop->remove($id) });
	})
;





		app->start
