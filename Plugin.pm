package Plugins::PandoraDirect::Plugin;

# Logitech Media Server Copyright 2001-2023 Logitech.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

use strict;

use base qw(Slim::Plugin::OPMLBased);

use Plugins::PandoraDirect::API;
use Slim::Utils::Prefs;

my $log = Slim::Utils::Log->addLogCategory( {
	category     => 'plugin.pandoradirect',
	defaultLevel => 'ERROR',
	description  => 'PLUGIN_PANDORA_DIRECT_DESC',
} );

my $prefs = preferences('plugin.pandoradirect');

sub initPlugin {
	my ($class) = @_;

	if (main::WEBUI) {
		require Plugins::PandoraDirect::Settings;
		Plugins::PandoraDirect::Settings->new();
	}

	$class->SUPER::initPlugin(
		feed   => sub {
			my ($client, $cb, $args) = @_;
			$class->channelList($client, $cb, $args);
		},
		tag    => 'pandoradirect',
		is_app => 1,
		weight => 1,
		menu   => 'radios',
	);
}

sub channelList {
	my ($class, $client, $cb, $args) = @_;

	if (!$prefs->get('listen_key') || !$prefs->get('subscriptions')) {
		return $cb->([{
			type => 'text',
			name => Slim::Utils::Strings::cstring($client, $class->missingCredsString),
		}]);
	}

	Plugins::PandoraDirect::API->channelFilters($class->network, sub {
		my $filters = shift;

		my $items = [];
		for my $filter ( @{$filters} ) {
			my $channels = [];
			for my $channel ( @{ $filter->{channels} } ) {
				my $image = $channel->{asset_url} . '?size=1000x1000&quality=90';
				$image = 'https:' . $image if $image =~ m|^//|;

				push @{$channels}, {
					type    => 'audio',
					bitrate => 320,
					name    => $channel->{name},
					line1   => $channel->{name},
					line2   => $channel->{description},
					image   => $image,
					url     => Plugins::PandoraDirect::API::API_URL . sprintf(
						'%s/listen/premium_high/%s.pls?listen_key=%s',
						$class->network,
						$channel->{key},
						$prefs->get('listen_key')
					),
				};
			}

			push @$items, {
				type  => 'playlist',
				name  => $filter->{name},
				items => $channels,
			};
		}

		main::DEBUGLOG && $log->is_debug && $log->debug("ChannelList:" . Data::Dump::dump($items));

		$cb->($items);
	});
}

sub missingCredsString {
	'PLUGIN_PANDORA_DIRECT_MISSING_CREDS';
}

1;