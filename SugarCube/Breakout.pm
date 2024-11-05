# Breakout contain all the database calls
#
# In Summary
# Go to MIP to get tracks
# From the response get all the metadata
# Drop into a database
# Change status to DROP based on our criteria if recent album etc
# Tracks remaining that arent status DROP are OK to use
# Queue up one of them depending on our criteria

package Plugins::SugarCube::Breakout;

use strict;
use base qw(Slim::Web::Settings);
use Plugins::SugarCube::Plugin;
use Slim::Utils::Prefs;
use Slim::Utils::Log;
use Slim::Utils::DateTime;
use File::Spec::Functions qw(:ALL);
use DBI qw(:sql_types);

my $log = Slim::Utils::Log->addLogCategory(
    {
        'category'     => 'plugin.sugarcube',
        'defaultLevel' => 'WARN',
        'description'  => getDisplayName(),
    }
);

sub getDisplayName { return 'PLUGIN_SUGARCUBE'; }
my $prefs = preferences('plugin.SugarCube');

# Get a Random Track based on provided Genre
sub getRandom {
    my $client = shift;
    my $genre  = shift;
    my $scblockartist_always =
      $prefs->client($client)->get('scblockartist_always');
    my $scblockartist_alwaystwo =
      $prefs->client($client)->get('scblockartist_alwaystwo');
    my $scblockartist_alwaysthree =
      $prefs->client($client)->get('scblockartist_alwaysthree');

    my (
        $SCTRACKURL,   $CurrentArtist,   $CurrentTrack, $CurrentAlbum,
        $CurrentGenre, $CurrentAlbumArt, $FullAlbum
    );

    if ( $scblockartist_always eq "" ) {
        $scblockartist_always = 'Ignore Artist not Specified';
    }
    if ( $scblockartist_alwaystwo eq "" ) {
        $scblockartist_alwaystwo = 'Ignore Artist not Specified';
    }
    if ( $scblockartist_alwaysthree eq "" ) {
        $scblockartist_alwaysthree = 'Ignore Artist not Specified';
    }
    $log->debug(
"\nGet Random Track but block Artist $scblockartist_always plus $scblockartist_alwaystwo plus $scblockartist_alwaysthree"
    );

    my $dbh           = Slim::Schema->storage->dbh();
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    $genre                     = $dbh->quote($genre);
    $scblockartist_always      = $dbh->quote($scblockartist_always);
    $scblockartist_alwaystwo   = $dbh->quote($scblockartist_alwaystwo);
    $scblockartist_alwaysthree = $dbh->quote($scblockartist_alwaysthree);

    my $sql =
"SELECT tracks.url, contributors.name, tracks.title, albums.title, genres.name, tracks.coverid, tracks.album FROM albums INNER JOIN contributors ON (albums.contributor = contributors.id) INNER JOIN tracks ON (tracks.album = albums.id) INNER JOIN genre_track ON tracks.id = genre_track.track INNER JOIN genres ON genre_track.genre = genres.id WHERE genres.name = $genre AND contributors.name <> $scblockartist_always AND contributors.name <> $scblockartist_alwaystwo AND contributors.name <> $scblockartist_alwaysthree order by random() ASC limit 1";

    my $sth = $dbh->prepare($sql);
    $sth->execute();
    $sth->bind_col( 1, \$SCTRACKURL );
    $sth->bind_col( 2, \$CurrentArtist );
    $sth->bind_col( 3, \$CurrentTrack );
    $sth->bind_col( 4, \$CurrentAlbum );
    $sth->bind_col( 5, \$CurrentGenre );
    $sth->bind_col( 6, \$CurrentAlbumArt );
    $sth->bind_col( 7, \$FullAlbum );

    if ( $sth->fetch() ) {
        $SCTRACKURL = Slim::Utils::Unicode::utf8decode( $SCTRACKURL, 'utf8' );
        $CurrentArtist =
          Slim::Utils::Unicode::utf8decode( $CurrentArtist, 'utf8' );
        $CurrentTrack =
          Slim::Utils::Unicode::utf8decode( $CurrentTrack, 'utf8' );
        $CurrentAlbum =
          Slim::Utils::Unicode::utf8decode( $CurrentAlbum, 'utf8' );
        $CurrentGenre =
          Slim::Utils::Unicode::utf8decode( $CurrentGenre, 'utf8' );
        $CurrentAlbumArt =
          Slim::Utils::Unicode::utf8decode( $CurrentAlbumArt, 'utf8' );
        $FullAlbum = Slim::Utils::Unicode::utf8decode( $FullAlbum, 'utf8' );
    }

    $sth->finish();
    return (
        $SCTRACKURL,   $CurrentArtist,   $CurrentTrack, $CurrentAlbum,
        $CurrentGenre, $CurrentAlbumArt, $FullAlbum
    );
}

sub getalbum {
    my $client = shift;
    my $song   = shift;
    my $SCAlbum;

    my $dbh           = Slim::Schema->storage->dbh();
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    my $sth =
      $dbh->prepare('SELECT tracks.album FROM tracks WHERE tracks.url = ?');
    $sth->execute($song);
    $sth->bind_col( 1, \$SCAlbum );
    if ( $sth->fetch() ) {
        $SCAlbum = Slim::Utils::Unicode::utf8decode( $SCAlbum, 'utf8' );
    }
    $sth->finish();
    return ($SCAlbum);
}

sub getRealRandom {
    my $randomtrack;
    my $SCTitle;

    my $dbh           = Slim::Schema->storage->dbh();
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    my $sql = "SELECT tracks.url FROM tracks order by random() limit 1";

    my $sth = $dbh->prepare($sql);
    $sth->execute();
    $sth->bind_col( 1, \$randomtrack );
    if ( $sth->fetch() ) {
        $randomtrack = Slim::Utils::Unicode::utf8decode( $randomtrack, 'utf8' );
    }

    $sth->finish();
    return ($randomtrack);
}

# FreeStyle Mode Calls
# Select tracks between a year range
# SELECT tracks.url FROM tracks WHERE tracks.year >= "2004" AND tracks.year <="2009" order by random() limit 10
# Select supports file content type, normal (any) mp3 or flac
# Select Tracks ...Normal 0 tracks.secs >= 0 AND tracks.secs <= 18000
# Select Tracks ...Short 1 (5mins) tracks.secs >= 0 AND tracks.secs <= 300
# Select Tracks ...Long 2  (>5mins) tracks.secs >= 300 AND tracks.secs <= 18000

sub FSgetRealRandomSubsetYearRangeStrict {
    no warnings 'numeric';

    my $client = shift;

    my $sugarcube_startyear =
      $prefs->client($client)->get('sugarcube_startyear');
    my $sugarcube_endyear = $prefs->client($client)->get('sugarcube_endyear');

    if ( $sugarcube_startyear eq "" ) {
        $sugarcube_startyear = "1900";
    }
    if ( $sugarcube_endyear eq "" ) {
        $sugarcube_endyear = "2020";
    }

    my $sugarcube_filetype = $prefs->client($client)->get('sugarcube_filetype');

    if ( $sugarcube_filetype eq "" ) {
        $sugarcube_filetype == 0;    # Default Anything
    }

    my $sugarcube_fs_length =
      $prefs->client($client)->get('sugarcube_fs_length');    # Length of Track

    my $sugarcube_fs_length_low;
    my $sugarcube_fs_length_high;

    # Select Tracks ...Normal 0 tracks.secs >= 0 AND tracks.secs <= 18000
    if ( $sugarcube_fs_length eq "" || $sugarcube_fs_length == 0 ) {
        $sugarcube_fs_length_low  = '0';
        $sugarcube_fs_length_high = '18000';

# Select Tracks ...Short 1 (Block Intro Tracks) tracks.secs >= 60 AND tracks.secs <= 300
    }
    elsif ( $sugarcube_fs_length == 1 ) {
        $sugarcube_fs_length_low  = '60';
        $sugarcube_fs_length_high = '18000';

      # Select Tracks ...Short 2 (5mins) tracks.secs >= 0 AND tracks.secs <= 300
    }
    elsif ( $sugarcube_fs_length == 2 ) {
        $sugarcube_fs_length_low  = '0';
        $sugarcube_fs_length_high = '300';

  # Select Tracks ...Long 3 (>5mins) tracks.secs >= 300 AND tracks.secs <= 18000
    }
    elsif ( $sugarcube_fs_length == 3 ) {
        $sugarcube_fs_length_low  = '300';
        $sugarcube_fs_length_high = '18000';
    }

    my @myworkingset = ();

    my $dbh           = Slim::Schema->storage->dbh();
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    $sugarcube_startyear = $dbh->quote($sugarcube_startyear);
    $sugarcube_endyear   = $dbh->quote($sugarcube_endyear);

    $sugarcube_fs_length_low  = $dbh->quote($sugarcube_fs_length_low);
    $sugarcube_fs_length_high = $dbh->quote($sugarcube_fs_length_high);

    my $sql;

    if ( $sugarcube_filetype == 0 ) {   # Anything normal no file type filtering
        $sql =
"SELECT tracks.url FROM tracks WHERE tracks.year >= $sugarcube_startyear AND tracks.year <= $sugarcube_endyear AND tracks.secs >= $sugarcube_fs_length_low AND tracks.secs <= $sugarcube_fs_length_high order by random() limit 10";
    }
    elsif ( $sugarcube_filetype == 1 ) {    # mp3
        $sql =
"SELECT tracks.url FROM tracks WHERE tracks.year >= $sugarcube_startyear AND tracks.year <= $sugarcube_endyear AND tracks.secs >= $sugarcube_fs_length_low AND tracks.secs <= $sugarcube_fs_length_high AND tracks.content_type = 'mp3' order by random() limit 10";
    }
    elsif ( $sugarcube_filetype == 2 ) {    # flac
        $sql =
"SELECT tracks.url FROM tracks WHERE tracks.year >= $sugarcube_startyear AND tracks.year <= $sugarcube_endyear AND tracks.secs >= $sugarcube_fs_length_low AND tracks.secs <= $sugarcube_fs_length_high AND tracks.content_type = 'flac' order by random() limit 10";
    }

    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my $array_ref = $sth->fetchall_arrayref();
    foreach my $row (@$array_ref) {
        push @myworkingset, my ($url) = @$row;
    }

    $sth->finish();
    return @myworkingset;
}

