package Mojolicious::Plugin::CommandWS::Tree;
use JSON::Validator;

my %cmds;

sub list_commands {
	keys %cmds
}

sub run_command {
	my $self	= shift;
	my $command	= shift;
	my $this	= shift;

	return $cmds{$command}->run($this => @_) if exists $cmds{$command};
}

sub run {
	my $self	= shift;
	my $this	= shift;
	my $data	= shift;

	die "Not a object setted" unless defined $this;
	return if exists $self->{parent} and not defined $self->{parent}->run($this => $data);

	if(exists $self->{conditional}) {
		my $cond = $self->{conditional};
		return unless $this->$cond($data)
	}
	if(exists $self->{command}) {
		my $cmd = $self->{command};
		return $this->$cmd($data)
	}
	1
}

sub new {
	my $class	= shift;
	my %data	= @_;
	bless {
		%data
	}, $class;
}

sub conditional {
	my $self	= shift;
	my $func	= shift;

	my $new = __PACKAGE__->new(
		conditional	=> $func,
		parent		=> $self,
	);
	$new
}

sub schema {
	my $self	= shift;
	my $schema	= shift;

	my $schema_obj = JSON::Validator->new;
	$schema_obj->schema($schema);
	$self->conditional(sub {
		my $self	= shift;
		my $msg		= shift;

		if(my @errors = $schema_obj->validate($msg->data)) {
			die [@errors];
		}
		1
	});
}

sub command {
	my $self	= shift;
	my $name	= shift;
	my $func	= shift;

	if(exists $cmds{$name}) {
		die "Command $name already exists"
	}
	my $new = __PACKAGE__->new(
		command	=> $func,
		parent	=> $self,
	);
	$cmds{$name} = $new;
	undef
}

42
