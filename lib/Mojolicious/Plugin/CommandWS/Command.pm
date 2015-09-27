package Mojolicious::Plugin::CommandWS::Command;
use Mojolicious::Plugin::CommandWS::Tree;
use Mojo::Util qw/dumper sha1_sum/;
use JSON::Validator;

my %cmds;
$cmds{REQUEST}	= Mojolicious::Plugin::CommandWS::Tree->new;
$cmds{RESPONSE}	= Mojolicious::Plugin::CommandWS::Tree->new;

sub requests {
	$cmds{REQUEST}
}

my %flow = (
	__init__	=> "REQUEST",
	REQUEST		=> "RESPONSE",
	RESPONSE	=> "CONFIRM"
);

my @fields2check = qw/cmd trans_id version type data/;

sub flow {
	my $class	= shift;
	my $type	= shift;

	$type = $class unless $type;

	if(defined $type) {
		return $flow{$type};
	}

	%flow
}

my $validator	= JSON::Validator->new;
$validator->schema("data://Mojolicious::Plugin::CommandWS::Command/msg.schema.json");

sub emit {
	my $class;
	if($_[0] eq __PACKAGE__) {
		$class = shift;
	}
	my $event	= shift;
	my $data	= shift;

	__PACKAGE__->new(
		version		=> 1,
		cmd		=> $event,
		type		=> "EVENT",
		trans_id	=> generate_trans_id($event),
		data		=> $data,
	)
}

sub new {
	my $class	= shift;
	my %data	= @_;

	my $self = bless { %data }, $class;

	if(my @errors = $validator->validate($data{msg})) {
		return $self->error([@errors])
	}

	$self
}

{
	my $counter;
	sub generate_trans_id {
		my $self = shift;
		sha1_sum join " - ", "CommandWS", $self, localtime time, rand, $counter++
	}
}

sub exec {
	my $self = shift;
	eval {
		return $cmds{$self->{msg}->{type}}->run_command($self->{msg}->{cmd} => $self->{c} => $self) if exists $cmds{$self->{msg}->{type}};
	};
	$self->error($@) if $@;
}

sub data {
	my $self = shift;
	$self->{msg}->{data}
}

sub reply {
	my $self	= shift;
	my $data	= shift;
	my $cb		= shift;
	die "End of type flow" unless defined flow($self->{msg}->{type});

	my $new = bless { %$self }, ref $self;

	$new->{msg}->{type}	= flow($new->{msg}->{type});
	$new->{msg}->{data}	= $data;

	if(defined $cb) {
		$cmds{$new->{msg}->{type}}
			->conditional(sub {
				my $self	= shift;
				my $reply	= shift;

				$reply->data->{trans_id} eq $new->{msg}->{trans_id}
			})
			->command(sub {
				my $self	= shift;
				my $reply	= shift;

				$self->$cb($reply)
			})
		;
	}

	$new->send
}

sub generate_checksum {
	my $self = shift;
	sha1_sum join $/, map {dumper $self->{$_}} @fields2check
}

sub error {
	my $self = shift;
	my $data = shift;

	my $new = bless { %$self }, ref $self;
	$new->{msg}->{type} = "ERROR";
	$new->{msg}->{data} = $data;
	$new->send
}

sub send {
	my $self	= shift;
	$checksum	= $self->generate_checksum;
	$self->{tx}->send({json => {
		version		=> $self->{msg}->{version} // 1,
		cmd		=> $self->{msg}->{cmd},
		type		=> $self->{msg}->{type},
		trans_id	=> $self->{msg}->{trans_id},
		data		=> $self->{msg}->{data},
		checksum	=> $checksum,
	}});
	$self
}

42

__DATA__

@@ msg.schema.json

{
	"type":		"object",
	"required":	["cmd", "trans_id"],
	"properties":	{
		"version":		{
			"type":		"integer",
			"minimum":	1
		},
		"cmd":		{
			"type":		"string"
		},
		"type": {
			"enum":		["REQUEST", "RESPONSE", "CONFIRM", "EVENT", "RECEIVED"]
		},
		"trans_id":	{
			"type":		"string",
			"patern":	"^\\w{40}$"
		},
		"checksum":	{
			"type":		"string",
			"patern":	"^\\w{40}$"
		},
		"data":		{}
	}
}