# Select tracks between a year range take into account where no year is set
# SELECT tracks.url FROM tracks WHERE (tracks.year >= "2009" AND tracks.year <="2009") OR tracks.year = '' order by random() limit 10
# Select supports file content type, normal (any) mp3 or flac
# Select Tracks ...Normal 0 tracks.secs >= 0 AND tracks.secs <= 18000
# Select Tracks ...Short 1 (5mins) tracks.secs >= 0 AND tracks.secs <= 300
# Select Tracks ...Long 2  (>5mins) tracks.secs >= 300 AND tracks.secs <= 18000
sub FSgetRealRandomSubsetYearRangeAny {
    no warnings 'numeric';

    my $client = shift;

    my $sugarcube_startyear =
      $prefs->client($client)->get('sugarcube_startyear');
    my $sugarcube_endyear = $prefs->client($client)->get('sugarcube_endyear');

    if ( $sugarcube_startyear eq "" ) {
        $sugarcube_startyear = "1900";
    }
    if ( $sugarcube_endyear eq "" ) {
        $sugarcube_endyear = "2020";
    }

    my $sugarcube_filetype = $prefs->client($client)->get('sugarcube_filetype');

    if ( $sugarcube_filetype eq "" ) {
        $sugarcube_filetype == 0;    # Default Anything
    }

    my $sugarcube_fs_length =
      $prefs->client($client)->get('sugarcube_fs_length');    # Length of Track

    my $sugarcube_fs_length_low;
    my $sugarcube_fs_length_high;

    # Select Tracks ...Normal 0 tracks.secs >= 0 AND tracks.secs <= 18000
    if ( $sugarcube_fs_length eq "" || $sugarcube_fs_length == 0 ) {
        $sugarcube_fs_length_low  = '0';
        $sugarcube_fs_length_high = '18000';

# Select Tracks ...Short 1 (Block Intro Tracks) tracks.secs >= 60 AND tracks.secs <= 300
    }
    elsif ( $sugarcube_fs_length == 1 ) {
        $sugarcube_fs_length_low  = '60';
        $sugarcube_fs_length_high = '18000';

      # Select Tracks ...Short 2 (5mins) tracks.secs >= 0 AND tracks.secs <= 300
    }
    elsif ( $sugarcube_fs_length == 2 ) {
        $sugarcube_fs_length_low  = '0';
        $sugarcube_fs_length_high = '300';

 # Select Tracks ...Long 3  (>5mins) tracks.secs >= 300 AND tracks.secs <= 18000
    }
    elsif ( $sugarcube_fs_length == 3 ) {
        $sugarcube_fs_length_low  = '300';
        $sugarcube_fs_length_high = '18000';
    }

    my @myworkingset  = ();
    my $dbh           = Slim::Schema->storage->dbh();
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    $sugarcube_startyear = $dbh->quote($sugarcube_startyear);
    $sugarcube_endyear   = $dbh->quote($sugarcube_endyear);

    $sugarcube_fs_length_low  = $dbh->quote($sugarcube_fs_length_low);
    $sugarcube_fs_length_high = $dbh->quote($sugarcube_fs_length_high);

    my $sql;

    if ( $sugarcube_filetype == 0 ) {   # Anything normal no file type filtering
        $sql =
"SELECT tracks.url FROM tracks WHERE (tracks.year >= $sugarcube_startyear AND tracks.year <= $sugarcube_endyear) OR tracks.year = '' AND tracks.secs >= $sugarcube_fs_length_low AND tracks.secs <= $sugarcube_fs_length_high order by random() limit 10";
    }
    elsif ( $sugarcube_filetype == 1 ) {    # mp3
        $sql =
"SELECT tracks.url FROM tracks WHERE tracks.year >= $sugarcube_startyear AND tracks.year <= $sugarcube_endyear OR tracks.year = '' AND tracks.secs >= $sugarcube_fs_length_low AND tracks.secs <= $sugarcube_fs_length_high AND tracks.content_type = 'mp3' order by random() limit 10";
    }
    elsif ( $sugarcube_filetype == 2 ) {    # flac
        $sql =
"SELECT tracks.url FROM tracks WHERE tracks.year >= $sugarcube_startyear AND tracks.year <= $sugarcube_endyear OR tracks.year = '' AND tracks.secs >= $sugarcube_fs_length_low AND tracks.secs <= $sugarcube_fs_length_high AND tracks.content_type = 'flac' order by random() limit 10";
    }

    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my $array_ref = $sth->fetchall_arrayref();
    foreach my $row (@$array_ref) {
        push @myworkingset, my ($url) = @$row;
    }

    $sth->finish();
    return @myworkingset;
}

# Select Random Failback Tracks
# Select tracks either limited to mp3 or FLAC or allow anything
# Used in FreeStyle Mode
# 0 = Anything
# 1 = MP3
# 2 = FLAC
# Select Tracks ...Normal 0 tracks.secs >= 0 AND tracks.secs <= 18000
# Select Tracks ...Short 1 (5mins) tracks.secs >= 0 AND tracks.secs <= 300
# Select Tracks ...Long 2  (>5mins) tracks.secs >= 300 AND tracks.secs <= 18000
sub FSgetRealRandomSubset {
    no warnings 'numeric';

    my $client = shift;

    my @myworkingset = ();

    my $sugarcube_filetype = $prefs->client($client)->get('sugarcube_filetype');

    if ( $sugarcube_filetype eq "" ) {
        $sugarcube_filetype == 0;    # Default Anything
    }

    my $sugarcube_fs_length =
      $prefs->client($client)->get('sugarcube_fs_length');    # Length of Track

    my $sugarcube_fs_length_low;
    my $sugarcube_fs_length_high;

    # Select Tracks ...Normal 0 tracks.secs >= 0 AND tracks.secs <= 18000
    if ( $sugarcube_fs_length eq "" || $sugarcube_fs_length == 0 ) {
        $sugarcube_fs_length_low  = '0';
        $sugarcube_fs_length_high = '18000';

# Select Tracks ...Short 1 (Block Intro Tracks) tracks.secs >= 60 AND tracks.secs <= 300
    }
    elsif ( $sugarcube_fs_length == 1 ) {
        $sugarcube_fs_length_low  = '60';
        $sugarcube_fs_length_high = '18000';

      # Select Tracks ...Short 2 (5mins) tracks.secs >= 0 AND tracks.secs <= 300
    }
    elsif ( $sugarcube_fs_length == 2 ) {
        $sugarcube_fs_length_low  = '0';
        $sugarcube_fs_length_high = '300';

 # Select Tracks ...Long 3  (>5mins) tracks.secs >= 300 AND tracks.secs <= 18000
    }
    elsif ( $sugarcube_fs_length == 3 ) {
        $sugarcube_fs_length_low  = '300';
        $sugarcube_fs_length_high = '18000';
    }

    my $dbh           = Slim::Schema->storage->dbh();
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    $sugarcube_fs_length_low  = $dbh->quote($sugarcube_fs_length_low);
    $sugarcube_fs_length_high = $dbh->quote($sugarcube_fs_length_high);

    my $sql;

    if ( $sugarcube_filetype == 0 ) {   # Anything normal no file type filtering
        $sql =
"SELECT tracks.url FROM tracks WHERE tracks.secs >= $sugarcube_fs_length_low AND tracks.secs <= $sugarcube_fs_length_high order by random() limit 10";
    }
    elsif ( $sugarcube_filetype == 1 ) {    # mp3
        $sql =
"SELECT tracks.url FROM tracks WHERE tracks.content_type = 'mp3' AND tracks.secs >= $sugarcube_fs_length_low AND tracks.secs <= $sugarcube_fs_length_high order by random() limit 10";
    }
    elsif ( $sugarcube_filetype == 2 ) {    # flac
        $sql =
"SELECT tracks.url FROM tracks WHERE tracks.content_type = 'flac' AND tracks.secs >= $sugarcube_fs_length_low AND tracks.secs <= $sugarcube_fs_length_high order by random() limit 10";
    }

    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my $array_ref = $sth->fetchall_arrayref();
    foreach my $row (@$array_ref) {
        push @myworkingset, my ($url) = @$row;
    }

    $sth->finish();
    return @myworkingset;
}

#TrackStat
sub getTSSongDetails {
    my ($song, $TSenabled, $sugarlvTS) = @_;
    my (
        $CurrentArtist, $CurrentTrack,    $CurrentAlbum,
        $CurrentGenre,  $CurrentAlbumArt, $FullAlbum,
        $PC,            $Rat,             $LP
    );

    my $dbh           = Slim::Schema->storage->dbh();
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

	my $statsSource = (($sugarlvTS == 1) || !$TSenabled) ? "tracks_persistent" : "track_statistics"; # 1 = LMS, 2 = TS
    my $sth = $dbh->prepare(
'SELECT contributors.name, tracks.title, albums.title, genres.name, tracks.coverid, tracks.album, $statsSource.playCount, $statsSource.rating, $statsSource.lastPlayed FROM albums INNER JOIN contributors ON (albums.contributor = contributors.id) INNER JOIN tracks ON (tracks.album = albums.id)  INNER JOIN genres ON (genre_track.genre = genres.id) INNER JOIN genre_track ON (genre_track.track = tracks.id) INNER JOIN $statsSource ON (tracks.urlmd5 = $statsSource.urlmd5) where tracks.url = ?'
    );

    $sth->execute($song);
    $sth->bind_col( 1, \$CurrentArtist );
    $sth->bind_col( 2, \$CurrentTrack );
    $sth->bind_col( 3, \$CurrentAlbum );
    $sth->bind_col( 4, \$CurrentGenre );
    $sth->bind_col( 5, \$CurrentAlbumArt );
    $sth->bind_col( 6, \$FullAlbum );
    $sth->bind_col( 7, \$PC );
    $sth->bind_col( 8, \$Rat );
    $sth->bind_col( 9, \$LP );

    if ( $sth->fetch() ) {

        if ( $PC eq '' ) {
            $PC = 'Never Played';
        }
        if ( $Rat eq '' ) {
            $Rat = 'Not Rated';
        }

        if ( $LP == -1 ) {
            $LP = 'Never Played';
        }
        else {
            $LP = localtime($LP);
            my $testdate = index( $LP, "1970" );
            if ( $testdate != -1 ) { $LP = "Never Played"; }
        }

        $CurrentArtist =
          Slim::Utils::Unicode::utf8decode( $CurrentArtist, 'utf8' );
        $CurrentTrack =
          Slim::Utils::Unicode::utf8decode( $CurrentTrack, 'utf8' );
        $CurrentAlbum =
          Slim::Utils::Unicode::utf8decode( $CurrentAlbum, 'utf8' );
        $CurrentGenre =
          Slim::Utils::Unicode::utf8decode( $CurrentGenre, 'utf8' );
        $CurrentAlbumArt =
          Slim::Utils::Unicode::utf8decode( $CurrentAlbumArt, 'utf8' );
        $FullAlbum = Slim::Utils::Unicode::utf8decode( $FullAlbum, 'utf8' );
        $PC        = Slim::Utils::Unicode::utf8decode( $PC,        'utf8' );
        $Rat       = Slim::Utils::Unicode::utf8decode( $Rat,       'utf8' );
        $LP        = Slim::Utils::Unicode::utf8decode( $LP,        'utf8' );
    }

    $sth->finish();

    return (
        $CurrentArtist, $CurrentTrack,    $CurrentAlbum,
        $CurrentGenre,  $CurrentAlbumArt, $FullAlbum,
        $PC,            $Rat,             $LP
    );
}

