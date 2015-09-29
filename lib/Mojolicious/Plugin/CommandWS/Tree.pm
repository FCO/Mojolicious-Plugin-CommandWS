package Mojolicious::Plugin::CommandWS::Tree;
use JSON::Validator;

my %cmds;

my @args = qw/arguments schema data type/;

sub list_commands {
	my $self = shift;
	my %ret;
	for my $cmd(keys %cmds) {
		$ret{$cmd}{$_} = [ $cmds{$cmd}->get_attr($_) ] for @args;
	}
	\%ret
}

sub get_attr {
	my $self = shift;
	my $attr = shift;
	die "Invalid attr" unless grep {$attr eq $_} @args;

	my @ret;

	if($self->{parent}) {
		my @tmp = $self->{parent}->get_attr($attr);
		push @ret, @tmp if @tmp
	}
	my @tmp = grep {defined} ref $self->{$attr} eq "ARRAY" ? @{ $self->{$attr} } : $self->{$attr};
	push @ret, @tmp if @tmp;
	@ret;
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

sub arguments {
	my $self	= shift;
	my @arguments	= shift;

	my $new = __PACKAGE__->new(
		arguments	=> [@arguments],
		parent		=> $self,
	);
	$new
}

sub data {
	my $self	= shift;
	my $data	= shift;

	my $new = __PACKAGE__->new(
		data	=> [@arguments],
		parent	=> $self,
	);
	$new
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

sub type {
	my $self = shift;
	my $type = uc shift;

	die "Type does not exists" unless exists $Mojolicious::Plugin::CommandWS::Command::flow{$type};
	my $new = $self->conditional(sub {
		my $self	= shift;
		my $msg		= shift;

		$msg->{msg}->{type} eq $type;
	});
	$new->{type} = $type;
	$new
}

sub schema {
	my $self	= shift;
	my $schema	= shift;

	my $schema_obj = JSON::Validator->new;
	$schema_obj->schema($schema);
	my $new = $self->conditional(sub {
		my $self	= shift;
		my $msg		= shift;

		if(my @errors = $schema_obj->validate($msg->data)) {
			die [@errors];
		}
		1
	});
	$new->{schema} = $schema;
	$new
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
