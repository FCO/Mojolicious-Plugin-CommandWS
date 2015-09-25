package Mojolicious::Plugin::CommandWS::Command;
use Mojo::Util qw/dumper sha1_sum/;

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

sub new {
	my $class	= shift;
	my %data	= @_;

	my $self = bless { %data }, $class;

	if(my @errors = $validator->validate($data{msg})) {
		return $self->error([@errors])
	}

	$self
}

sub exec {
	my $self = shift;
	$self->{cmds}->run_command($self->{msg}->{cmd} => $self->{c} => $self);
}

sub data {
	my $self = shift;
	$self->{msg}->{data}
}

sub reply {
	my $self = shift;
	my $data = shift;
	die "End of type flow" unless defined flow($self->{msg}->{type});

	my $new = bless { %$self }, ref $self;

	$new->{msg}->{type}	= flow($new->{msg}->{type});
	$new->{msg}->{data}	= $data;
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
	$new->send
}

sub send {
	my $self	= shift;
	$checksum	= $self->generate_checksum;
	$self->{tx}->send({json => {
		version		=> 1,
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
			"enum":		["REQUEST", "RESPONSE", "CONFIRM"]
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