sub getmyTSNextSong {
    no warnings 'numeric';

    my ($client, $TSenabled, $sugarlvTS) = @_;
    my $song;
    my (
        $CurrentArtist, $CurrentTrack,    $CurrentAlbum,
        $CurrentGenre,  $CurrentAlbumArt, $FullAlbum,
        $PC,            $Rat,             $LP
    );
    my $songIndex = Slim::Player::Source::streamingSongIndex($client);
    $songIndex++;
    my $listlength = Slim::Player::Playlist::count($client);
    if ( $songIndex == $listlength ) { $songIndex--; }
    my $url = Slim::Player::Playlist::song( $client, $songIndex );
    my $track = Slim::Schema->rs('Track')->objectForUrl(
        {
            'url' => $url,
        }
    );
    my $trackid = $track->id;

    my $dbh           = Slim::Schema->storage->dbh();
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

	my $statsSource = (($sugarlvTS == 1) || !$TSenabled) ? "tracks_persistent" : "track_statistics"; # 1 = LMS, 2 = TS
    my $sth = $dbh->prepare(
'SELECT contributors.name, tracks.title, albums.title, genres.name, tracks.coverid, tracks.album, $statsSource.playCount, $statsSource.rating, $statsSource.lastPlayed FROM albums INNER JOIN contributors ON (albums.contributor = contributors.id) INNER JOIN tracks ON (tracks.album = albums.id)  INNER JOIN genres ON (genre_track.genre = genres.id) INNER JOIN genre_track ON (genre_track.track = tracks.id) INNER JOIN $statsSource ON (tracks.urlmd5 = $statsSource.urlmd5) where tracks.id = ?'
    );

    $sth->execute($trackid);
    $sth->bind_col( 1, \$CurrentArtist );
    $sth->bind_col( 2, \$CurrentTrack );
    $sth->bind_col( 3, \$CurrentAlbum );
    $sth->bind_col( 4, \$CurrentGenre );
    $sth->bind_col( 5, \$CurrentAlbumArt );
    $sth->bind_col( 6, \$FullAlbum );
    $sth->bind_col( 7, \$PC );
    $sth->bind_col( 8, \$Rat );
    $sth->bind_col( 9, \$LP );

    if ( $sth->fetch() ) {

        if ( $PC eq '' ) {
            $PC = 'Never Played';
        }
        if ( $Rat eq '' ) {
            $Rat = 'Not Rated';
        }

        if ( $LP == -1 ) {
            $LP = 'Never Played';
        }
        else {
            $LP = localtime($LP);
            my $testdate = index( $LP, "1970" );
            if ( $testdate != -1 ) { $LP = "Never Played"; }
        }

        $CurrentArtist =
          Slim::Utils::Unicode::utf8decode( $CurrentArtist, 'utf8' );
        $CurrentTrack =
          Slim::Utils::Unicode::utf8decode( $CurrentTrack, 'utf8' );
        $CurrentAlbum =
          Slim::Utils::Unicode::utf8decode( $CurrentAlbum, 'utf8' );
        $CurrentGenre =
          Slim::Utils::Unicode::utf8decode( $CurrentGenre, 'utf8' );
        $CurrentAlbumArt =
          Slim::Utils::Unicode::utf8decode( $CurrentAlbumArt, 'utf8' );
        $FullAlbum = Slim::Utils::Unicode::utf8decode( $FullAlbum, 'utf8' );
        $PC        = Slim::Utils::Unicode::utf8decode( $PC,        'utf8' );
        $Rat       = Slim::Utils::Unicode::utf8decode( $Rat,       'utf8' );
        $LP        = Slim::Utils::Unicode::utf8decode( $LP,        'utf8' );
    }

    $sth->finish();
    return (
        $CurrentArtist, $CurrentTrack,    $CurrentAlbum,
        $CurrentGenre,  $CurrentAlbumArt, $FullAlbum,
        $PC,            $Rat,             $LP
    );
}

sub getSongDetails {
    my $song = shift;
    my (
        $CurrentArtist, $CurrentTrack,    $CurrentAlbum,
        $CurrentGenre,  $CurrentAlbumArt, $FullAlbum
    );

    my $dbh           = Slim::Schema->storage->dbh();
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    my $sth = $dbh->prepare(
'SELECT contributors.name, tracks.title, albums.title, genres.name, tracks.coverid, tracks.album FROM albums INNER JOIN contributors ON (albums.contributor = contributors.id) INNER JOIN tracks ON (tracks.album = albums.id)  INNER JOIN genres ON (genre_track.genre = genres.id) INNER JOIN genre_track ON (genre_track.track = tracks.id) where tracks.url = ?'
    );
    $sth->execute($song);
    $sth->bind_col( 1, \$CurrentArtist );
    $sth->bind_col( 2, \$CurrentTrack );
    $sth->bind_col( 3, \$CurrentAlbum );
    $sth->bind_col( 4, \$CurrentGenre );
    $sth->bind_col( 5, \$CurrentAlbumArt );
    $sth->bind_col( 6, \$FullAlbum );

    if ( $sth->fetch() ) {
        $CurrentArtist =
          Slim::Utils::Unicode::utf8decode( $CurrentArtist, 'utf8' );
        $CurrentTrack =
          Slim::Utils::Unicode::utf8decode( $CurrentTrack, 'utf8' );
        $CurrentAlbum =
          Slim::Utils::Unicode::utf8decode( $CurrentAlbum, 'utf8' );
        $CurrentGenre =
          Slim::Utils::Unicode::utf8decode( $CurrentGenre, 'utf8' );
        $CurrentAlbumArt =
          Slim::Utils::Unicode::utf8decode( $CurrentAlbumArt, 'utf8' );
        $FullAlbum = Slim::Utils::Unicode::utf8decode( $FullAlbum, 'utf8' );
    }

    $sth->finish();
    return (
        $CurrentArtist, $CurrentTrack,    $CurrentAlbum,
        $CurrentGenre,  $CurrentAlbumArt, $FullAlbum
    );
}

sub getmyNextSong {
    no warnings 'numeric';

    my $client = shift;
    my $song;
    my (
        $CurrentArtist, $CurrentTrack,    $CurrentAlbum,
        $CurrentGenre,  $CurrentAlbumArt, $FullAlbum
    );
    my $songIndex = Slim::Player::Source::streamingSongIndex($client);
    $songIndex++;
    my $listlength = Slim::Player::Playlist::count($client);
    if ( $songIndex == $listlength ) { $songIndex--; }
    my $url = Slim::Player::Playlist::song( $client, $songIndex );
    my $track = Slim::Schema->rs('Track')->objectForUrl(
        {
            'url' => $url,
        }
    );
    my $trackid = $track->id;

    my $dbh           = Slim::Schema->storage->dbh();
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    my $sth = $dbh->prepare(
'SELECT contributors.name, tracks.title, albums.title, genres.name, tracks.coverid, tracks.album FROM albums INNER JOIN contributors ON (albums.contributor = contributors.id) INNER JOIN tracks ON (tracks.album = albums.id)  INNER JOIN genres ON (genre_track.genre = genres.id) INNER JOIN genre_track ON (genre_track.track = tracks.id) where tracks.id = ?'
    );
    $sth->execute($trackid);
    $sth->bind_col( 1, \$CurrentArtist );
    $sth->bind_col( 2, \$CurrentTrack );
    $sth->bind_col( 3, \$CurrentAlbum );
    $sth->bind_col( 4, \$CurrentGenre );
    $sth->bind_col( 5, \$CurrentAlbumArt );
    $sth->bind_col( 6, \$FullAlbum );

    if ( $sth->fetch() ) {
        $CurrentArtist =
          Slim::Utils::Unicode::utf8decode( $CurrentArtist, 'utf8' );
        $CurrentTrack =
          Slim::Utils::Unicode::utf8decode( $CurrentTrack, 'utf8' );
        $CurrentAlbum =
          Slim::Utils::Unicode::utf8decode( $CurrentAlbum, 'utf8' );
        $CurrentGenre =
          Slim::Utils::Unicode::utf8decode( $CurrentGenre, 'utf8' );
        $CurrentAlbumArt =
          Slim::Utils::Unicode::utf8decode( $CurrentAlbumArt, 'utf8' );
        $FullAlbum = Slim::Utils::Unicode::utf8decode( $FullAlbum, 'utf8' );
    }

    $sth->finish();

    return (
        $CurrentArtist, $CurrentTrack,    $CurrentAlbum,
        $CurrentGenre,  $CurrentAlbumArt, $FullAlbum
    );
}

sub getGenre {
    my $client = shift;
    my $song   = shift;
    my $SCGENRE;

    my $dbh           = Slim::Schema->storage->dbh();
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    my $sth = $dbh->prepare(
'SELECT genres.name FROM contributor_track INNER JOIN tracks ON (contributor_track.track = tracks.id) INNER JOIN contributors ON (contributor_track.contributor = contributors.id) INNER JOIN genre_track ON (genre_track.track = tracks.id) INNER JOIN genres ON (genre_track.genre = genres.id) WHERE tracks.url = ?'
    );
    $sth->execute($song);
    $sth->bind_col( 1, \$SCGENRE );
    if ( $sth->fetch() ) {
        $SCGENRE = Slim::Utils::Unicode::utf8decode( $SCGENRE, 'utf8' );
    }

    $sth->finish();

    return ($SCGENRE);
}

sub getSongTechnical {
    my $client = shift;
    my $song   = shift;
    my ( $SCTitle, $SCCover, $SCReplaygain, $SCAlbumgain );

    my $dbh           = Slim::Schema->storage->dbh();
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    my $sth = $dbh->prepare(
'SELECT tracks.title, tracks.cover, tracks.replay_gain, albums.replay_gain FROM albums INNER JOIN contributors ON (albums.contributor = contributors.id) INNER JOIN tracks ON (tracks.album = albums.id) where tracks.url = ?'
    );
    $sth->execute($song);
    $sth->bind_col( 1, \$SCTitle );
    $sth->bind_col( 2, \$SCCover );
    $sth->bind_col( 3, \$SCReplaygain );
    $sth->bind_col( 4, \$SCAlbumgain );

    if ( $sth->fetch() ) {
        $SCTitle = Slim::Utils::Unicode::utf8decode( $SCTitle, 'utf8' );
        $SCCover = Slim::Utils::Unicode::utf8decode( $SCCover, 'utf8' );
        $SCReplaygain =
          Slim::Utils::Unicode::utf8decode( $SCReplaygain, 'utf8' );
        $SCAlbumgain = Slim::Utils::Unicode::utf8decode( $SCAlbumgain, 'utf8' );
    }

    $sth->finish();

    return ( $SCTitle, $SCCover, $SCReplaygain, $SCAlbumgain );
}

