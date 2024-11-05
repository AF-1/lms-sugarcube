package Plugins::SugarCube::PlayerSettings;

use strict;
use base qw(Slim::Web::Settings);
use Plugins::SugarCube::Plugin;
use Slim::Utils::Prefs;
use Slim::Utils::Log;
use Slim::Utils::DateTime;
use LWP::UserAgent;

my $prefs = preferences('plugin.SugarCube');
my %filterHash = ();
my %GenresHash = ();
my %ReceipesHash = ();
my %ArtistsHash = ();
my $timeoutvalue = 4;

my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.sugarcube',
	'defaultLevel' => 'WARN',
	'description'  => getDisplayName(),
});
sub getDisplayName {
	return 'PLUGIN_SUGARCUBE';
}
sub needsClient {
	return 1;
}

sub name {
	return Slim::Web::HTTP::CSRF->protectName('PLUGIN_SUGARCUBE');
}

sub page {
	return Slim::Web::HTTP::CSRF->protectURI('plugins/SugarCube/settings/player.html');
}

sub prefs {
	my ($class,$client) = @_;
	return ($prefs->client($client), qw(scroll fdays));
}

sub handler {
	my ($class, $client, $params, $callback, @args) = @_;
	if ($params->{'saveSettings'})
	{			# Save routine.. pull out the form and save them to disk

		my $sugarcube_dupper = $params->{'sugarcube_dupper'};
		$prefs->client($client)->set('sugarcube_dupper', "$sugarcube_dupper");		

		my $sugarcube_fade_time = $params->{'sugarcube_fade_time'};
		$prefs->client($client)->set('sugarcube_fade_time', "$sugarcube_fade_time");		# Fade timeline
	
		my $sugarcube_fade_on_off = $params->{'sugarcube_fade_on_off'};
		$prefs->client($client)->set('sugarcube_fade_on_off', "$sugarcube_fade_on_off");		# Fade or not fade

		my $sugarcube_mode = $params->{'sugarcube_mode'};
		$prefs->client($client)->set('sugarcube_mode', "$sugarcube_mode");		# Standard MusicIP or Freestyle mode
	
		my $sugarcube_vintage = $params->{'sugarcube_vintage'};
		$prefs->client($client)->set('sugarcube_vintage', "$sugarcube_vintage");

		my $sugarcube_wobble = $params->{'sugarcube_wobble'};
		$prefs->client($client)->set('sugarcube_wobble', "$sugarcube_wobble");

		my $sugarcube_alarm_type = $params->{'sugarcube_alarm_type'};
		$prefs->client($client)->set('sugarcube_alarm_type', "$sugarcube_alarm_type");
		
		my $scalarm_filter = $params->{'scalarm_filter'};
		$prefs->client($client)->set('scalarm_filter', "$scalarm_filter");

		my $sugarcube_status = $params->{'sugarcube_status'};
		$prefs->client($client)->set('sugarcube_status', "$sugarcube_status");

		my $sugarcube_upnext = $params->{'sugarcube_upnext'};
		$prefs->client($client)->set('sugarcube_upnext', "$sugarcube_upnext");
		
		my $sugarcube_style = $params->{'sugarcube_style'};
		$prefs->client($client)->set('sugarcube_style', "$sugarcube_style");

		my $sugarcube_variety = $params->{'sugarcube_variety'};
		$prefs->client($client)->set('sugarcube_variety', "$sugarcube_variety");
		
		my $sugarcube_album_song = $params->{'sugarcube_album_song'};
		$prefs->client($client)->set('sugarcube_album_song', "$sugarcube_album_song");
		
		my $sugarcube_mix_type = $params->{'sugarcube_mix_type'};
		$prefs->client($client)->set('sugarcube_mix_type', "$sugarcube_mix_type");

		my $sugarcube_restrict_genre = $params->{'sugarcube_restrict_genre'};
		$prefs->client($client)->set('sugarcube_restrict_genre', "$sugarcube_restrict_genre");
		
		my $sugarcube_receipes = $params->{'sugarcube_receipes'};
		$prefs->client($client)->set('sugarcube_receipes', "$sugarcube_receipes");

		my $sugarcube_genre = $params->{'sugarcube_genre'};
		$prefs->client($client)->set('sugarcube_genre', "$sugarcube_genre");
		
		my $sugarcube_artist = $params->{'sugarcube_artist'};
		$prefs->client($client)->set('sugarcube_artist', "$sugarcube_artist");

		my $sugarcube_morningfilter = $params->{'sugarcube_morningfilter'};
		$prefs->client($client)->set('sugarcube_morningfilter', "$sugarcube_morningfilter");
		
		my $sugarcube_dayfilter = $params->{'sugarcube_dayfilter'};
		$prefs->client($client)->set('sugarcube_dayfilter', "$sugarcube_dayfilter");
		
		my $sugarcube_eveningfilter = $params->{'sugarcube_eveningfilter'};
		$prefs->client($client)->set('sugarcube_eveningfilter', "$sugarcube_eveningfilter");
		
		my $sugarcube_filteractive = $params->{'sugarcube_filteractive'};
		$prefs->client($client)->set('sugarcube_filteractive', "$sugarcube_filteractive");
		
		my $sugarcube_shuffle = $params->{'sugarcube_shuffle'};
		$prefs->client($client)->set('sugarcube_shuffle', "$sugarcube_shuffle");

		my $sugarcube_remembertracks = $params->{'sugarcube_remembertracks'};
		$prefs->client($client)->set('sugarcube_remembertracks', "$sugarcube_remembertracks");
		
		my $sugarcube_clear = $params->{'sugarcube_clear'};
		$prefs->client($client)->set('sugarcube_clear', "$sugarcube_clear");
		
		my $sugarcube_volume_flag = $params->{'sugarcube_volume_flag'};
		$prefs->client($client)->set('sugarcube_volume_flag', "$sugarcube_volume_flag");

		my $sugarcube_volumetimefrom = $params->{'sugarcube_volumetimefrom'};
		$prefs->client($client)->set('sugarcube_volumetimefrom', "$sugarcube_volumetimefrom");
		
		my $sugarcube_volumetimeto = $params->{'sugarcube_volumetimeto'};
		$prefs->client($client)->set('sugarcube_volumetimeto', "$sugarcube_volumetimeto");

		my $sugarcube_reducevolume = $params->{'sugarcube_reducevolume'};
		$prefs->client($client)->set('sugarcube_reducevolume', "$sugarcube_reducevolume");

		my $sugarcube_sleep = $params->{'sugarcube_sleep'};
		$prefs->client($client)->set('sugarcube_sleep', "$sugarcube_sleep");
		
		my $sugarcube_sleepfrom = $params->{'sugarcube_sleepfrom'};
		$prefs->client($client)->set('sugarcube_sleepfrom', "$sugarcube_sleepfrom");

		my $sugarcube_sleepto = $params->{'sugarcube_sleepto'};
		$prefs->client($client)->set('sugarcube_sleepto', "$sugarcube_sleepto");
		
		my $sugarcube_sleepduration = $params->{'sugarcube_sleepduration'};
		$prefs->client($client)->set('sugarcube_sleepduration', "$sugarcube_sleepduration");

		my $sugarcube_weighting = $params->{'sugarcube_weighting'};
		$prefs->client($client)->set('sugarcube_weighting', "$sugarcube_weighting");

		my $sugarcube_weightingtxt = $params->{'sugarcube_weightingtxt'};
		$prefs->client($client)->set('sugarcube_weightingtxt', "$sugarcube_weightingtxt");
		
		my $scblockgenre_always = $params->{'scblockgenre_always'};
		$prefs->client($client)->set('scblockgenre_always', "$scblockgenre_always");

		my $scblockgenre_alwaystwo = $params->{'scblockgenre_alwaystwo'};
		$prefs->client($client)->set('scblockgenre_alwaystwo', "$scblockgenre_alwaystwo");

		my $scblockgenre_alwaysthree = $params->{'scblockgenre_alwaysthree'};
		$prefs->client($client)->set('scblockgenre_alwaysthree', "$scblockgenre_alwaysthree");

		my $scalarm_genre = $params->{'scalarm_genre'};
		$prefs->client($client)->set('scalarm_genre', "$scalarm_genre");
		
		my $sugarcube_vartist = $params->{'sugarcube_vartist'};
		$prefs->client($client)->set('sugarcube_vartist', "$sugarcube_vartist");

		my $sugarcube_fade = $params->{'sugarcube_fade'};
		$prefs->client($client)->set('sugarcube_fade', "$sugarcube_fade");

		my $sugarcube_blockartist = $params->{'sugarcube_blockartist'};
		$prefs->client($client)->set('sugarcube_blockartist', "$sugarcube_blockartist");

		my $sugarcube_blockalbum = $params->{'sugarcube_blockalbum'};
		$prefs->client($client)->set('sugarcube_blockalbum', "$sugarcube_blockalbum");
		
		my $sugarcube_ts_recentplayed = $params->{'sugarcube_ts_recentplayed'};
		$prefs->client($client)->set('sugarcube_ts_recentplayed', "$sugarcube_ts_recentplayed");
		
		my $sugarcube_ts_playcount = $params->{'sugarcube_ts_playcount'};
		$prefs->client($client)->set('sugarcube_ts_playcount', "$sugarcube_ts_playcount");

		my $sugarcube_ts_rating = $params->{'sugarcube_ts_rating'};
		$prefs->client($client)->set('sugarcube_ts_rating', "$sugarcube_ts_rating");

		my $sugarcube_ts_lastplayed = $params->{'sugarcube_ts_lastplayed'};
		$prefs->client($client)->set('sugarcube_ts_lastplayed', "$sugarcube_ts_lastplayed");

		my $sugarcube_dynamicq = $params->{'sugarcube_dynamicq'};
		$prefs->client($client)->set('sugarcube_dynamicq', "$sugarcube_dynamicq");
		
		my $scblockartist_always = $params->{'scblockartist_always'};
		$prefs->client($client)->set('scblockartist_always', "$scblockartist_always");

		my $scblockartist_alwaystwo = $params->{'scblockartist_alwaystwo'};
		$prefs->client($client)->set('scblockartist_alwaystwo', "$scblockartist_alwaystwo");
		
		my $scblockartist_alwaysthree = $params->{'scblockartist_alwaysthree'};
		$prefs->client($client)->set('scblockartist_alwaysthree', "$scblockartist_alwaysthree");

		my $sugarcube_filetype = $params->{'sugarcube_filetype'};				# Flac or MP3 used in FreeStyle Mode
		$prefs->client($client)->set('sugarcube_filetype',"$sugarcube_filetype");		

		my $sugarcube_year_on_off = $params->{'sugarcube_year_on_off'};
		$prefs->client($client)->set('sugarcube_year_on_off',"$sugarcube_year_on_off");	# 0=any 1=strict 2=allow empty	

		my $sugarcube_startyear = $params->{'sugarcube_startyear'};
		$prefs->client($client)->set('sugarcube_startyear',"$sugarcube_startyear");	# FS Start Year	
		
		my $sugarcube_endyear = $params->{'sugarcube_endyear'};
		$prefs->client($client)->set('sugarcube_endyear',"$sugarcube_endyear");		# FS End Year
	
		my $sugarcube_fs_length = $params->{'sugarcube_fs_length'};
		$prefs->client($client)->set('sugarcube_fs_length',"$sugarcube_fs_length");		# FS Length
	
		my $sugarcube_display = $params->{'sugarcube_display'};
		$prefs->client($client)->set('sugarcube_display', "$sugarcube_display");

		my $sugarcube_ts_pc_higher = $params->{'sugarcube_ts_pc_higher'};
		$prefs->client($client)->set('sugarcube_ts_pc_higher', "$sugarcube_ts_pc_higher");
		
		my $sugarcube_ts_trackrated = $params->{'sugarcube_ts_trackrated'};
		$prefs->client($client)->set('sugarcube_ts_trackrated', "$sugarcube_ts_trackrated");

		my $sugarcube_clearstats = $params->{'sugarcube_clearstats'};
		if ($sugarcube_clearstats == 1) {
			$prefs->client($client)->set('sugarcube_trackcount',0);
			$prefs->client($client)->set('sugarcube_randomcount',0);
			$log->info("SugarCube Statistics Reset\n");
		}
		
		my $sugarcube_sn = $params->{'sugarcube_sn'};
		$prefs->client($client)->set('sugarcube_sn', "$sugarcube_sn");
		
		my $sugarcube_clutter = $params->{'sugarcube_clutter'};
		$prefs->client($client)->set('sugarcube_clutter', "$sugarcube_clutter");
		
		my $sugarcube_albumoveride = $params->{'sugarcube_albumoveride'};
		$prefs->client($client)->set('sugarcube_albumoveride', "$sugarcube_albumoveride");

		my $sugarcube_megasaver = $params->{'sugarcube_megasaver'};
		if ($sugarcube_megasaver == 1) {
		# MEGA SAVE START
			foreach my $player (Slim::Player::Client::clients()) {
				$prefs->client($player)->set('sugarcube_vintage', "$sugarcube_vintage");
				$prefs->client($player)->set('sugarcube_wobble', "$sugarcube_wobble");
				$prefs->client($player)->set('sugarcube_alarm_type', "$sugarcube_alarm_type");
				$prefs->client($player)->set('scalarm_filter', "$scalarm_filter");
				$prefs->client($player)->set('sugarcube_status', "$sugarcube_status");
				$prefs->client($player)->set('sugarcube_upnext', "$sugarcube_upnext");
				$prefs->client($player)->set('sugarcube_style', "$sugarcube_style");
				$prefs->client($player)->set('sugarcube_variety', "$sugarcube_variety");
				$prefs->client($player)->set('sugarcube_album_song', "$sugarcube_album_song");
				$prefs->client($player)->set('sugarcube_mix_type', "$sugarcube_mix_type");
				$prefs->client($player)->set('sugarcube_restrict_genre', "$sugarcube_restrict_genre");
				$prefs->client($player)->set('sugarcube_receipes', "$sugarcube_receipes");
				$prefs->client($player)->set('sugarcube_genre', "$sugarcube_genre");
				$prefs->client($player)->set('sugarcube_artist', "$sugarcube_artist");
				$prefs->client($player)->set('sugarcube_morningfilter', "$sugarcube_morningfilter");
				$prefs->client($player)->set('sugarcube_dayfilter', "$sugarcube_dayfilter");
				$prefs->client($player)->set('sugarcube_eveningfilter', "$sugarcube_eveningfilter");
				$prefs->client($player)->set('sugarcube_filteractive', "$sugarcube_filteractive");
				$prefs->client($player)->set('sugarcube_shuffle', "$sugarcube_shuffle");
				$prefs->client($player)->set('sugarcube_remembertracks', "$sugarcube_remembertracks");
				$prefs->client($player)->set('sugarcube_clear', "$sugarcube_clear");
				$prefs->client($player)->set('sugarcube_volume_flag', "$sugarcube_volume_flag");
				$prefs->client($player)->set('sugarcube_volumetimefrom', "$sugarcube_volumetimefrom");
				$prefs->client($player)->set('sugarcube_volumetimeto', "$sugarcube_volumetimeto");
				$prefs->client($player)->set('sugarcube_reducevolume', "$sugarcube_reducevolume");
				$prefs->client($player)->set('sugarcube_sleep', "$sugarcube_sleep");
				$prefs->client($player)->set('sugarcube_sleepfrom', "$sugarcube_sleepfrom");
				$prefs->client($player)->set('sugarcube_sleepto', "$sugarcube_sleepto");
				$prefs->client($player)->set('sugarcube_sleepduration', "$sugarcube_sleepduration");
				$prefs->client($player)->set('sugarcube_weighting', "$sugarcube_weighting");
				$prefs->client($player)->set('sugarcube_weightingtxt', "$sugarcube_weightingtxt");
				$prefs->client($player)->set('scblockgenre_always', "$scblockgenre_always");
				$prefs->client($player)->set('scblockgenre_alwaystwo', "$scblockgenre_alwaystwo");
				$prefs->client($player)->set('scblockgenre_alwaysthree', "$scblockgenre_alwaysthree");
				$prefs->client($player)->set('scalarm_genre', "$scalarm_genre");
				$prefs->client($player)->set('sugarcube_vartist', "$sugarcube_vartist");
				$prefs->client($player)->set('sugarcube_fade', "$sugarcube_fade");
				$prefs->client($player)->set('sugarcube_blockartist', "$sugarcube_blockartist");
				$prefs->client($player)->set('sugarcube_blockalbum', "$sugarcube_blockalbum");
				$prefs->client($player)->set('sugarcube_ts_recentplayed', "$sugarcube_ts_recentplayed");
				$prefs->client($player)->set('sugarcube_ts_playcount', "$sugarcube_ts_playcount");
				$prefs->client($player)->set('sugarcube_ts_rating', "$sugarcube_ts_rating");
				$prefs->client($player)->set('sugarcube_ts_lastplayed', "$sugarcube_ts_lastplayed");
				$prefs->client($player)->set('sugarcube_dynamicq', "$sugarcube_dynamicq");
				$prefs->client($player)->set('scblockartist_always', "$scblockartist_always");
				$prefs->client($player)->set('scblockartist_alwaystwo', "$scblockartist_alwaystwo");
				$prefs->client($player)->set('scblockartist_alwaysthree', "$scblockartist_alwaysthree");

				$prefs->client($client)->set('sugarcube_filetype',"$sugarcube_filetype");		# FreeStyle Mode (mp3/flac)

				$prefs->client($client)->set('sugarcube_mode', "$sugarcube_mode");		# Standard MusicIP or Freestyle mode

				$prefs->client($client)->set('sugarcube_year_on_off',"$sugarcube_year_on_off");	# 0=any 1=strict 2=allow empty	

				$prefs->client($client)->set('sugarcube_startyear',"$sugarcube_startyear");	# FS Start Year	
				$prefs->client($client)->set('sugarcube_endyear',"$sugarcube_endyear");		# FS End Year

				$prefs->client($client)->set('sugarcube_fs_length',"$sugarcube_fs_length");		# FS Length
				
				$prefs->client($player)->set('sugarcube_display', "$sugarcube_display");
				$prefs->client($player)->set('sugarcube_ts_pc_higher', "$sugarcube_ts_pc_higher");
				$prefs->client($player)->set('sugarcube_ts_trackrated', "$sugarcube_ts_trackrated");

				$prefs->client($client)->set('sugarcube_fade_on_off', "$sugarcube_fade_on_off");		# Fade or not fade
				$prefs->client($client)->set('sugarcube_fade_time', "$sugarcube_fade_time");		# Fade timeline
		
				$prefs->client($client)->set('sugarcube_dupper', "$sugarcube_dupper");		

				if ($sugarcube_clearstats == 1) {
					$prefs->client($player)->set('sugarcube_trackcount',0);
					$prefs->client($player)->set('sugarcube_randomcount',0);
				}
				$prefs->client($player)->set('sugarcube_sn', "$sugarcube_sn");
				$prefs->client($player)->set('sugarcube_clutter', "$sugarcube_clutter");
				$prefs->client($player)->set('sugarcube_albumoveride', "$sugarcube_albumoveride");
			}}
		# MEGA SAVE END	
		
		if ($sugarcube_status == 1) {		#  Additional Activities for SC Dis/Enabled
			Plugins::SugarCube::Plugin::SugarCubeEnabled($client);
		} else {
			Plugins::SugarCube::Plugin::SugarCubeDisabled($client);
		}
		
	}	# LOAD ROUTINE.. PULL IN DATA AND PUT IT INTO THE SCALARS
	
			my $master = Slim::Player::Sync::isMaster($client);  # Returns 1 if true
			my $slave = Slim::Player::Sync::isSlave($client);  # Returns 1 if true
			my $name = Slim::Player::Client::name($client);
			if ($master == 1) {
			$params->{'prefs'}->{'master'}  = "";
			} elsif ($slave == 1) {
			my $sync_master = $client->master()->name();			
			$params->{'prefs'}->{'master'}  = "#### Warning $name is a slave in sync group, make changes at $sync_master ####";
			} else {$params->{'prefs'}->{'master'}  = "";}

# Default set - minimum to work
	my $scube_style = $prefs->client($client)->get('sugarcube_style');
	my $scube_variety = $prefs->client($client)->get('sugarcube_variety');
	if ( $scube_style eq '' ) {
	$prefs->client($client)->set('sugarcube_style', 0);
	$log->debug("SugarCube MIP Style Setting not Set for this client, default set to 0\n");}
	
	if ( $scube_variety eq '' ) {
	$prefs->client($client)->set('sugarcube_variety', 0);
	$log->debug("SugarCube MIP Variety Setting not Set for this client, default set to 0\n");}
	
	my $sugarcube_blockartist = $prefs->client($client)->get('sugarcube_blockartist');
	if ( $sugarcube_blockartist eq '' ) {
	$prefs->client($client)->set('sugarcube_blockartist', 5);
	$log->debug("Block Artist, default set to 5\n");}
	
	my $sugarcube_blockalbum = $prefs->client($client)->get('sugarcube_blockalbum');
	if ( $sugarcube_blockalbum eq '' ) {
	$prefs->client($client)->set('sugarcube_blockalbum', 5);
	$log->debug("Block Album, default set to 5\n");}
	
	my $sugarcube_remembertracks = $prefs->client($client)->get('sugarcube_remembertracks');
	if ( $sugarcube_remembertracks eq '' ) {
	$prefs->client($client)->set('sugarcube_remembertracks', 6);
	$log->debug("Remember Tracks, default set to 6\n");}
	
	my $sugarcube_clutter = $prefs->client($client)->get('sugarcube_clutter');
	if ( $sugarcube_clutter eq '' ) {
	$prefs->client($client)->set('sugarcube_clutter', 5);
	$log->debug("Clutter, default set to 5\n");}
	
	
	my $sugarcube_mode = $prefs->client($client)->get('sugarcube_mode');
	if ( $sugarcube_mode eq '' ) {
	$prefs->client($client)->set('sugarcube_mode', 0);		# Standard MusicIP or Freestyle mode
		$log->debug("Default mode set to Standard MusicIP\n");}
	
	my $sugarcube_ts_lastplayed = $prefs->client($client)->get('sugarcube_ts_lastplayed');			
	my $sugarcube_ts_trackrated = $prefs->client($client)->get('sugarcube_ts_trackrated');	
	my $sugarcube_ts_pc_higher = $prefs->client($client)->get('sugarcube_ts_pc_higher');			
	my $sugarcube_ts_recentplayed = $prefs->client($client)->get('sugarcube_ts_recentplayed'); 
	my $sugarcube_ts_playcount = $prefs->client($client)->get('sugarcube_ts_playcount'); 
	my $sugarcube_ts_rating = $prefs->client($client)->get('sugarcube_ts_rating');	

	my $sugarcube_filetype = $prefs->client($client)->get('sugarcube_filetype');	# FreeStyle mp3/flac

	my $sugarcube_fade_on_off = $prefs->client($client)->get('sugarcube_fade_on_off');		# Fade or not fade

	my $sugarcube_fade_time = $prefs->client($client)->get('sugarcube_fade_time');		# Fade timeline
	if ( $sugarcube_fade_time eq '' ) {
	$prefs->client($client)->set('sugarcube_fade_time', 10);
	$log->debug("Fade time, default set to 10\n");}

	my $sugarcube_dupper = $prefs->client($client)->get('sugarcube_dupper');		
	
# TrackStat Settings default to 0 if not defined
	if ( $sugarcube_ts_trackrated eq '' ) {
			$log->debug("sugarcube_ts_trackrated; NOT defined\n");
			$prefs->client($client)->set('sugarcube_ts_trackrated', 0);
		}
	if ( $sugarcube_ts_lastplayed eq '' ) {
			$log->debug("sugarcube_ts_lastplayed; NOT defined\n");
			$prefs->client($client)->set('sugarcube_ts_lastplayed', 0);
		}
			if ( $sugarcube_ts_pc_higher eq '' ) {
			$log->debug("sugarcube_ts_pc_higher; NOT defined\n");
			$prefs->client($client)->set('sugarcube_ts_pc_higher', 0);
		}
				if ( $sugarcube_ts_recentplayed eq '' ) {
			$log->debug("sugarcube_ts_recentplayed; NOT defined\n");
			$prefs->client($client)->set('sugarcube_ts_recentplayed', 0);
		}  
					if ( $sugarcube_ts_playcount eq '' ) {
			$log->debug("sugarcube_ts_playcount; NOT defined\n");
			$prefs->client($client)->set('sugarcube_ts_playcount', 0);
		}  
					if ( $sugarcube_ts_rating eq '' ) {
			$log->debug("sugarcube_ts_rating; NOT defined\n");
			$prefs->client($client)->set('sugarcube_ts_rating', 0);
		}  
					if ( $sugarcube_fade_time eq '' ) {
			$log->debug("sugarcube_fade_time; NOT defined\n");
			$prefs->client($client)->set('sugarcube_fade_time', 10);
		}  
#
	$params->{'prefs'}->{'sugarcube_vintage'}  = $prefs->client($client)->get('sugarcube_vintage');
	$params->{'prefs'}->{'sugarcube_status'}  = $prefs->client($client)->get('sugarcube_status');
	$params->{'prefs'}->{'sugarcube_upnext'}  = $prefs->client($client)->get('sugarcube_upnext');
	$params->{'prefs'}->{'sugarcube_wobble'}  = $prefs->client($client)->get('sugarcube_wobble');
	$params->{'prefs'}->{'sugarcube_albumoveride'}  = $prefs->client($client)->get('sugarcube_albumoveride');
	$params->{'prefs'}->{'sugarcube_weighting'}  = $prefs->client($client)->get('sugarcube_weighting');	
	$params->{'prefs'}->{'sugarcube_weightingtxt'}  = $prefs->client($client)->get('sugarcube_weightingtxt');
	$params->{'prefs'}->{'sugarcube_style'}  = $prefs->client($client)->get('sugarcube_style');
	$params->{'prefs'}->{'sugarcube_variety'}  = $prefs->client($client)->get('sugarcube_variety');
	$params->{'prefs'}->{'sugarcube_album_song'}  = $prefs->client($client)->get('sugarcube_album_song');
	$params->{'prefs'}->{'sugarcube_mix_type'}  = $prefs->client($client)->get('sugarcube_mix_type');
	$params->{'prefs'}->{'sugarcube_restrict_genre'}  = $prefs->client($client)->get('sugarcube_restrict_genre');
	$params->{'prefs'}->{'scalarm_genre'}  = $prefs->client($client)->get('scalarm_genre');
	$params->{'prefs'}->{'sugarcube_dynamicq'}  = $prefs->client($client)->get('sugarcube_dynamicq');
	$params->{'prefs'}->{'sugarcube_filteractive'} = $prefs->client($client)->get('sugarcube_filteractive');	
	$params->{'prefs'}->{'sugarcube_receipes'}  = $prefs->client($client)->get('sugarcube_receipes');
	$params->{'prefs'}->{'sugarcube_genre'}  = $prefs->client($client)->get('sugarcube_genre');
	$params->{'prefs'}->{'sugarcube_artist'}  = $prefs->client($client)->get('sugarcube_artist');
	$params->{'prefs'}->{'sugarcube_morningfilter'}  = $prefs->client($client)->get('sugarcube_morningfilter');
	$params->{'prefs'}->{'sugarcube_dayfilter'}  = $prefs->client($client)->get('sugarcube_dayfilter');
	$params->{'prefs'}->{'sugarcube_eveningfilter'}  = $prefs->client($client)->get('sugarcube_eveningfilter');
	$params->{'prefs'}->{'sugarcube_shuffle'}  = $prefs->client($client)->get('sugarcube_shuffle');
	$params->{'prefs'}->{'sugarcube_remembertracks'}  = $prefs->client($client)->get('sugarcube_remembertracks');
	$params->{'prefs'}->{'sugarcube_clear'}  = $prefs->client($client)->get('sugarcube_clear');
	$params->{'prefs'}->{'sugarcube_volume_flag'}  = $prefs->client($client)->get('sugarcube_volume_flag');
	$params->{'prefs'}->{'sugarcube_volumetimefrom'}  = $prefs->client($client)->get('sugarcube_volumetimefrom');
	$params->{'prefs'}->{'sugarcube_volumetimeto'}  = $prefs->client($client)->get('sugarcube_volumetimeto');
	$params->{'prefs'}->{'sugarcube_reducevolume'}  = $prefs->client($client)->get('sugarcube_reducevolume');
	$params->{'prefs'}->{'sugarcube_sleep'}  = $prefs->client($client)->get('sugarcube_sleep');
	$params->{'prefs'}->{'sugarcube_sleepfrom'}  = $prefs->client($client)->get('sugarcube_sleepfrom');
	$params->{'prefs'}->{'sugarcube_sleepto'}  = $prefs->client($client)->get('sugarcube_sleepto');
	$params->{'prefs'}->{'sugarcube_sleepduration'} = $prefs->client($client)->get('sugarcube_sleepduration');
	$params->{'prefs'}->{'sugarcube_vartist'} = $prefs->client($client)->get('sugarcube_vartist');
	$params->{'prefs'}->{'scblockgenre_always'} = $prefs->client($client)->get('scblockgenre_always');
	$params->{'prefs'}->{'scblockgenre_alwaystwo'} = $prefs->client($client)->get('scblockgenre_alwaystwo');
	$params->{'prefs'}->{'scblockgenre_alwaysthree'} = $prefs->client($client)->get('scblockgenre_alwaysthree');
	$params->{'prefs'}->{'sugarcube_ts_pc_higher'} = $prefs->client($client)->get('sugarcube_ts_pc_higher');
	$params->{'prefs'}->{'sugarcube_blockartist'} = $prefs->client($client)->get('sugarcube_blockartist');
	$params->{'prefs'}->{'sugarcube_ts_recentplayed'} = $prefs->client($client)->get('sugarcube_ts_recentplayed');
	$params->{'prefs'}->{'sugarcube_ts_playcount'} = $prefs->client($client)->get('sugarcube_ts_playcount');
	$params->{'prefs'}->{'sugarcube_ts_rating'} = $prefs->client($client)->get('sugarcube_ts_rating');
	$params->{'prefs'}->{'scblockartist_always'} = $prefs->client($client)->get('scblockartist_always');
	$params->{'prefs'}->{'scblockartist_alwaystwo'} = $prefs->client($client)->get('scblockartist_alwaystwo');
	$params->{'prefs'}->{'scblockartist_alwaysthree'} = $prefs->client($client)->get('scblockartist_alwaysthree');
			
	$params->{'prefs'}->{'sugarcube_filetype'} = $prefs->client($client)->get('sugarcube_filetype');# Flac or MP3 used in FreeStyle Mode
	$params->{'prefs'}->{'sugarcube_startyear'} = $prefs->client($client)->get('sugarcube_startyear');	# FS Start Year	
	$params->{'prefs'}->{'sugarcube_endyear'} = $prefs->client($client)->get('sugarcube_endyear');	# FS End Year		
	$params->{'prefs'}->{'sugarcube_year_on_off'} = $prefs->client($client)->get('sugarcube_year_on_off');	# 0=any 1=strict 2=allow empty	

	$params->{'prefs'}->{'sugarcube_fs_length'} = $prefs->client($client)->get('sugarcube_fs_length');	# FS Length	
	
	$params->{'prefs'}->{'sugarcube_display'}  = $prefs->client($client)->get('sugarcube_display');
	$params->{'prefs'}->{'sugarcube_ts_trackrated'}  = $prefs->client($client)->get('sugarcube_ts_trackrated');
	$params->{'prefs'}->{'sugarcube_ts_lastplayed'}  = $prefs->client($client)->get('sugarcube_ts_lastplayed');
	$params->{'prefs'}->{'sugarcube_fade'}  = $prefs->client($client)->get('sugarcube_fade');
	$params->{'prefs'}->{'sugarcube_sn'}  = $prefs->client($client)->get('sugarcube_sn');
	$params->{'prefs'}->{'sugarcube_clutter'}  = $prefs->client($client)->get('sugarcube_clutter');
	$params->{'prefs'}->{'sugarcube_alarm_type'}  = $prefs->client($client)->get('sugarcube_alarm_type');
	$params->{'prefs'}->{'scalarm_filter'}  = $prefs->client($client)->get('scalarm_filter');	
	$params->{'prefs'}->{'sugarcube_blockalbum'}  = $prefs->client($client)->get('sugarcube_blockalbum');

	$params->{'prefs'}->{'sugarcube_mode'} = $prefs->client($client)->get('sugarcube_mode');		# Standard MusicIP or Freestyle mode
	
	$params->{'prefs'}->{'scubelicense'} = $prefs->get('scubelicense');

	$params->{'prefs'}->{'sugarcube_fade_on_off'} = $prefs->client($client)->get('sugarcube_fade_on_off');		# Fade or not fade
	
	$params->{'prefs'}->{'sugarcube_fade_time'} = $prefs->client($client)->get('sugarcube_fade_time');		# Fade timeline

	$params->{'prefs'}->{'sugarcube_dupper'} = $prefs->client($client)->get('sugarcube_dupper');	
	
	$params->{'filters'} = getFilterList();
	$params->{'genres'} = getGenresList();
	$params->{'receipes'} = getReceipesList();
	$params->{'artists'} = getArtistsList();

	return $class->SUPER::handler($client, $params);
}
sub isPluginsInstalled {
        my $client = shift;
        my $pluginList = shift;
        my $enabledPlugin = 1;
        foreach my $plugin (split /,/, $pluginList) {
                if($enabledPlugin) {
                        $enabledPlugin = grep(/$plugin/, Slim::Utils::PluginManager->enabledPlugins($client));
                }
        }
        return $enabledPlugin;
}
sub getPrefs {return $prefs;}
###
# FILTERS
#
#
sub getFilterList {
	my @filters    = ();
	my %filterHash = ();
	
	my $MMSport = $prefs->get('sugarport');
	my $miphosturl = $prefs->get('miphosturl');

	my $url = 'http://' . $miphosturl . ":$MMSport/api/filters";
	my $ua = LWP::UserAgent->new();
	$ua->timeout($timeoutvalue);
	my $http = $ua->get($url);		
	
	if ($http) {
		@filters = split(/\n/, $http->content);
	}
	my $none = sprintf('(%s)', Slim::Utils::Strings::string('NONE'));
	push @filters, $none;
	foreach my $filter ( @filters ) {
		if ($filter eq $none) {
			$filterHash{0} = $filter;
			next
		}
		$filterHash{$filter} = $filter;
	}
	if ($http->header("Client-Warning") =~ /Internal response/) {
		# did not reach the server at all
	$log->warn("\nMusicIP is NOT Running!");		
	$timeoutvalue = 2;
	}
	return \%filterHash;	
}

