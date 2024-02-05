package Plugins::PandoraDirect::Settings;

# Logitech Media Server Copyright 2001-2023 Logitech.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

use strict;

use base qw(Slim::Web::Settings);

use Plugins::PandoraDirect::API;
use Slim::Utils::Log;
use Slim::Utils::Prefs;

my $prefs = preferences('plugin.pandoradirect');
my $log   = logger('plugin.pandoradirect');

sub name {
	return Slim::Web::HTTP::CSRF->protectName('PLUGIN_PANDORA_DIRECT_NAME');
}

sub prefs { return ($prefs, qw(username premium) )}

sub page {
	return Slim::Web::HTTP::CSRF->protectURI('plugins/PandoraDirect/settings.html');
}

sub handler {
	my ($class, $client, $params, $callback, @args) = @_;

	if ( $params->{pref_logout} ) {
		$prefs->remove('listen_key');
		$prefs->remove('subscriptions');
	}
	elsif ( $params->{saveSettings} ) {
		# set credentials if mail changed or a password is defined and it has changed
		if ( $params->{pref_username} && $params->{password} ) {
			Plugins::PandoraDirect::API->authenticate({
				username => $params->{pref_username},
				password => $params->{password},
				premium  => $params->{pref_premium},
			}, sub {
				my $body = $class->SUPER::handler($client, $params);
				$callback->( $client, $params, $body, @args );
			});

			return;
		}
	}

	return $class->SUPER::handler($client, $params);
}

sub beforeRender {
	my ($class, $params, $client) = @_;
	$params->{has_session} = $prefs->get('listen_key') && $prefs->get('subscriptions') && 1;
}

1;