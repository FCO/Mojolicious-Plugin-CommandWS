package Mojolicious::Plugin::CommandWS;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Util qw/dumper/;
use Mojolicious::Plugin::CommandWS::Command;
use File::Basename 'dirname';
use File::Spec::Functions 'catdir';

our $VERSION = '0.01';

sub register {
	my ($self, $app, $conf) = @_;
	my $r = $app->routes;

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

	$r->websocket($conf->{path})
		->to(cb => sub{
			my $c	= shift;
			$c->on(json => sub{
				my $tx	= shift;
				my $msg	= shift;

				print "MSG: <[", dumper($msg), "]>", $/;

				# msg:
				# {
				# 	cmd		=> "command_name",
				#	type		=> "REQUEST",
				# 	trans_id	=> "1234567890123456789012345678901234567890",
				# 	data		=> {data},
				#	checksum	=> "1234567890123456789012345678901234567890"
				# }

				my $msgCMD = Mojolicious::Plugin::CommandWS::Command->new(
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
