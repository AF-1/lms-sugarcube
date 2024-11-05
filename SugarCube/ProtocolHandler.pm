package Plugins::SugarCube::ProtocolHandler;

# $Id

# Squeezebox Server Copyright 2001-2009 Logitech.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

use strict;
use Plugins::SugarCube::Plugin;
use Slim::Utils::Log;
my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.sugarcube',
	'defaultLevel' => 'DEBUG',
	'description'  => getDisplayName(),
});

sub getDisplayName {return 'PLUGIN_SUGARCUBE';}

sub overridePlayback {
	my ( $class, $client, $url ) = @_;

	if ($url !~ m|^sugarcube:(.*)$|) {
		return undef;
	}
	$log->debug("ProtocolHandler; Firing");
    Slim::Utils::Timers::setTimer($client, Time::HiRes::time() + 1, \&Plugins::SugarCube::Plugin::AlarmFired($client),);
	return 1;
}

sub canDirectStream { 0 }

sub contentType {
	return 'sugarcube';
}

sub isRemote { 0 }

sub getIcon {
	return Plugins::SugarCube::Plugin->_pluginDataFor('icon');
}
1;
