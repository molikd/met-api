package Dancer::Session::Met;


use strict;
use warnings;

use parent 'Dancer::Session::Abstract';

use Redis::hiredis;
use Dancer::Config 'setting';
use Storable ();
use Carp ();

my $_redis;
my %options = ();

sub init {
	my $self = shift;

	$self->SUPER::init(@_);

	# backend settings
	if (my $opts = setting('redis_session') ) {
		if (ref $opts and ref $opts eq 'HASH' ) {
			%options = (
				server   => $opts->{server}   || undef,
				sock     => $opts->{sock}     || undef,
				database => $opts->{database} || 0,
				expire   => $opts->{expire}   || 900,
				debug    => $opts->{debug}    || 0,
				password => $opts->{password} || undef,
			);
		} else {
			Carp::croak 'Settings redis_session must be a hash reference!';
		}
	} else {
		Carp::croak 'Settings redis_session is not defined!';
	}

	unless (defined $options{server} || defined $options{sock}) {
		Carp::croak 'Settings redis_session should include either server or sock parameter!';
	}

	# get radis handle
	$self->redis;
}

# create a new session
sub create {
	my ($class) = @_;

	$class->new->flush;
}

# fetch the session object by id
sub retrieve($$) {
	my ($class, $id) = @_;

	my $self = $class->new;
	$self->redis->select($options{database});
	$self->redis->expire($id => $options{expire});

	Storable::thaw($self->redis->get($id));
}

# delete session
sub destroy {
	my ($self) = @_;

	$self->redis->select($options{database});
	$self->redis->del($self->id);
}

# flush session
sub flush {
	my ($self) = @_;

	$self->redis->select($options{database});
	$self->redis->set($self->id => Storable::freeze($self));
	$self->redis->expire($self->id => $options{expire});

	$self;
}

# get redis handle
sub redis {
	my ($self) = @_;

	if (!$_redis || !$_redis->ping) {
		my %params = (
			debug	 => $options{debug},
			reconnect => 10,
			every	 => 100,
		);

		if (defined $options{sock}) {
			$params{sock} = $options{sock};
		}
		else {
			$params{server} = $options{server};
		}

		$params{password} = $options{password} if $options{password};

		$_redis = Redis::hiredis->new(%params);
	}

	$_redis and return $_redis;

	Carp::croak "Unable connect to redis-server...";
}

1; # End of Dancer::Session::Redis

__END__
