# Spicefly - SugarCube
# Developed by Charles Parker
# Modifications by AF, (c) 2024
# Licensed under the GPLv3 - see LICENSE file
#

package Plugins::SugarCube::ProtocolHandler;

use strict;
use warnings;
use Plugins::SugarCube::Plugin;
use Slim::Utils::Log;
my $log = logger('plugin.sugarcube');

sub overridePlayback {
	my ($class, $client, $url) = @_;

	if ($url !~ m|^sugarcube:(.*)$|) {
		return undef;
	}
	$log->debug("ProtocolHandler; Firing");
	Slim::Utils::Timers::setTimer($client, Time::HiRes::time() + 1, \&Plugins::SugarCube::Plugin::AlarmFired, $client);
	return 1;
}

sub canDirectStream { 0 }

sub contentType { return 'sugarcube'; }

sub isRemote { 0 }

sub getIcon { return Plugins::SugarCube::Plugin->_pluginDataFor('icon'); }

1;
