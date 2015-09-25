package Mojolicious::Plugin::CommandWS::Command;

my %flow = (
	__init__	=> "REQUEST",
	REQUEST		=> "RESPONSE",
	RESPONSE	=> "CONFIRM"
);

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
	die "End of type flow" unless exists $flow{$self->{msg}->{type}};

	my $new = bless { %$self }, ref $self;

	$new->{msg}->{type} = $flow{$new->{msg}->{type}};
	$new->{msg}->{data} = $data;
	$new->send
}

sub error {
	my $self = shift;
	my $data = shift;

	my $new = bless { %$self }, ref $self;
	$new->{msg}->{type} = "ERROR";
	$new->send
}

sub send {
	my $self = shift;
	$self->{tx}->send({json => {
		cmd		=> $self->{msg}->{cmd},
		type		=> $self->{msg}->{type},
		trans_id	=> $self->{msg}->{trans_id},
		data		=> $self->{msg}->{data},
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
		"data":		{}
	}
}

@@ CommandWS.js

// CommandWS.js

