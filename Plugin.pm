package Plugins::PandoraDirect::Plugin;

# Logitech Media Server Copyright 2001-2023 Logitech.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

use strict;

use base qw(Slim::Plugin::OPMLBased);
use Slim::Utils::Prefs;

use WebService::Pandora;
use WebService::Pandora::Partner::AIR;
use Cwd ();
use File::Basename ();
use File::Spec ();
use lib File::Spec->catdir(File::Basename::dirname(Cwd::abs_path __FILE__), 'lib/perl5');
use MIME::Base64 (qw/decode_base64/);
use Data::Dumper;

my $partner;
my $pandora;

my $log = Slim::Utils::Log->addLogCategory( {
	category     => 'plugin.pandoradirect',
	defaultLevel => 'DEBUG',
	description  => 'PLUGIN_PANDORA_DIRECT_DESC',
} );

my $prefs = preferences('plugin.pandoradirect');

sub initPlugin {
	my ($class) = @_;

	Slim::Player::ProtocolHandlers->registerHandler(
		pandoradirect => 'Plugins::PandoraDirect::ProtocolHandler'
	);

	if (main::WEBUI) {
		require Plugins::PandoraDirect::Settings;
		Plugins::PandoraDirect::Settings->new();
	}

	$class->SUPER::initPlugin(
		feed   => sub {
			my ($client, $cb, $args) = @_;
			$class->_call('channelList', $client, $cb, $args);
		},
		tag    => 'pandoradirect',
		is_app => 1,
		weight => 1,
		menu   => 'radios',
	);
}

sub authenticate {
	my ( $class, $cb ) = @_;

	unless ($partner) {
		$log->debug('Creating new partner');
		$partner = WebService::Pandora::Partner::AIR->new;
	}
	unless ($pandora) {
		$log->debug('Creating new client');
		$pandora = WebService::Pandora->new(
			username => $prefs->get('username'),
			password => decode_base64($prefs->get('password')),
			partner  => $partner,
		);
	}

	$pandora->login($cb);
}

sub _call {
	my ( $class, $method, $client, $cb, $args ) = @_;

	$log->info("API call: $method");

	$class->authenticate(
		sub {
			$class->$method($client, $cb, $args);
		}
	);
}

sub getPlaylist {
	my ($class, $client, $cb, $args) = @_;

	$pandora->getPlaylist(
		sub {
			my $ret = shift;
			if ($pandora->error) {
				$log->error( $pandora->error );
			}
			$log->debug("playlist: " . Dumper($ret));
			$cb->($ret, $args);
		},
		%$args,
	);
}

sub channelList {
	my ($class, $client, $cb, $args) = @_;

	if (!$prefs->get('username') || !$prefs->get('password')) {
		return $cb->([{
			type => 'text',
			name => Slim::Utils::Strings::cstring($client, $class->missingCredsString),
		}]);
	}

	$pandora->getStationList(
		sub {
			my $ret = shift;
			my @stations;
			for my $station (@{$ret->{stations}}) {
				push @stations, {
					type        => 'link',
					play        => "pandoradirect://$station->{stationId}.mp3",
					on_select   => 'play',
					items       => [],
					name        => $station->{stationName},
					image       => $station->{artUrl},
					url         => \&getStation,
					passthrough => [{
						stationId => $station->{stationId},
					}],
				};
			}
			$cb->(\@stations);
		}
	);
}

sub missingCredsString {
	'PLUGIN_PANDORA_DIRECT_MISSING_CREDS';
}

1;