sub wipeourtracks {
    my $client   = shift;
    my $clientid = Slim::Player::Client::id($client);

    my $path ||= Slim::Utils::OSDetect::dirsFor('prefs');
    $path = catfile( $path, 'plugin', 'sugarcube.db' );

    my $dbh = DBI->connect("dbi:SQLite:$path")
      || die "Cannot connect: $DBI::errstr";
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    $dbh->do("DELETE FROM WorkingSet WHERE client = '$clientid' ");
    $dbh->do("DELETE FROM AlbumTracker WHERE client = '$clientid' ");
    $dbh->do("DELETE FROM ArtistTracker WHERE client = '$clientid' ");
    $dbh->do("DELETE FROM TrackTracker WHERE client = '$clientid' ");
    $dbh->do("DELETE FROM History WHERE client = '$clientid' ");

    $dbh->disconnect;
    return;
}

sub playlistcull {
    no warnings 'numeric';

    my $client      = shift;
    my $songIndex   = Slim::Player::Source::streamingSongIndex($client);
    my $songsToKeep = $prefs->client($client)->get('sugarcube_clutter');
    if ( !defined $songsToKeep ) { $songsToKeep = 5; }
    if ( $songIndex && $songsToKeep ne '' && $songIndex > $songsToKeep ) {
        for ( my $i = 0 ; $i < $songIndex - $songsToKeep ; $i++ ) {
            my $request = $client->execute( [ 'playlist', 'delete', 0 ] );
        }
    }
}

sub CheckPosition {
    my $client          = shift;
    my $listlength      = Slim::Player::Playlist::count($client);
    my $playingTrackPos = Slim::Player::Source::playingSongIndex($client);
    my $returnvalue     = ( $listlength - $playingTrackPos );
    return $returnvalue;
}

sub init {
    $log->info("Initialising SugarCube Database\n");
    my $path ||= Slim::Utils::OSDetect::dirsFor('prefs');
    $path = catfile( $path, 'plugin', 'sugarcube.db' );

    my $dbh = DBI->connect("dbi:SQLite:$path")
      || die "Cannot connect: $DBI::errstr";
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    $dbh->do(
"CREATE TABLE IF NOT EXISTS sugarcubeclients (id INTEGER PRIMARY KEY, client, persona)"
    );
    $dbh->do(
"CREATE TABLE IF NOT EXISTS WorkingSet (id INTEGER PRIMARY KEY, client, trackingno, temptrack, SCtrack, SCalbum, SCgenres, SCartist, SCplaycount integer, SCrating integer, SClastplayed integer, cover, album)"
    );
    $dbh->do(
"CREATE TABLE IF NOT EXISTS AlbumTracker (id INTEGER PRIMARY KEY, client, SCalbum text unique)"
    );
    $dbh->do(
"CREATE TABLE IF NOT EXISTS ArtistTracker (id INTEGER PRIMARY KEY, client, SCartist text unique)"
    );
    $dbh->do(
"CREATE TABLE IF NOT EXISTS TrackTracker (id INTEGER PRIMARY KEY, client, track text unique)"
    );
    $dbh->do(
"CREATE TABLE IF NOT EXISTS History (id INTEGER PRIMARY KEY, client, artist,track,album,genre,albumart,fullalbum)"
    );

    my $catalog_rowset =
      $dbh->selectall_arrayref("PRAGMA table_info(WorkingSet)");
    my @col_names = map { $_->[1] } @{$catalog_rowset};
    if ( grep { $_ eq 'cover' } @col_names ) {

        #	$log->debug("Database tables are up to date\n");
    }
    else {
        $log->debug("Updating database table\n");
        $dbh->do("ALTER TABLE WorkingSet ADD cover");
        $dbh->do("ALTER TABLE WorkingSet ADD album");
        $dbh->do(
"CREATE TABLE IF NOT EXISTS previoustrack (id INTEGER PRIMARY KEY, client, temptrack, SCtrack, SCalbum, SCgenres, SCartist, SCplaycount integer, SCrating integer, SClastplayed integer, cover)"
        );
    }
    my $catalog_rowset =
      $dbh->selectall_arrayref("PRAGMA table_info(WorkingSet)");
    my @col_names = map { $_->[1] } @{$catalog_rowset};
    if ( grep { $_ eq 'trackid' } @col_names ) {
        $log->debug("Database tables are ready\n");
    }
    else {
        $log->debug("Updating database table some more\n");
        $dbh->do("ALTER TABLE WorkingSet ADD trackid");
    }
    $dbh->do("DROP TABLE IF EXISTS sugarcubeversion");
    $dbh->do("DROP TABLE IF EXISTS MIPReturned");
    $dbh->disconnect;
}

sub myworkingset {
    no warnings 'numeric';

    my $client = shift;
    my (@miparray) = @_;

    my $clientid = Slim::Player::Client::id($client);
    my $path ||= Slim::Utils::OSDetect::dirsFor('prefs');

    $path = catfile( $path, 'plugin', 'sugarcube.db' );
    my $dbh = DBI->connect("dbi:SQLite:$path")
      || die "Cannot connect: $DBI::errstr";
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    my $sth =
      $dbh->prepare("DELETE FROM WorkingSet WHERE client = '$clientid' ");
    $sth->execute();

    my $sql =
qq{INSERT INTO WorkingSet (client, trackingno, temptrack, SCtrack, SCalbum, SCgenres, SCartist, SCplaycount, SCrating, SClastplayed, cover, album, trackid) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)};
    my $sth = $dbh->prepare($sql);

    my $arraysize = scalar(@miparray);
    my $i         = 0;
    while ( $i < $arraysize ) {
        my $SCplaycount  = $miparray[ $i + 5 ];
        my $SCrating     = $miparray[ $i + 6 ];
        my $SClastplayed = $miparray[ $i + 7 ];

        # If these are not set ie. trackstat not installed set to -1

        $SCplaycount += 0;
        if ( $SCplaycount <= 0 ) {
            $SCplaycount = -1;
        }
        $SCrating += 0;
        if ( $SCrating <= 0 ) {
            $SCrating = -1;
        }
        $SClastplayed += 0;
        if ( $SClastplayed <= 0 ) {
            $SClastplayed = -1;
        }

        $sth->bind_param( 1, $clientid,     SQL_VARCHAR );
        $sth->bind_param( 2, 'OK',          SQL_VARCHAR );
        $sth->bind_param( 3, $miparray[$i], SQL_VARCHAR )
          ;    # temptrack; track filename
        $sth->bind_param( 4,  $miparray[ $i + 1 ],  SQL_VARCHAR ); #SCTrack
        $sth->bind_param( 5,  $miparray[ $i + 2 ],  SQL_VARCHAR ); #SCAlbum
        $sth->bind_param( 6,  $miparray[ $i + 3 ],  SQL_VARCHAR ); #SCgenres
        $sth->bind_param( 7,  $miparray[ $i + 4 ],  SQL_VARCHAR ); # SCartist
        $sth->bind_param( 8,  $SCplaycount,         SQL_INTEGER ); # playcount
        $sth->bind_param( 9,  $SCrating,            SQL_INTEGER ); # rating
        $sth->bind_param( 10, $SClastplayed,        SQL_INTEGER ); # last played
        $sth->bind_param( 11, $miparray[ $i + 8 ],  SQL_VARCHAR ); # cover
        $sth->bind_param( 12, $miparray[ $i + 9 ],  SQL_VARCHAR ); # album
        $sth->bind_param( 13, $miparray[ $i + 10 ], SQL_VARCHAR ); # trackid
        $sth->execute;
        $i = $i + 11;    # INCREMENT IF ADDING COLUMNS
    }

    $sth->finish();
    return;
}

sub AlbumArtistTracker {
    no warnings 'numeric';

    my $client   = shift;
    my $album    = shift;
    my $artist   = shift;
    my $clientid = Slim::Player::Client::id($client);

    my $sugarcube_blockalbum =
      $prefs->client($client)->get('sugarcube_blockalbum');
    if ( $sugarcube_blockalbum eq '' ) {
        $log->debug(
            "Not defined; setting Default Album blocking to 5 tracks\n");
        $sugarcube_blockalbum = 5;
        $prefs->client($client)
          ->set( 'sugarcube_blockalbum', "$sugarcube_blockalbum" );
    }

    my $sugarcube_blockartist =
      $prefs->client($client)->get('sugarcube_blockartist');
    if ( $sugarcube_blockartist eq '' ) {
        $log->debug(
            "Not defined; setting Default Artist blocking to 5 tracks\n");
        $sugarcube_blockartist = 5;
        $prefs->client($client)
          ->set( 'sugarcube_blockartist', "$sugarcube_blockartist" );
    }

    my $path ||= Slim::Utils::OSDetect::dirsFor('prefs');
    $path = catfile( $path, 'plugin', 'sugarcube.db' );

    my $dbh = DBI->connect("dbi:SQLite:$path")
      || die "Cannot connect: $DBI::errstr";
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    if (
           $album ne "No Album"
        && $album ne "Žádné album"
        && $album ne "Intet album"
        && $album ne "Kein Album"
        && $album ne "Sin álbum"
        && $album ne "Ei levyä"
        && $album ne "Pas d'album"
        && $album ne "Nessun album"
        && $album ne "Geen album"
        && $album ne "Ingen album"
        && $album ne "Brak albumu"
        && $album ne "Sem Álbum"
        && $album ne "Inget album"

      )

    {  # LMS sketchy idea if the track has no album, so dont save it into the db

        my $sql =
qq{INSERT OR REPLACE INTO AlbumTracker (client, SCalbum) VALUES (?,?)};
        my $sth = $dbh->prepare($sql);
        $sth->bind_param( 1, $clientid, SQL_VARCHAR );
        $sth->bind_param( 2, $album,    SQL_VARCHAR );
        $sth->execute;
        $sth->finish();

        my $sth = $dbh->prepare(
            "SELECT COUNT(*) FROM AlbumTracker WHERE client ='$clientid'");
        eval {
            $sth->execute();
            my $songIndex = undef;
            $sth->bind_col( 1, \$songIndex );
            if ( $sth->fetch() ) {
                if ( defined($songIndex) ) {
                    if ( $songIndex > $sugarcube_blockalbum )
                    {    #  sugarcube_blockartist
                        for (
                            my $i = 0 ;
                            $i < $songIndex - $sugarcube_blockalbum ;
                            $i++
                          )
                        {
                            my $sth = $dbh->prepare(
"delete from AlbumTracker where id in (select id from AlbumTracker order by id asc limit 1)"
                            );
                            $sth->execute();
                        }
                    }
                }
            }
            $sth->finish();
        };
    }
    else {
        #$log->debug("########### HAVE A NO ALBUM; $album\n");
    }

    # Various Artists Block
    if ( lc($artist) eq 'various artists' ) {
        my $sugarcube_vartist =
          $prefs->client($client)->get('sugarcube_vartist');
        if ( $sugarcube_vartist == 1 ) {
            return;
        }
    }

    my $sql =
      qq{INSERT OR REPLACE INTO ArtistTracker (client, SCartist) VALUES (?,?)};
    my $sth = $dbh->prepare($sql);
    $sth->bind_param( 1, $clientid, SQL_VARCHAR );
    $sth->bind_param( 2, $artist,   SQL_VARCHAR );
    $sth->execute;
    $sth->finish();

    my $sth = $dbh->prepare(
        "SELECT COUNT(*) FROM ArtistTracker WHERE client ='$clientid'");
    eval {
        $sth->execute();
        my $songIndex = undef;
        $sth->bind_col( 1, \$songIndex );
        if ( $sth->fetch() ) {
            if ( defined($songIndex) ) {
                if ( $songIndex > $sugarcube_blockartist )
                {    #  sugarcube_blockartist
                    for (
                        my $i = 0 ;
                        $i < $songIndex - $sugarcube_blockartist ;
                        $i++
                      )
                    {
                        my $sth = $dbh->prepare(
"delete from ArtistTracker where id in (select id from ArtistTracker order by id asc limit 1)"
                        );
                        $sth->execute();
                    }
                }
            }
        }

    };
    $sth->finish();
    return;
}

