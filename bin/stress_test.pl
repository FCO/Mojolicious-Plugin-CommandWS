#!/usr/bin/perl
use lib "./lib";
use Mojo::Util qw/dumper/;
use Mojolicious::Lite;
use Mojolicious::Plugin::CommandWS::Command;
use Mojo::IOLoop;

my $cmds = plugin "CommandWS" => {path => "/ws"};

$cmds
	->type("REQUEST")
	->schema({
		type		=> "object",
		required	=> [qw/date sleep_for/],
		properties	=> {
			date		=> {},
			sleep_for	=> {type => "number"},
			bla		=> {},
			ble		=> {},
		}
	})
	->command(stress1 => sub {
		my $self = shift;
		my $data = shift;

		$self->app->log->info("STRESS_TEST");
		if($data->data->{sleep_for}) {
			Mojo::IOLoop->timer($data->data->{sleep_for} => sub {
				$data->reply({%{ $data->data }, slept => $data->data->{sleep_for}})
			});
		} else {
			$data->reply({%{ $data->data }, slept => 0})
		}
	})
;

app->start
