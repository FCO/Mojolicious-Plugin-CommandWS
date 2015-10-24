package Mojolicious::Plugin::CommandWS;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Util qw/dumper sha1_sum/;
use Mojolicious::Plugin::CommandWS::Command;
use File::Basename 'dirname';
use File::Spec::Functions 'catdir';
use Mojo::EventEmitter;

our $VERSION = '0.01';

sub register {
	my ($self, $app, $conf) = @_;
	my $r	= $app->routes;

	$app->attr(events => sub{ Mojo::EventEmitter->new });

	push @{$app->static->classes}, "Mojolicious::Plugin::CommandWS::Command";

	my $base = catdir dirname(__FILE__), 'CommandWS';
	push @{$app->static->paths}, catdir($base, 'public');

	my $cmds = Mojolicious::Plugin::CommandWS::Command::requests();

	for my $schema(exists $conf->{schema} ? ref $conf->{schema} eq "ARRAY" ? @{ $conf->{schema} } : $conf->{schema} : ()) {
		$cmds = $cmds->schema($schema);
	}
	for my $conditional(exists $conf->{conditional} ? ref $conf->{conditional} eq "ARRAY" ? @{ $conf->{conditional} } : $conf->{conditional} : ()) {
		$cmds = $cmds->conditional($conditional);
	}

	$cmds->command(log => sub{
		my $self	= shift;
		my $msg		= shift;

		print $msg->{msg}->{trans_id}, ": ", dumper $msg->data
	});

	$cmds->command(list_commands => sub{
		my $self	= shift;
		my $msg		= shift;

		$msg->reply($cmds->list_commands)
	});

	# msg:
	# {
	# 	cmd		=> "command_name",
	#	type		=> "REQUEST",
	# 	trans_id	=> "1234567890123456789012345678901234567890",
	# 	data		=> {data},
	#	checksum	=> "1234567890123456789012345678901234567890"
	# }

	$r->websocket($conf->{path})
		->to(cb => sub {
			my $c	= shift;
			$c->inactivity_timeout(3600);
			$c->on(json => sub{
				my $tx	= shift;
				my $msg	= shift;

				print "MSG: <[", dumper($msg), "]>", $/;

				my $msgCMD = Mojolicious::Plugin::CommandWS::Command->new(
					via	=> "ws",
					tx	=> $tx,
					msg	=> $msg,
					cmds	=> $cmds,
					c	=> $c,
				);

				$msgCMD->exec if $msgCMD
			});
		})
	;

	my $lp_counter;
	my $delimiter = $conf->{delimiter} // "/*---------------------------*/";
	$r->get($conf->{path})
		->to(cb => sub {
			my $c	= shift;
			my $lp	= sha1_sum join " - ", $c, localtime time, rand, $lp_counter++;
			$c->write_chunk("lp($lp)[$delimiter]$/");
			$c->inactivity_timeout(3600);
			my $event = "longpoll $lp";
			my $cb = $c->app->events->on($event, sub{
				shift;
				my $msg = shift;

				my $msgCMD = Mojolicious::Plugin::CommandWS::Command->new(
					via	=> "lp",
					delim	=> $delimiter,
					tx	=> $c->tx,
					msg	=> $msg,
					cmds	=> $cmds,
					c	=> $c,
				);

				$msgCMD->exec if defined $msgCMD
			});
			$c->on(finish => sub {$c->app->events->unsubscribe($event => $cb)});
		})
	;
	$r->post($conf->{path})
		->to(cb => sub {
			my $c		= shift;
			my $data	= $c->req->json;
			print "MSG: <[", dumper($data), "]>", $/;
			my $lp		= delete $data->{lp};
			$c->app->events->emit("longpoll $lp", $data);
			$c->render(status => 200, json => {ok => \1})
		})
	;

	$cmds
}

42