sub TrackTracker {
    my $client = shift;
    my $track  = shift;

    my $clientid = Slim::Player::Client::id($client);

    my $sugarcube_remembertracks =
      $prefs->client($client)->get('sugarcube_remembertracks');
    if ( $sugarcube_remembertracks eq '' ) {
        $log->debug("Not defined; setting Default Track block to 5 tracks\n");
        $sugarcube_remembertracks = 5;
        $prefs->client($client)
          ->set( 'sugarcube_remembertracks', "$sugarcube_remembertracks" );
    }

    $log->debug("\nInsert into Database Playing Track:\n$track\n");

    my $path ||= Slim::Utils::OSDetect::dirsFor('prefs');
    $path = catfile( $path, 'plugin', 'sugarcube.db' );

    my $dbh = DBI->connect("dbi:SQLite:$path")
      or die "SugarCube Database Not Ready.. Please Wait 5 secs and retry\n";
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    my $sql =
      qq{INSERT OR REPLACE INTO TrackTracker (client, track) VALUES (?,?)};
    my $sth = $dbh->prepare($sql);
    $sth->bind_param( 1, $clientid, SQL_VARCHAR );
    $sth->bind_param( 2, $track,    SQL_VARCHAR );
    $sth->execute;
    $sth->finish();

    my $sth = $dbh->prepare(
        "SELECT COUNT(*) FROM TrackTracker WHERE client ='$clientid'");
    eval {
        $sth->execute();
        my $songIndex = undef;
        $sth->bind_col( 1, \$songIndex );
        if ( $sth->fetch() ) {
            if ( defined($songIndex) ) {
                if ( $songIndex > $sugarcube_remembertracks )
                {    #  sugarcube_remembertracks
                    for (
                        my $i = 0 ;
                        $i < $songIndex - $sugarcube_remembertracks ;
                        $i++
                      )
                    {
                        my $sth = $dbh->prepare(
"delete from TrackTracker where id in (select id from TrackTracker order by id asc limit 1)"
                        );
                        $sth->execute();
                    }
                }
            }
        }

    };
    $sth->finish();
    return;
}

sub mystuff {
    my $client       = shift;
    my @myworkingset = ();
    my $clientid     = Slim::Player::Client::id($client);

    my $path ||= Slim::Utils::OSDetect::dirsFor('prefs');
    $path = catfile( $path, 'plugin', 'sugarcube.db' );
    my $dbh = DBI->connect("dbi:SQLite:$path")
      || die "Cannot connect: $DBI::errstr";
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    my $sth = $dbh->prepare(
"SELECT temptrack, SCTrack, SCalbum, SCgenres, SCartist, SCplaycount, SCrating, SClastplayed, cover, album FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid'"
    );
    $sth->execute();

    my $array_ref = $sth->fetchall_arrayref();
    foreach my $row (@$array_ref) {
        push @myworkingset,
          my (
            $url,       $track,  $SCalbum,    $genres, $artist,
            $playcount, $rating, $lastplayed, $cover,  $album
          ) = @$row;
    }
    $sth->finish();
    return @myworkingset;
}

# get tracks for dupper
sub dup_tracks {
    my $client       = shift;
    my @myworkingset = ();
    my $clientid     = Slim::Player::Client::id($client);

    my $path ||= Slim::Utils::OSDetect::dirsFor('prefs');
    $path = catfile( $path, 'plugin', 'sugarcube.db' );
    my $dbh = DBI->connect("dbi:SQLite:$path")
      || die "Cannot connect: $DBI::errstr";
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    my $sth = $dbh->prepare(
"SELECT temptrack, SCTrack, SCalbum, SCgenres, SCartist FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid'"
    );
    $sth->execute();

    my $array_ref = $sth->fetchall_arrayref();
    foreach my $row (@$array_ref) {
        push @myworkingset,
          my ( $url, $track, $SCalbum, $genres, $artist ) = @$row;
    }

    $sth->finish();
    return @myworkingset;
}

sub tssorting {
    no warnings 'numeric';

    my $client                    = shift;
    my $sugarcube_ts_recentplayed = shift;
    my $sugarcube_ts_playcount    = shift;
    my $sugarcube_ts_rating       = shift;
    my $sth;
    my $metadata =
'temptrack, SCTrack, SCalbum, SCgenres, SCartist, SCplaycount, SCrating, SClastplayed, cover, album';
    my @myworkingset = ();
    my $clientid     = Slim::Player::Client::id($client);

    my $path ||= Slim::Utils::OSDetect::dirsFor('prefs');
    $path = catfile( $path, 'plugin', 'sugarcube.db' );
    my $dbh = DBI->connect("dbi:SQLite:$path")
      || die "Cannot connect: $DBI::errstr";
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    $log->debug("TrackStat - Sorting Requested\n");

    if ( $sugarcube_ts_playcount == 1 ) {

        #	$log->debug("TrackStat - Lowest Playcount\n");
    }
    elsif ( $sugarcube_ts_playcount == 2 ) {

        #	$log->debug("TrackStat - Highest Playcount\n");
    }
    if ( $sugarcube_ts_rating == 1 ) {

        #	$log->debug("TrackStat - Lowest Rating\n");
    }
    elsif ( $sugarcube_ts_rating == 2 ) {

        #	$log->debug("TrackStat - Highest Rating\n");
    }
    if ( $sugarcube_ts_recentplayed == 1 ) {

        #	$log->debug("TrackStat - Recently Played\n");
    }
    elsif ( $sugarcube_ts_recentplayed == 2 ) {

        #	$log->debug("TrackStat - Not Recently Played\n");
    }

#$log->debug("TrackStat WITH Sorting; PC;$sugarcube_ts_playcount, R;$sugarcube_ts_rating, RP;$sugarcube_ts_recentplayed\n");

#Track Playcount Setting - sugarcube_ts_playcount 	0=Dis 1=Lowest Playcount 	2=Highest Playcount
#Track Rating Setting - sugarcube_ts_rating 		0=Dis 1=Lowest Rating 		2=Highest Rating
#Track Played Setting - sugarcube_ts_recentplayed 	0=Dis 1=Recently Played 	2=Not Recently Played

    if (   ( $sugarcube_ts_playcount == 0 )
        && ( $sugarcube_ts_rating == 0 )
        && ( $sugarcube_ts_recentplayed == 1 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SClastplayed DESC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 0 )
        && ( $sugarcube_ts_rating == 0 )
        && ( $sugarcube_ts_recentplayed == 2 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SClastplayed ASC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 0 )
        && ( $sugarcube_ts_rating == 1 )
        && ( $sugarcube_ts_recentplayed == 0 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCrating ASC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 0 )
        && ( $sugarcube_ts_rating == 1 )
        && ( $sugarcube_ts_recentplayed == 1 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCrating ASC, WorkingSet.SClastplayed DESC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 0 )
        && ( $sugarcube_ts_rating == 1 )
        && ( $sugarcube_ts_recentplayed == 2 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCrating ASC, WorkingSet.SClastplayed ASC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 0 )
        && ( $sugarcube_ts_rating == 2 )
        && ( $sugarcube_ts_recentplayed == 0 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCrating DESC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 0 )
        && ( $sugarcube_ts_rating == 2 )
        && ( $sugarcube_ts_recentplayed == 1 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCrating DESC, WorkingSet.SClastplayed DESC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 0 )
        && ( $sugarcube_ts_rating == 2 )
        && ( $sugarcube_ts_recentplayed == 2 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCrating DESC, WorkingSet.SClastplayed ASC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 1 )
        && ( $sugarcube_ts_rating == 0 )
        && ( $sugarcube_ts_recentplayed == 0 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCplaycount ASC"
        );

        #	$log->debug("--ASC\n");
    }
    if (   ( $sugarcube_ts_playcount == 1 )
        && ( $sugarcube_ts_rating == 0 )
        && ( $sugarcube_ts_recentplayed == 1 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCplaycount ASC, WorkingSet.SClastplayed DESC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 1 )
        && ( $sugarcube_ts_rating == 0 )
        && ( $sugarcube_ts_recentplayed == 2 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCplaycount ASC, WorkingSet.SClastplayed ASC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 1 )
        && ( $sugarcube_ts_rating == 1 )
        && ( $sugarcube_ts_recentplayed == 0 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCplaycount ASC, WorkingSet.SCrating ASC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 1 )
        && ( $sugarcube_ts_rating == 2 )
        && ( $sugarcube_ts_recentplayed == 0 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCplaycount ASC, WorkingSet.SCrating DESC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 1 )
        && ( $sugarcube_ts_rating == 2 )
        && ( $sugarcube_ts_recentplayed == 1 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCplaycount ASC, WorkingSet.SCrating DESC, WorkingSet.SClastplayed DESC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 1 )
        && ( $sugarcube_ts_rating == 2 )
        && ( $sugarcube_ts_recentplayed == 2 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCplaycount ASC, WorkingSet.SCrating DESC, WorkingSet.SClastplayed ASC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 1 )
        && ( $sugarcube_ts_rating == 1 )
        && ( $sugarcube_ts_recentplayed == 1 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCplaycount ASC, WorkingSet.SCrating ASC, WorkingSet.SClastplayed DESC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 1 )
        && ( $sugarcube_ts_rating == 1 )
        && ( $sugarcube_ts_recentplayed == 2 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCplaycount ASC, WorkingSet.SCrating ASC, WorkingSet.SClastplayed ASC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 2 )
        && ( $sugarcube_ts_rating == 0 )
        && ( $sugarcube_ts_recentplayed == 0 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCplaycount DESC"
        );
        $log->debug("--DESC\n");
    }
    if (   ( $sugarcube_ts_playcount == 2 )
        && ( $sugarcube_ts_rating == 0 )
        && ( $sugarcube_ts_recentplayed == 1 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCplaycount DESC, WorkingSet.SClastplayed DESC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 2 )
        && ( $sugarcube_ts_rating == 0 )
        && ( $sugarcube_ts_recentplayed == 2 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCplaycount DESC, WorkingSet.SClastplayed ASC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 2 )
        && ( $sugarcube_ts_rating == 2 )
        && ( $sugarcube_ts_recentplayed == 1 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCplaycount DESC, WorkingSet.SCrating DESC, WorkingSet.SClastplayed DESC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 2 )
        && ( $sugarcube_ts_rating == 2 )
        && ( $sugarcube_ts_recentplayed == 2 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCplaycount DESC, WorkingSet.SCrating DESC, WorkingSet.SClastplayed ASC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 2 )
        && ( $sugarcube_ts_rating == 1 )
        && ( $sugarcube_ts_recentplayed == 0 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCplaycount DESC, WorkingSet.SCrating ASC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 2 )
        && ( $sugarcube_ts_rating == 2 )
        && ( $sugarcube_ts_recentplayed == 0 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCplaycount DESC, WorkingSet.SCrating DESC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 2 )
        && ( $sugarcube_ts_rating == 1 )
        && ( $sugarcube_ts_recentplayed == 1 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCplaycount DESC, WorkingSet.SCrating ASC, WorkingSet.SClastplayed DESC"
        );
    }
    if (   ( $sugarcube_ts_playcount == 2 )
        && ( $sugarcube_ts_rating == 1 )
        && ( $sugarcube_ts_recentplayed == 2 ) )
    {
        $sth = $dbh->prepare(
"SELECT $metadata FROM WorkingSet WHERE WorkingSet.trackingno = 'OK' AND client ='$clientid' ORDER BY WorkingSet.SCplaycount DESC, WorkingSet.SCrating ASC, WorkingSet.SClastplayed ASC"
        );
    }

    $sth->execute();
    my (
        $temptrack,   $SCTrack,  $SCalbum,      $SCgenres, $SCartist,
        $SCplaycount, $SCrating, $SClastplayed, $cover,    $album
    );

    $sth->bind_col( 1,  \$temptrack );
    $sth->bind_col( 2,  \$SCTrack );
    $sth->bind_col( 3,  \$SCalbum );
    $sth->bind_col( 4,  \$SCgenres );
    $sth->bind_col( 5,  \$SCartist );
    $sth->bind_col( 6,  \$SCplaycount );
    $sth->bind_col( 7,  \$SCrating );
    $sth->bind_col( 8,  \$SClastplayed );
    $sth->bind_col( 9,  \$cover );
    $sth->bind_col( 10, \$album );

    while ( $sth->fetch ) {
        push @myworkingset, $temptrack, $SCTrack, $SCalbum, $SCgenres,
          $SCartist, $SCplaycount, $SCrating, $SClastplayed, $cover, $album;

#$log->debug("PC;$SCplaycount R;$SCrating LP;$SClastplayed; $SCTrack,$SCalbum,$SCartist\n");
    }
    $sth->finish();
    return @myworkingset;
}

