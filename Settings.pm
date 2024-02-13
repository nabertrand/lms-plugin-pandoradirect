package Plugins::PandoraDirect::Settings;

# Logitech Media Server Copyright 2001-2023 Logitech.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

use strict;

use base qw(Slim::Web::Settings);

use MIME::Base64 (qw/encode_base64/);
use Data::Dumper;
use Slim::Utils::Log;
use Slim::Utils::Prefs;

my $prefs = preferences('plugin.pandoradirect');
my $log   = logger('plugin.pandoradirect');

sub name {
	return Slim::Web::HTTP::CSRF->protectName('PLUGIN_PANDORA_DIRECT_NAME');
}

sub prefs { return ($prefs, qw(username password) )}

sub page {
	return Slim::Web::HTTP::CSRF->protectURI('plugins/PandoraDirect/settings.html');
}

sub handler {
	my ($class, $client, $params, $callback, @args) = @_;

	$log->debug("Params: " . Data::Dumper::Dumper($params));
	if ( $params->{pref_password} ) {
		$params->{pref_password} = encode_base64($params->{pref_password}, '');
	}
	$log->debug("Params: " . Data::Dumper::Dumper($params));

	return $class->SUPER::handler($client, $params);
}

1;