####
# GENRES
#
#
sub getGenresList {
	my @filters    = ();
	my %filterHash = ();
	
	my $MMSport = $prefs->get('sugarport');
	my $miphosturl = $prefs->get('miphosturl');

	my $url = 'http://' . $miphosturl . ":$MMSport/api/genres";
	my $ua = LWP::UserAgent->new();
	$ua->timeout($timeoutvalue);
	my $http = $ua->get($url);		
	
	if ($http) {
		@filters = split(/\n/, $http->content);
	}
	my $none = sprintf('(%s)', Slim::Utils::Strings::string('NONE'));
	push @filters, $none;
	foreach my $filter ( @filters ) {
		if ($filter eq $none) {
			$filterHash{0} = $filter;
			next
		}
		$filterHash{$filter} = $filter;
	}
	if ($http->header("Client-Warning") =~ /Internal response/) {
		# did not reach the server at all
	$log->warn("\nMusicIP is NOT Running!");		
	}
	return \%filterHash;
}
####
# ARTISTS
#
#
#
sub getArtistsList {
	my @filters    = ();
	my %filterHash = ();
	
	my $MMSport = $prefs->get('sugarport');
	my $miphosturl = $prefs->get('miphosturl');

	my $url = 'http://' . $miphosturl . ":$MMSport/api/artists";
	my $ua = LWP::UserAgent->new();
	$ua->timeout($timeoutvalue);
	my $http = $ua->get($url);		
	
	if ($http) {
		@filters = split(/\n/, $http->content);
	}
	my $none = sprintf('(%s)', Slim::Utils::Strings::string('NONE'));
	push @filters, $none;
	foreach my $filter ( @filters ) {
		if ($filter eq $none) {
			$filterHash{0} = $filter;
			next
		}
		$filterHash{$filter} = $filter;
	}
	if ($http->header("Client-Warning") =~ /Internal response/) {
		# did not reach the server at all
	$log->warn("\nMusicIP is NOT Running!");		
	}	
	
	return \%filterHash;
}
##### 
# RECEIPES
#
#
#
sub getReceipesList {
	my @filters    = ();
	my %filterHash = ();
	
	my $MMSport = $prefs->get('sugarport');
	my $miphosturl = $prefs->get('miphosturl');

	my $url = 'http://' . $miphosturl . ":$MMSport/api/recipes";
	my $ua = LWP::UserAgent->new();
	$ua->timeout($timeoutvalue);
	my $http = $ua->get($url);		
	
	if ($http) {
		@filters = split(/\n/, $http->content);
	}
	my $none = sprintf('(%s)', Slim::Utils::Strings::string('NONE'));
	push @filters, $none;
	foreach my $filter ( @filters ) {
		if ($filter eq $none) {
			$filterHash{0} = $filter;
			next
		}
		$filterHash{$filter} = $filter;
	}
	if ($http->header("Client-Warning") =~ /Internal response/) {
		# did not reach the server at all
	$log->warn("\nMusicIP is NOT Running!");		
	}
	return \%filterHash;
}
#

sub grabPlayers {
	my @players    = ();
	my %playersHash = ();
	my $a;
	my @players = Slim::Player::Client::clients();

	foreach my $client ( @players ) {
	for($a=0; $a<$#players+1; $a++) 
	{
	my $players = Slim::Player::Client::name($players[$a]);
		$playersHash{$players} = $players;
	}

	}
	return \%playersHash;
}


1;
__END__