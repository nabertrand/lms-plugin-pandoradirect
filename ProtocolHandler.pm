package Plugins::PandoraDirect::ProtocolHandler;

# Logitech Media Server Copyright 2003-2020 Logitech.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License, 
# version 2.

# Handler for pandoradrect:// URLs

use strict;
use base qw(Slim::Player::Protocols::HTTP);

use JSON::XS::VersionOneAndTwo;
use Data::Dumper;

use Plugins::PandoraDirect::Plugin;

use Slim::Player::Playlist;
use Slim::Utils::Misc;

my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.pandoradirect',
	'defaultLevel' => 'DEBUG',
	'description'  => 'PLUGIN_PANDORA_DIRECT_MODULE_NAME',
});

# default artwork URL if an album has no art
my $defaultArtURL = 'http://www.pandora.com/images/no_album_art.jpg';

# To support remote streaming (synced players, slimp3/SB1), we need to subclass Protocols::HTTP
sub new {
	my $class  = shift;
	my $args   = shift;

	my $client = $args->{client};

	my $song      = $args->{'song'};
	my $streamUrl = $song->streamUrl() || return;

	$log->debug( 'Remote streaming Pandora track: ' . $streamUrl );

	my $sock = $class->SUPER::new( {
		url     => $streamUrl,
		song    => $args->{'song'},
		client  => $client,
		bitrate => $song->bitrate() || 128_000,
	} ) || return;

	${*$sock}{contentType} = 'audio/mpeg';

	return $sock;
}

sub scanUrl {
	my ($class, $url, $args) = @_;
	$args->{'cb'}->($args->{'song'}->currentTrack());
}

sub getFormatForURL () { 'mp3' }

sub shouldLoop () { 0 }

sub isRepeatingStream { 1 }

sub getNextTrack {
	my ($class, $song, $successCb, $errorCb) = @_;

	my $client = $song->master();
	my $url    = $song->track()->url;

	my ($stationId) = $url =~ m{^pandoradirect://([^.]+)\.mp3};

	my $playlist = $client->master->pluginData('playlist');

	if ($playlist && scalar(@$playlist)) {
		$log->debug('Found existing playlist: ' . Dumper($playlist));
		updateNextTrack($client, $song, $playlist, $successCb);
	}
	else {
		Plugins::PandoraDirect::Plugin->_call(
			'getPlaylist',
			$client,
			\&getNextTrackCallback,
			{
				stationToken => $stationId,
				client => $client,
				song => $song,
				callback => $successCb,
				errorCallback => $errorCb,
			},
		)
	}

}

sub getNextTrackCallback {
	my ($ret, $args) = @_;
	unless ($ret) {
		$log->debug('Nothing returned from getPlaylist');
		$args->{errorCallback}->('Failed to retrieve playlist', '');
		return;
	}

	updateNextTrack($args->{client}, $args->{song}, $ret->{items}, $args->{callback});
}

sub updateNextTrack {
	my ($client, $song, $playlist, $callback) = @_;

	my @playlist = @$playlist;
	my $track = shift(@playlist);

	$client->master->pluginData(playlist => \@playlist);

	$song->bitrate( $track->{'audioUrlMap'}->{'highQuality'}->{'bitrate'} * 1000);
	$song->duration( $track->{'trackLength'});
	$song->pluginData( $track );
	$song->streamUrl( $track->{'audioUrlMap'}->{'highQuality'}->{'audioUrl'});
	$callback->();
}

# Metadata for a URL, used by CLI/JSON clients
sub getMetadataFor {
	my ( $class, $client, $url, $forceCurrent ) = @_;

	my $song = $forceCurrent ? $client->streamingSong() : $client->playingSong();
	return {} unless $song;

	my $icon = $class->getIcon();

	my $bitrate = $song->bitrate ? ($song->bitrate/1000) . 'k CBR' : '128k CBR';

	# Could be somewhere else in the playlist
	if ($song->track->url ne $url) {
		main::DEBUGLOG && $log->debug($url);
		return {
			icon    => $icon,
			cover   => $icon,
			bitrate => $bitrate,
			type    => 'MP3 (Pandora)',
			title   => 'Pandora',
			album   => Slim::Music::Info::standardTitle( $client, $url, undef ),
		};
	}

	my $track = $song->pluginData();
	if ( $track && %$track ) {
		return {
			artist      => $track->{artistName},
			album       => $track->{albumName},
			title       => $track->{songName},
			cover       => $track->{albumArtUrl} || $defaultArtURL,
			icon        => $icon,
			replay_gain => $track->{trackGain},
			duration    => $track->{trackLength},
			bitrate     => $bitrate,
			type        => 'MP3 (Pandora)',
			info_link   => 'plugins/pandoradirect/trackinfo.html',
			buttons     => {
				# disable REW/Previous button
				rew => 0,
				# disable FWD when you've reached skip limit
				#fwd => canSkip($client) ? 1 : 0,
				fwd => 0,
				# replace repeat with Thumbs Up
				#repeat  => {
				#	icon    => 'html/images/btn_thumbs_up.gif',
				#	jiveStyle => $track->{allowFeedback} ? 'thumbsUp' : 'thumbsUpDisabled',
				#	tooltip => $client->string('PLUGIN_PANDORA_I_LIKE'),
				#	command => $track->{allowFeedback} ? [ 'pandora', 'rate', 1 ] : [ 'jivedummycommand' ],
				#},
				repeat => 0,

				# replace shuffle with Thumbs Down
				#shuffle => {
				#	icon    => 'html/images/btn_thumbs_down.gif',
				#	jiveStyle => $track->{allowFeedback} ? 'thumbsDown' : 'thumbsDownDisabled',
				#	tooltip => $client->string('PLUGIN_PANDORA_I_DONT_LIKE'),
				#	command => $track->{allowFeedback} ? [ 'pandora', 'rate', 0 ] : [ 'jivedummycommand' ],
				#},
				shuffle => 0,
			}
		};
	}
	else {
		return {
			icon    => $icon,
			cover   => $icon,
			bitrate => $bitrate,
			type    => 'MP3 (Pandora)',
			title   => $song->track()->title(),
		};
	}
}

sub getIcon {
	my ( $class, $url ) = @_;

	return Slim::Plugin::Pandora::Plugin->_pluginDataFor('icon');
}

1;