sub droptsmetrics {
    my $client   = shift;
    my $clientid = Slim::Player::Client::id($client);

    my $sugarcube_ts_trackrated =
      $prefs->client($client)->get('sugarcube_ts_trackrated');
    my $sugarcube_ts_pc_higher =
      $prefs->client($client)->get('sugarcube_ts_pc_higher');
    my $sugarcube_ts_lastplayed =
      $prefs->client($client)->get('sugarcube_ts_lastplayed');

    my $path ||= Slim::Utils::OSDetect::dirsFor('prefs');
    $path = catfile( $path, 'plugin', 'sugarcube.db' );
    my $dbh = DBI->connect("dbi:SQLite:$path")
      || die "Cannot connect: $DBI::errstr";
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    if ( $sugarcube_ts_trackrated eq '' ) {
        $prefs->client($client)->set( 'sugarcube_ts_trackrated', 0 );
        $sugarcube_ts_trackrated = 0;
    }
    if ( $sugarcube_ts_pc_higher eq '' ) {
        $prefs->client($client)->set( 'sugarcube_ts_pc_higher', 0 );
        $sugarcube_ts_pc_higher = 0;
    }
    if ( $sugarcube_ts_lastplayed eq '' ) {
        $prefs->client($client)->set( 'sugarcube_ts_lastplayed', 0 );
        $sugarcube_ts_lastplayed = 0;
    }

#	$log->debug("Track Rating: $sugarcube_ts_trackrated PlayCount: $sugarcube_ts_pc_higher LastPlayed: $sugarcube_ts_lastplayed\n");

    if ( $sugarcube_ts_trackrated == 0 ) {
        $log->debug("TrackStat - Use Track Rating - Disabled\n");
    }
    else {

        ## trackstat.plugin.pm line 1940
        my $ts_prefs = preferences('plugin.TrackStat');

        #rating_10scale == 0 if 1to5
        #rating_10scale == 1 if 1to10

        my $rating_scale = $ts_prefs->get('rating_10scale');

        if ( $rating_scale == 1 ) {    # TS scale is 1 to 10

            #	$log->debug("TrackStat - Is using Rating Scale of 1 to 10\n");
            if ( $sugarcube_ts_trackrated == 1 ) {
                $sugarcube_ts_trackrated = 14;
            }                          # TS1
            elsif ( $sugarcube_ts_trackrated == 2 ) {
                $sugarcube_ts_trackrated = 24;
            }                          # TS2
            elsif ( $sugarcube_ts_trackrated == 3 ) {
                $sugarcube_ts_trackrated = 34;
            }                          # TS3
            elsif ( $sugarcube_ts_trackrated == 4 ) {
                $sugarcube_ts_trackrated = 44;
            }                          # TS4
            elsif ( $sugarcube_ts_trackrated == 5 ) {
                $sugarcube_ts_trackrated = 54;
            }                          # TS5
            elsif ( $sugarcube_ts_trackrated == 6 ) {
                $sugarcube_ts_trackrated = 64;
            }                          # TS6
            elsif ( $sugarcube_ts_trackrated == 7 ) {
                $sugarcube_ts_trackrated = 74;
            }                          # TS7
            elsif ( $sugarcube_ts_trackrated == 8 ) {
                $sugarcube_ts_trackrated = 84;
            }                          # TS8
            elsif ( $sugarcube_ts_trackrated == 9 ) {
                $sugarcube_ts_trackrated = 94;
            }                          # TS9
            else { $sugarcube_ts_trackrated = 0; }

        }
        else {                         # TS rating 1 to 5

            #	$log->debug("TrackStat - Is using Rating Scale of 1 to 5\n");
            # TS0 is under 9
            if ( $sugarcube_ts_trackrated == 1 ) {
                $sugarcube_ts_trackrated = 29;
            }    # TS1 10 and 29
            elsif ( $sugarcube_ts_trackrated == 2 ) {
                $sugarcube_ts_trackrated = 49;
            }    # TS2 30 to 49
            elsif ( $sugarcube_ts_trackrated == 3 ) {
                $sugarcube_ts_trackrated = 69;
            }    # TS3 50 to 69
            elsif ( $sugarcube_ts_trackrated == 4 ) {
                $sugarcube_ts_trackrated = 89;
            }    # TS4 70 to 89
            else {
                $sugarcube_ts_trackrated = 0;
                $log->debug(
"***ERROR*** you set block higher than TrackStat Rating Scale.. (Change to Block 0 to 4) Ignoring Setting and using 0\n"
                );
            }
        }

#		$sugarcube_ts_trackrated *= 10;	# Bump it same as Trackstat
#		$sugarcube_ts_trackrated += 9;	# Trackstat tracks ratings of 1* or 2* may actually be 12 or 23 so we bump up to the 9 to catch these

    #		$log->debug("TrackStat - Drop between 0 and $sugarcube_ts_trackrated\n");

        my $sth = $dbh->prepare(
"SELECT DISTINCT WorkingSet.id FROM WorkingSet WHERE (WorkingSet.SCrating BETWEEN 0 AND '$sugarcube_ts_trackrated') AND WorkingSet.client ='$clientid'"
        );
        $sth->execute() or warn $dbh->errstr . "\n";
        my $array_ref = $sth->fetchall_arrayref();
        foreach my $row (@$array_ref) {

            my $sth = $dbh->prepare(
"UPDATE WorkingSet SET trackingno='DROPTSRATING' WHERE WorkingSet.id ='@$row'"
            );
            $sth->execute();
        }
        $sth->finish();
    }

    if ( $sugarcube_ts_pc_higher == 0 ) {

       #	$log->debug("TrackStat - Drop Tracks with Playcount N/A - DISABLED\n");
    }
    else {
#		$log->debug("TrackStat - Drop Tracks with Playcount >= $sugarcube_ts_pc_higher\n");
        my $sth = $dbh->prepare(
"SELECT DISTINCT WorkingSet.id FROM WorkingSet WHERE (WorkingSet.SCplaycount >= '$sugarcube_ts_pc_higher') AND WorkingSet.client ='$clientid'"
        );
        $sth->execute() or warn $dbh->errstr . "\n";
        my $array_ref = $sth->fetchall_arrayref();
        foreach my $row (@$array_ref) {
            my $sth = $dbh->prepare(
"UPDATE WorkingSet SET trackingno='DROPTSPLAYCOUNT' WHERE WorkingSet.id ='@$row'"
            );
            $sth->execute();

            #	$log->debug("Dropping track; '@$row'\n");
        }
        $sth->finish();
    }
    if ( $sugarcube_ts_lastplayed == 0 ) {

        #	$log->debug("TrackStat - Drop tracks Lastplayed N/A - DISABLED\n");
    }
    else {

        my $currenttime     = time;    # Current time in epoch
        my $epochYestertime = time -
          ( ( $sugarcube_ts_lastplayed * 24 ) * 60 * 60 )
          ;    # subtract secs in day from current epoch time

 #		$log->debug("TrackStat - Drop BETWEEN $epochYestertime AND $currenttime\n");

        my $sth = $dbh->prepare(
"SELECT DISTINCT WorkingSet.id FROM WorkingSet WHERE (WorkingSet.SClastplayed BETWEEN '$epochYestertime' AND '$currenttime') AND WorkingSet.client ='$clientid'"
        );
        $sth->execute() or warn $dbh->errstr . "\n";
        my $array_ref = $sth->fetchall_arrayref();
        foreach my $row (@$array_ref) {
            my $sth = $dbh->prepare(
"UPDATE WorkingSet SET trackingno='DROPTSLASTPLAYED' WHERE WorkingSet.id ='@$row'"
            );
            $sth->execute();
        }
        $sth->finish();
    }
}

