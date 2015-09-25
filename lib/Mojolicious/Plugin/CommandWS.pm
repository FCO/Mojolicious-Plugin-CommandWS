package Mojolicious::Plugin::CommandWS;
use Mojo::Base 'Mojolicious::Plugin';
use JSON::Validator;
use Mojo::Util qw/dumper/;
use CommandWS::Tree;
use CommandWS;
use strict;

our $VERSION = '0.01';

sub register {
	my ($self, $app, $conf) = @_;
	my $r = $app->routes;

	my $cmds = CommandWS::Tree->new;

	$cmds->command(log => sub{
		my $self	= shift;
		my $msg		= shift;

		print $msg->{msg}->{trans_id}, ": ", dumper $msg->data
	});

	$r->websocket($conf->{path})
		->to(cb => sub{
			my $c	= shift;
			$c->on(json => sub{
				my $tx	= shift;
				my $msg	= shift;

				# msg:
				# {
				# 	cmd		=> "command_name",
				#	type		=> "REQUEST",
				# 	trans_id	=> "1234567890123456789012345678901234567890",
				# 	data		=> {data}
				# }

				my $msgCMD = CommandWS->new(
					tx	=> $tx,
					msg	=> $msg,
					cmds	=> $cmds,
					c	=> $c,
				);

				$msgCMD->exec
			});
		})
	;

	$cmds
}

42
