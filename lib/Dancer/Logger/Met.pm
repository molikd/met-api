package Dancer::Logger::Met;

use strict;
use warnings;

use base 'Dancer::Logger::Abstract';
use File::Basename 'basename';
use Sys::Syslog qw(:DEFAULT setlogsock);
use Dancer::Config 'setting';

sub init {
	my ($self) = @_;

	setlogsock('unix');

	my $conf = setting('syslog');

	$self->{facility} = $conf->{facility} || 'USER';
	$self->{ident}    = $conf->{ident}
		                    || setting('appname') 
		                    || $ENV{DANCER_APPDIR} 
		                    || basename($0);
	$self->{logopt}   = $conf->{logopt}   || 'ndelay,pid';
}

sub DESTROY { closelog() }

sub _log {
	my ($self, $level, $message) = @_;

	if (!$self->{log_opened}) {
		openlog($self->{ident}, $self->{logopt}, $self->{facility});
		$self->{log_opened} = 1;
	}

	my $syslog_levels = {
		core    => 'debug',
		debug   => 'debug',
		warning => 'warning',
		error   => 'err',
		info    => 'info',
	};

	$level = $syslog_levels->{$level} || 'debug';
	my $fm = $self->format_message($level => $message);
	return syslog($level, $fm);
}

1;

=head1 NAME

Dancer::Logger::Met - a built in syslogger for Dancer

=head1 SYNOPSIS

    use Dancer::Logger::Met;
    set logger => 'met';
    set syslog   => { facility => $CONFIG->{log_facility}, ident => __PACKAGE__, };

=head1 AUTHOR

Dan Molik, C<< <dan at brgl.org> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Dancer::Logger::Met

__END__