#Drop XMas Genre
sub DropGenreAndXMas {
    my $client    = shift;
    my $sugarxmas = $prefs->get('sugarxmas');
    my $theTime;

    my $path ||= Slim::Utils::OSDetect::dirsFor('prefs');
    $path = catfile( $path, 'plugin', 'sugarcube.db' );
    my $dbh = DBI->connect("dbi:SQLite:$path")
      || die "Cannot connect: $DBI::errstr";
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    if ( $sugarxmas == 1 ) {

        # Check if its Christmas
        my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
        my (
            $second,     $min,       $hour,
            $dayOfMonth, $month,     $yearOffset,
            $dayOfWeek,  $dayOfYear, $daylightSavings
        ) = localtime();
        $theTime = "$months[$month]";
    }

    # Block Genres we dont want
    my $scblockgenre_always =
      $dbh->quote( $prefs->client($client)->get('scblockgenre_always') );
    my $scblockgenre_alwaystwo =
      $dbh->quote( $prefs->client($client)->get('scblockgenre_alwaystwo') );
    my $scblockgenre_alwaysthree =
      $dbh->quote( $prefs->client($client)->get('scblockgenre_alwaysthree') );
    my $clientid = $dbh->quote( Slim::Player::Client::id($client) );

    my $sth;

    if ( ( $sugarxmas == 1 ) && ( $theTime ne 'Dec' ) ) {

        #	$log->debug("Christmas Block Active\n" );
        $sth = $dbh->prepare(
"UPDATE WorkingSet SET trackingno = 'DROPBLOCKEDGENRE' WHERE WorkingSet.SCgenres = $scblockgenre_always OR WorkingSet.SCgenres = $scblockgenre_alwaystwo OR WorkingSet.SCgenres = $scblockgenre_alwaysthree OR upper(WorkingSet.SCgenres) = 'XMAS' OR upper(WorkingSet.SCgenres) = 'CHRISTMAS' AND WorkingSet.client = $clientid"
        );
        $sth->execute() || die "Could not execute: " . $dbh->errstr;
    }
    else {
        $sth = $dbh->prepare(
"UPDATE WorkingSet SET trackingno = 'DROPBLOCKEDGENRE' WHERE WorkingSet.SCgenres = $scblockgenre_always OR WorkingSet.SCgenres = $scblockgenre_alwaystwo OR WorkingSet.SCgenres = $scblockgenre_alwaysthree AND WorkingSet.client = $clientid"
        );
        $sth->execute() || die "Could not execute: " . $dbh->errstr;
    }

}

#Drop Artists
sub DropArtists {
    my $client = shift;
    my $sth;

    my $sugarcube_global_player =
      $prefs->client($client)->get('sugarcube_global_player');

    $sugarcube_global_player = 0;    # Stop it firing for now

    my $path ||= Slim::Utils::OSDetect::dirsFor('prefs');
    $path = catfile( $path, 'plugin', 'sugarcube.db' );
    my $dbh = DBI->connect("dbi:SQLite:$path")
      || die "Cannot connect: $DBI::errstr";
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    # Block Artist we dont want
    my $scblockartist_always =
      $prefs->client($client)->get('scblockartist_always');
    my $scblockartist_alwaystwo =
      $prefs->client($client)->get('scblockartist_alwaystwo');
    my $scblockartist_alwaysthree =
      $prefs->client($client)->get('scblockartist_alwaysthree');

    $scblockartist_always      = $dbh->quote($scblockartist_always);
    $scblockartist_alwaystwo   = $dbh->quote($scblockartist_alwaystwo);
    $scblockartist_alwaysthree = $dbh->quote($scblockartist_alwaysthree);

    if ( $sugarcube_global_player == 0 ) {

        #	$log->debug("SugarCube Std Drop Artists\n");
        my $clientid = $dbh->quote( Slim::Player::Client::id($client) );
        $sth = $dbh->prepare(
"UPDATE WorkingSet SET trackingno = 'DROPBLOCKEDARTIST' WHERE WorkingSet.SCartist = $scblockartist_always OR WorkingSet.SCartist = $scblockartist_alwaystwo OR WorkingSet.SCartist = $scblockartist_alwaysthree AND WorkingSet.client = $clientid"
        );
        $sth->execute() || die "Could not execute: " . $dbh->errstr;
        $sth = $dbh->prepare(
"UPDATE WorkingSet SET trackingno = 'DROPARTIST' WHERE EXISTS (SELECT ArtistTracker.id FROM ArtistTracker WHERE ArtistTracker.SCartist = WorkingSet.SCartist AND WorkingSet.client = $clientid)"
        );
        $sth->execute() || die "Could not execute: " . $dbh->errstr;

    }
    else {
        #	$log->debug("SugarCube GLOBAL Drop Artists\n");
        my $clientid = $dbh->quote( Slim::Player::Client::id($client) );
        $sth = $dbh->prepare(
"UPDATE WorkingSet SET trackingno = 'DROPBLOCKEDARTIST' WHERE WorkingSet.SCartist = $scblockartist_always OR WorkingSet.SCartist = $scblockartist_alwaystwo OR WorkingSet.SCartist = $scblockartist_alwaysthree AND WorkingSet.client = $clientid"
        );
        $sth->execute() || die "Could not execute: " . $dbh->errstr;
        $sth = $dbh->prepare(
"UPDATE WorkingSet SET trackingno = 'DROPARTIST' WHERE EXISTS (SELECT ArtistTracker.id FROM ArtistTracker WHERE ArtistTracker.SCartist = WorkingSet.SCartist"
        );
        $sth->execute() || die "Could not execute: " . $dbh->errstr;

    }

}

#Drop Albums
sub DropAlbums {
    my $client = shift;
    my $sth;
    my $sugarcube_global_player =
      $prefs->client($client)->get('sugarcube_global_player');

    $sugarcube_global_player = 0;    # Stop it firing for now

    my $path ||= Slim::Utils::OSDetect::dirsFor('prefs');
    $path = catfile( $path, 'plugin', 'sugarcube.db' );
    my $dbh = DBI->connect("dbi:SQLite:$path")
      || die "Cannot connect: $DBI::errstr";
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    if ( $sugarcube_global_player == 0 ) {
        my $clientid = $dbh->quote( Slim::Player::Client::id($client) );
        $sth = $dbh->prepare(
"UPDATE WorkingSet SET trackingno = 'DROPALBUMS' WHERE EXISTS (SELECT AlbumTracker.id FROM AlbumTracker WHERE AlbumTracker.SCalbum = WorkingSet.SCalbum AND WorkingSet.client = $clientid)"
        );
    }
    else {
        $sth = $dbh->prepare(
"UPDATE WorkingSet SET trackingno = 'DROPALBUMS' WHERE EXISTS (SELECT AlbumTracker.id FROM AlbumTracker WHERE AlbumTracker.SCalbum = WorkingSet.SCalbum)"
        );
    }
    $sth->execute() || die "Could not execute: " . $dbh->errstr;
}

sub DropEmPunk {
    my $client   = shift;
    my $clientid = Slim::Player::Client::id($client);

    my $path ||= Slim::Utils::OSDetect::dirsFor('prefs');
    $path = catfile( $path, 'plugin', 'sugarcube.db' );
    my $dbh = DBI->connect("dbi:SQLite:$path")
      || die "Cannot connect: $DBI::errstr";
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    my $sth = $dbh->prepare(
"SELECT DISTINCT WorkingSet.id FROM WorkingSet INNER JOIN TrackTracker ON TrackTracker.client = WorkingSet.client WHERE WorkingSet.temptrack LIKE TrackTracker.track AND WorkingSet.client ='$clientid'"
    );
    $sth->execute();
    my $array_ref = $sth->fetchall_arrayref();
    foreach my $row (@$array_ref) {
        my $sth = $dbh->prepare(
"UPDATE WorkingSet SET trackingno='DROPPLAYEDALREADY' WHERE WorkingSet.id ='@$row'"
        );
        $sth->execute();
    }

    $sth->finish();
}

sub update_duplicate {
    my $client    = shift;
    my $track_url = shift;

    my $sth;

    my $path ||= Slim::Utils::OSDetect::dirsFor('prefs');
    $path = catfile( $path, 'plugin', 'sugarcube.db' );
    my $dbh = DBI->connect("dbi:SQLite:$path")
      || die "Cannot connect: $DBI::errstr";
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    my $clientid = $dbh->quote( Slim::Player::Client::id($client) );
    my $track    = $dbh->quote($track_url);

    $sth = $dbh->prepare(
"UPDATE WorkingSet SET trackingno = 'DROPDUP' WHERE WorkingSet.temptrack = $track AND WorkingSet.client = $clientid"
    );
    $sth->execute() || die "Could not execute: " . $dbh->errstr;
}

