package Mojolicious::Plugin::CommandWS::Tree;

my %cmds;

sub run_command {
	my $self	= shift;
	my $command	= shift;
	my $this	= shift;

	return $cmds{$command}->run($this => @_) if exists $cmds{$command};
}

sub run {
	my $self	= shift;
	my $this	= shift;
	my @data	= @_;

	die "Not a object setted" unless defined $this;

	return if exists $self->{parent} and not defined $self->{parent}->run($this => @data);

	if(exists $self->{conditional}) {
		my $cond = $self->{conditional};
		return unless $this->$cond(@data)
	}
	if(exists $self->{command}) {
		my $cmd = $self->{command};
		return $this->$cmd(@data)
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

	my $new = (ref $self)->new(
		conditional	=> $func,
		parent		=> $self,
	);
	$new
}

sub command {
	my $self	= shift;
	my $name	= shift;
	my $func	= shift;

	if(exists $cmds{$name}) {
		die "Command $name already exists"
	}
	my $new = (ref $self)->new(
		command	=> $func,
		parent	=> $self,
	);
	$cmds{$name} = $new;
	undef
}

42