sub StatsPuller {
    my $client   = shift;
    my $clientid = Slim::Player::Client::id($client);
    my (
        $line, $col1, $col2, $col3,  $col4,  $col5, $col6,
        $col7, $col8, $col9, $col10, $col11, $col12
    );
    my $sugarlvTS       = $prefs->get('sugarlvTS');
    my $sugarlviconsize = $prefs->get('sugarlviconsize');

    my $path ||= Slim::Utils::OSDetect::dirsFor('prefs');
    $path = catfile( $path, 'plugin', 'sugarcube.db' );

    my $dbh = DBI->connect("dbi:SQLite:$path")
      || die "Cannot connect: $DBI::errstr";
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    my $sth = $dbh->prepare(
"SELECT trackingno, SCtrack, SCalbum, SCartist, SCgenres, SCplaycount, SCrating, SClastplayed, temptrack, cover, album, trackid FROM WorkingSet WHERE WorkingSet.client = '$clientid' ORDER BY WorkingSet.trackingno DESC"
    );
    $sth->execute();
    $sth->bind_col( 1, \$col1 )
      ;    # tracking status ie. played already, playcount etc
    $sth->bind_col( 2,  \$col2 );     # track name
    $sth->bind_col( 3,  \$col3 );     # album name
    $sth->bind_col( 4,  \$col4 );     # artist name
    $sth->bind_col( 5,  \$col5 );     # genres
    $sth->bind_col( 6,  \$col6 );     # TS playcount
    $sth->bind_col( 7,  \$col7 );     # TS rating
    $sth->bind_col( 8,  \$col8 );     # TS lastplayed
    $sth->bind_col( 9,  \$col9 );     # temptrack file url
    $sth->bind_col( 10, \$col10 );    # albumart cover number
    $sth->bind_col( 11, \$col11 );    # full album id
    $sth->bind_col( 12, \$col12 );    # track id

    my $clientid = $client->id;
    $clientid =~ s/:/%3A/g;           # URI player id

    if ($sugarlvTS) {

        # Stats Enabled
        while ( $sth->fetch ) {
            if ( $col6 == -1 ) { $col6 = 'Never Played'; }
            if ( $col7 == -1 ) { $col7 = 'Not Rated'; }
            if ( $col1 eq 'DROPBLOCKEDARTIST' ) {
                $col1 = 'Always Block Artist';
            }
            elsif ( $col1 eq 'DROPARTIST' )       { $col1 = 'Recent Artist'; }
            elsif ( $col1 eq 'DROPALBUMS' )       { $col1 = 'Recent Album'; }
            elsif ( $col1 eq 'DROPTSLASTPLAYED' ) { $col1 = 'Recently Played'; }
            elsif ( $col1 eq 'DROPPLAYEDALREADY' ) { $col1 = 'Already Played'; }
            elsif ( $col1 eq 'DROPBLOCKEDGENRE' ) {
                $col1 = 'Always Block Genre';
            }
            elsif ( $col1 eq 'DROPTSPLAYCOUNT' ) {
                $col1 = 'Blocked by Playcount';
            }
            elsif ( $col1 eq 'DROPTSRATING' ) { $col1 = 'Blocked by Rating'; }
            elsif ( $col1 eq 'DROPDUP' )      { $col1 = 'Duplicate Track'; }

            if ( $col8 == -1 ) {
                $col8 = 'Never Played';
            }
            else {
                $col8 = localtime($col8);
            }

            if ( length($col10) == 0 ) { $col10 = "0"; }
            my $build =
"<a onclick=\"SqueezeJS.Controller.urlRequest('/anyurl?p0=playlistcontrol&amp;p1=cmd:load&amp;p2=album_id:"
              . $col11
              . "&amp;player="
              . $clientid
              . "', 1, SqueezeJS.string('Loading Album'));\">";
            my $build2 =
"<a onclick=\"SqueezeJS.Controller.urlRequest('/anyurl?p0=playlistcontrol&amp;p1=cmd:add&amp;p2=album_id:"
              . $col11
              . "&amp;player="
              . $clientid
              . "', 1, SqueezeJS.string('Loading Album'));\">";
            my $build3 =
"<a href=\"/clixmlbrowser/clicmd=browselibrary+items&amp;mode=albums&amp;album_id="
              . $col11
              . "&amp;player="
              . $clientid
              . "'/index.html?index=0\" target=\"browser\"><img src=\"/html/images/b_mmmix.gif\"  alt=\"More\" title=\"More\"></a>";
            my $build4 =
"<a onclick=\"SqueezeJS.Controller.urlRequest('/anyurl?p0=playlistcontrol&amp;p1=cmd:add&amp;p2=track_id:"
              . $col12
              . "&amp;player="
              . $clientid
              . "', 1, SqueezeJS.string('Add Track'));\">";

            # THIS IS TRACKSTAT BUILD UP
            $line =
                $line
              . '<tr><td rowspan=9 class=pic><img width='
              . $sugarlviconsize
              . ' height='
              . $sugarlviconsize
              . " src=/music/"
              . $col10
              . "/cover_"
              . $sugarlviconsize . 'x'
              . $sugarlviconsize
              . '_o.jpg></td><td>'
              . $build
              . ' <img src="/html/images/b_play.gif" class="cmdLinkIcon" width="17" height="17" alt="Play Album" title="Play Album"></a> '
              . $build2
              . ' <img src="/html/images/b_add.gif" class="cmdLinkIcon" width="17" height="17" alt="Add Album" title="Add Album"></a> '
              . $build4
              . ' <img src="/plugins/SugarCube/HTML/images/sugarcube2_25x25.png" class="cmdLinkIcon" width="17" height="17" alt="Add Track" title="Add Track"></a> '
              . $build3
              . '</td></tr><tr><td class=txt>'
              . $col1
              . '</td></tr><tr><td style="vertical-align:middle">'
              . $col2
              . '</td></tr><tr><td style="vertical-align:middle">'
              . $col3
              . '</td></tr><tr><td style="vertical-align:middle">'
              . $col4
              . '</td></tr><tr><td style="vertical-align:middle">'
              . $col5
              . '</td></tr><tr><td style="vertical-align:middle">Playcount: '
              . $col6
              . '</td></tr><tr><td style="vertical-align:middle">Rating: '
              . $col7
              . '</td></tr><tr><td style="vertical-align:middle">Last Played: '
              . $col8
              . '</td></tr><tr><td colspan=2 class=end>&nbsp;</td></tr><tr><td colspan=2>&nbsp;</td></tr>';
        }
    }
    else {
        while ( $sth->fetch ) {
            if ( $col1 eq 'DROPBLOCKEDARTIST' ) {
                $col1 = 'Always Block Artist';
            }
            elsif ( $col1 eq 'DROPARTIST' )       { $col1 = 'Recent Artist'; }
            elsif ( $col1 eq 'DROPALBUMS' )       { $col1 = 'Recent Album'; }
            elsif ( $col1 eq 'DROPTSLASTPLAYED' ) { $col1 = 'Recently Played'; }
            elsif ( $col1 eq 'DROPPLAYEDALREADY' ) { $col1 = 'Already Played'; }
            elsif ( $col1 eq 'DROPBLOCKEDGENRE' ) {
                $col1 = 'Always Block Genre';
            }
            elsif ( $col1 eq 'DROPTSPLAYCOUNT' ) {
                $col1 = 'Blocked by Playcount';
            }
            elsif ( $col1 eq 'DROPTSRATING' ) { $col1 = 'Blocked by Rating'; }
            elsif ( $col1 eq 'DROPDUP' )      { $col1 = 'Duplicate Track'; }

            if ( length($col10) == 0 ) { $col10 = '0'; }

            my $build =
"<a onclick=\"SqueezeJS.Controller.urlRequest('/anyurl?p0=playlistcontrol&amp;p1=cmd:load&amp;p2=album_id:"
              . $col11
              . "&amp;player="
              . $clientid
              . "', 1, SqueezeJS.string('Loading Album'));\">";
            my $build2 =
"<a onclick=\"SqueezeJS.Controller.urlRequest('/anyurl?p0=playlistcontrol&amp;p1=cmd:add&amp;p2=album_id:"
              . $col11
              . "&amp;player="
              . $clientid
              . "', 1, SqueezeJS.string('Add Album'));\">";
            my $build4 =
"<a onclick=\"SqueezeJS.Controller.urlRequest('/anyurl?p0=playlistcontrol&amp;p1=cmd:add&amp;p2=track_id:"
              . $col12
              . "&amp;player="
              . $clientid
              . "', 1, SqueezeJS.string('Add Track'));\">";
            my $build3 =
"<a href=\"/clixmlbrowser/clicmd=browselibrary+items&amp;mode=albums&amp;album_id="
              . $col11
              . "&amp;player="
              . $clientid
              . "'/index.html?index=0\" target=\"browser\"><img src=\"/html/images/b_mmmix.gif\" alt=\"More\" title=\"More\"></a>";

            $line =
                $line
              . '<tr><td rowspan=7 class=pic><img width='
              . $sugarlviconsize
              . ' height='
              . $sugarlviconsize
              . " src=/music/"
              . $col10
              . "/cover_"
              . $sugarlviconsize . 'x'
              . $sugarlviconsize
              . '_o.jpg></td><td>'
              . $build
              . ' <img src="/html/images/b_play.gif" class="cmdLinkIcon" width="17" height="17" alt="Play Album" title="Play Album"></a> '
              . $build2
              . ' <img src="/html/images/b_add.gif" class="cmdLinkIcon" width="17" height="17" alt="Add Album" title="Add Album"></a> '
              . $build4
              . ' <img src="/plugins/SugarCube/HTML/images/sugarcube2_25x25.png" class="cmdLinkIcon" width="17" height="17" alt="Add Track" title="Add Track"></a> '
              . $build3
              . '</td></tr><tr><td class=txt>'
              . $col1
              . '</td></tr><tr><td style="vertical-align:middle">'
              . $col2
              . '</td></tr><tr><td style="vertical-align:middle">'
              . $col3
              . '</td></tr><tr><td style="vertical-align:middle">'
              . $col4
              . '</td></tr><tr><td style="vertical-align:middle">'
              . $col5
              . '</td></tr><tr><td colspan=2 class=end>&nbsp;</td></tr><tr><td colspan=2>&nbsp;</td></tr>';

        }
    }

    $sth->finish();
    return $line;
}

sub GrabHistory {
    my $client       = shift;
    my @myworkingset = ();
    my $clientid     = Slim::Player::Client::id($client);

    my $path ||= Slim::Utils::OSDetect::dirsFor('prefs');
    $path = catfile( $path, 'plugin', 'sugarcube.db' );

    my $dbh = DBI->connect("dbi:SQLite:$path")
      || die "Cannot connect: $DBI::errstr";
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    my $sth = $dbh->prepare(
"SELECT artist, track, album, genre, albumart, fullalbum FROM History WHERE client ='$clientid' ORDER BY id DESC"
    );
    $sth->execute();

    my $array_ref = $sth->fetchall_arrayref();
    foreach my $row (@$array_ref) {
        push @myworkingset,
          my ( $artist, $track, $album, $genre, $albumart, $fullalbum ) = @$row;
    }

    $sth->finish();
    return @myworkingset;
}

sub SaveHistory {
    my $client    = shift;
    my $artist    = shift;
    my $track     = shift;
    my $album     = shift;
    my $genre     = shift;
    my $albumart  = shift;
    my $fullalbum = shift;

    my $clientid = Slim::Player::Client::id($client);

    my $path ||= Slim::Utils::OSDetect::dirsFor('prefs');
    $path = catfile( $path, 'plugin', 'sugarcube.db' );

    my $dbh = DBI->connect("dbi:SQLite:$path")
      || die "Cannot connect: $DBI::errstr";
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    my $sql =
qq{INSERT INTO History (client, artist, track, album, genre, albumart, fullalbum) VALUES (?,?,?,?,?,?,?)};
    my $sth = $dbh->prepare($sql);
    $sth->bind_param( 1, $clientid,  SQL_VARCHAR );
    $sth->bind_param( 2, $artist,    SQL_VARCHAR );
    $sth->bind_param( 3, $track,     SQL_VARCHAR );
    $sth->bind_param( 4, $album,     SQL_VARCHAR );
    $sth->bind_param( 5, $genre,     SQL_VARCHAR );
    $sth->bind_param( 6, $albumart,  SQL_VARCHAR );
    $sth->bind_param( 7, $fullalbum, SQL_VARCHAR );

    $sth->execute;

    my $sth =
      $dbh->prepare("SELECT COUNT(*) FROM History WHERE client ='$clientid'");
    eval {
        $sth->execute();
        my $songIndex = undef;
        $sth->bind_col( 1, \$songIndex );
        if ( $sth->fetch() ) {
            if ( defined($songIndex) ) {
                if ( $songIndex > 30 ) {
                    for ( my $i = 0 ; $i < $songIndex - 30 ; $i++ ) {
                        my $sth = $dbh->prepare(
"delete from History where id in (select id from History order by id asc limit 1)"
                        );
                        $sth->execute();
                    }
                }
            }
        }
    };

    $sth->finish();
    return;
}

# Get number of seconds of track
sub get_track_length {
    my $client = shift;
    my $song   = shift;
    my $length;

    my $dbh           = Slim::Schema->storage->dbh();
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    my $sth = $dbh->prepare('SELECT secs FROM tracks WHERE tracks.url = ?');
    $sth->execute($song);
    $sth->bind_col( 1, \$length );
    if ( $sth->fetch() ) {
        $length = Slim::Utils::Unicode::utf8decode( $length, 'utf8' );
    }
    $sth->finish();
    return ($length);

}

1;
__END__
