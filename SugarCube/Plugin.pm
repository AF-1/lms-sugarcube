#Spicefly - SugarCube - Copyright 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021 - Charles Parker
#Developed by Charles Parker - https://www.spicefly.com/
#
#Donations are gratefully received to assist with the costs of maintaining spicefly.com and associated knowledge articles
#https://paypal.me/spicefly
#
#
#v6.01 - December 2023
#+===================+
#Licencing Requirements Removed
#Released as Open Source under the GNU General Public License v3.0
#
#In Short Summary
#Complete source code must be made available that includes all changes
#Copyright and license notices must be preserved. 
#Contributors provide an express grant of patent rights.


package Plugins::SugarCube::Plugin;
use base qw(Slim::Plugin::Base);
use strict;
use Slim::Utils::Misc;
use Slim::Utils::Prefs;
use Slim::Utils::Log;

my $log = Slim::Utils::Log->addLogCategory(
    {
        'category' => 'plugin.sugarcube',

        #  'defaultLevel' => 'WARN',
        'defaultLevel' => 'DEBUG',
        'description'  => getDisplayName(),
    }
);

use Slim::Utils::Strings qw(string);
use Slim::Control::Request;
use Slim::Utils::OSDetect;
use Plugins::SugarCube::Settings;
use Plugins::SugarCube::PlayerSettings;
use Plugins::SugarCube::Breakout;
use Plugins::SugarCube::Traffic;
use Plugins::SugarCube::ProtocolHandler;
use Scalar::Util qw(blessed);
use Slim::Utils::Timers;
use URI::Escape;
use base qw(Slim::Menu::Base);
my @previousset       = ();
my @unique            = ();
my @myworkingset      = ();
my $prefs             = preferences('plugin.SugarCube');
my %cpartist          = ();
my %cptrack           = ();
my %cpalbum           = ();
my %cpgenre           = ();
my %cpalbumart        = ();
my %cpfullalbum       = ();
my %cppc              = ();
my %cprat             = ();
my %cplp              = ();
my %upnartist         = ();
my %upntrack          = ();
my %upnalbum          = ();
my %upngenre          = ();
my %upnalbumart       = ();
my %upnfullalbum      = ();
my %upnpc             = ();
my %upnrat            = ();
my %upnlp             = ();
my %genres            = ();
my $htmlTemplate      = 'plugins/SugarCube/settings/history.html';
my $htmlTemplateLV    = 'plugins/SugarCube/settings/liveview.html';
my $htmlQuickPlay     = 'plugins/SugarCube/settings/quickplay.html';
my %nowPlayingmapping = ( 'pause.hold' => 'quietnext', );
my $global_quickmix    = 0;  # if quick fire mix from currently playing selected
my %slide_start_volume = (); # Holds clients volume level before sliding
my %global_slide_on    = (); # Holds clients status if volume sliding
my $mixstatus          = ''; # Holds status of MusicIP service
my $TSenabled;

sub getIcon {
    return Plugins::SugarCube::Plugin->_pluginDataFor('icon');
}
sub getDisplayName { return 'PLUGIN_SUGARCUBE'; }

sub quietnext {
    my $client           = shift;
    my $button           = shift;
    my $arg              = shift;
    my $sugarcube_upnext = $prefs->client($client)->get('sugarcube_upnext');
    if ( $sugarcube_upnext == 1 ) {
        $sugarcube_upnext = 0;
        $prefs->client($client)->set( 'sugarcube_upnext', "$sugarcube_upnext" );
        UpNext( $client, '{PLUGIN_SUGARCUBE_UPNEXT_OFF}' );
    }
    else {
        $sugarcube_upnext = 1;
        $prefs->client($client)->set( 'sugarcube_upnext', "$sugarcube_upnext" );
        UpNext( $client, '{PLUGIN_SUGARCUBE_UPNEXT_ON}' );
    }
}

sub initPlugin {
    my $class  = shift;
    my $client = shift;
    $class->SUPER::initPlugin();
    Slim::Hardware::IR::addModeDefaultMapping( 'playlist',
        \%nowPlayingmapping );
    my $functref = Slim::Buttons::Playlist::getFunctions();
    $functref->{'quietnext'} = \&quietnext;

    Plugins::SugarCube::Settings->new;
    Plugins::SugarCube::PlayerSettings->new;

    Plugins::SugarCube::Breakout::init();

    my $sugarxmas = $prefs->get('sugarxmas');
    if ( $sugarxmas eq '' ) {
        $sugarxmas = 0;
        $prefs->set( 'sugarxmas', "$sugarxmas" );
        $log->debug("SugarCube XMas Block, default to off\n");
    }

    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    if ( $sqlitetimeout eq '' ) {
        $sqlitetimeout = 30;
        $prefs->set( 'sqlitetimeout', "$sqlitetimeout" );
        $log->debug("Sqlitetimeout, default to 30secs\n");
    }

    my $sugarlvweight = $prefs->get('sugarlvweight');
    if ( $sugarlvweight eq '' ) {
        $sugarlvweight = '84';
        $prefs->set( 'sugarlvweight', "$sugarlvweight" );
        $log->debug(
            "SugarCube LV Weighting not Set; $sugarlvweight, default set\n");
    }

    my $sugarhisweight = $prefs->get('sugarhisweight');
    if ( $sugarhisweight eq '' ) {
        $sugarhisweight = '85';
        $prefs->set( 'sugarhisweight', "$sugarhisweight" );
        $log->debug(
            "SugarCube HIS Weighting not Set; $sugarhisweight, default set\n");
    }

    my $sugarport = $prefs->get('sugarport');
    if ( $sugarport eq '' ) {
        $sugarport = '10002';
        $prefs->set( 'sugarport', "$sugarport" );
        $log->debug(
"SugarCube Port not Set; $sugarport for this client, default set to 10002\n"
        );
    }
    my $miphosturl = $prefs->get('miphosturl');
    if ( $miphosturl eq '' ) {
        $miphosturl = 'localhost';
        $prefs->set( 'miphosturl', "$miphosturl" );
        $log->debug(
"SugarCube MIP URL not Set; $miphosturl for this client, default set to localhost\n"
        );
    }
    my $sugarlviconsize = $prefs->get('sugarlviconsize');

    if ( !defined $sugarlviconsize || $sugarlviconsize eq '' ) {
        $sugarlviconsize = '100';
        $prefs->set( 'sugarlviconsize', "$sugarlviconsize" );
        $log->debug(
"SugarCube Album Art not Set; $sugarlviconsize for this client, default set to 100\n"
        );
    }
    my $sugardelay = $prefs->get('sugardelay');
    if ( length($sugardelay) == 1 || length($sugardelay) == 2 ) {
    }
    else {
        $sugardelay = '1';
        $prefs->set( 'sugardelay', "$sugardelay" );
        $log->debug("SugarCube Delay set to 1\n");
    }
    my $sugarmipsize = $prefs->get('sugarmipsize');
    if (   length($sugarmipsize) == 1
        || length($sugarmipsize) == 2
        || length($sugarmipsize) == 3 )
    {
    }
    else {
        $sugarmipsize = '10';
        $prefs->set( 'sugarmipsize', "$sugarmipsize" );
        $log->debug("SugarCube MIPSize set to $sugarmipsize\n");
    }

    my $sugarlvwidth = $prefs->get('sugarlvwidth');
    if ( length($sugarlvwidth) == 2 || length($sugarlvwidth) == 3 ) {
    }
    else {
        $sugarlvwidth = '100';
        $prefs->set( 'sugarlvwidth', "$sugarlvwidth" );
        $log->debug("sugarlvwidth set to 100\n");
    }

    ####
    ####
    ####
    ####

    Slim::Control::Request::subscribe( \&commandCallback,
        [ [ 'play', 'pause', 'stop', 'power', 'playlist' ] ] );
    my $icon = Plugins::SugarCube::Plugin->_pluginDataFor('icon');

    my @menu = (
        {
            text      => Slim::Utils::Strings::string('PLUGIN_SUGARCUBE'),
            id        => 'pluginFoobarActivateSomething',
            'icon-id' => $icon,
            weight    => 20,
            actions   => {
                go => {
                    player => 0,
                    cmd    => [ 'sugarcube', 'menu' ],
                    params => { activate => '1', },
                }
            },
            window => {
                titleStyle => 'settings',
                'icon-id'  => $class->_pluginDataFor('icon')
            },
        },
    );
    Slim::Control::Jive::registerPluginMenu( \@menu, 'settings' );

    Slim::Control::Request::addDispatch( [ 'sugarcube', 'menu' ],
        [ 0, 0, 1, \&jiveSugarCubeMenu ] );
    Slim::Control::Request::addDispatch( [ 'sugarcube', 'setting' ],
        [ 1, 0, 1, \&jiveSugarCubeSetting ] );
    Slim::Control::Request::addDispatch(
        [ 'sugarcube', 'filters', '_filter' ],
        [ 1, 0, 0, \&jive_menu_save_filter ]
    );
    Slim::Control::Request::addDispatch(
        [ 'sugarcube', 'genre', '_genre' ],
        [ 1, 0, 0, \&jive_menu_save_genre ]
    );
    Slim::Control::Request::addDispatch(
        [ 'sugarcube', 'artist', '_artist' ],
        [ 1, 0, 0, \&jive_menu_save_artist ]
    );
    Slim::Control::Request::addDispatch(
        [ 'sugarcube', 'players', '_sendplayer' ],
        [ 1, 0, 0, \&jiveSugarCubeSetting ]
    );

    Slim::Menu::TrackInfo->registerInfoProvider(
        enable_disable => (
            before => 'playitem',
            func   => \&enable_disable,
        )
    );

    Slim::Menu::TrackInfo->registerInfoProvider(
        sugarcube => (
            before => 'playitem',
            func   => \&SCInfoMenu,
        )
    );

    Slim::Menu::TrackInfo->registerInfoProvider(
        mixfromhere => (
            before => 'playitem',
            func   => \&mixfromhere,
        )
    );

    Slim::Menu::TrackInfo->registerInfoProvider(
        playthealbum => (
            before => 'playitem',
            func   => \&playthealbum,
        )
    );
    Slim::Menu::TrackInfo->registerInfoProvider(
        flipmode => (
            before => 'playitem',
            func   => \&flipmode,
        )
    );

    Slim::Menu::TrackInfo->registerInfoProvider(
        sendtoplayer => (
            after => 'playthealbum',
            func  => \&sendtoplayer,
        )
    );

    Slim::Player::ProtocolHandlers->registerHandler(
        sugarcube => 'Plugins::SugarCube::ProtocolHandler' );

    getAlarmPlaylists();

}

sub postinitPlugin {
    my $class = shift;

    # if user has the Don't Stop The Music plugin enabled, register ourselves
    if (
        Slim::Utils::PluginManager->isEnabled(
            'Slim::Plugin::DontStopTheMusic::Plugin')
      )
    {
        require Slim::Plugin::DontStopTheMusic::Plugin;
        Slim::Plugin::DontStopTheMusic::Plugin->registerHandler(
            'PLUGIN_SUGARCUBE',
            sub {

                #	        $log->debug("##Got poked by DSTM Plugin##\n");
                my ( $client, $cb ) = @_;
                kickoff($client);
            }
        );
    }
	$TSenabled = Slim::Utils::PluginManager->isEnabled('Plugins::TrackStat::Plugin');
}

sub SCInfoMenu {
    my ( $client, $url, $obj, $remoteMeta, $tags, $objectType ) = @_;
    return unless $client;
    return {
        type      => 'redirect',
        name      => $client->string('PLUGIN_JIVE_NEXT'),
        favorites => 0,
        player    => {
            mode       => 'PLUGIN_JIVE_NEXT',
            modeParams => {
                objectType => $objectType,
                obj        => $obj,
            },
        },
        jive => {
            actions => {
                go => {
                    cmd    => [ 'sugarcube', 'setting', 'sugarcube_next:0' ],
                    params => {
                        menu => 1,
                        id   => $obj->id,
                    },
                    nextWindow => 'nowPlaying',
                }
            }
        },
    };
}

sub flipmode {
    my ( $client, $url, $obj, $remoteMeta, $tags, $objectType ) = @_;
    return unless $client;
    return {
        type      => 'redirect',
        name      => $client->string('PLUGIN_SG_MODE'),
        favorites => 0,
        player    => {
            mode       => 'PLUGIN_SG_MODE',
            modeParams => {
                objectType => $objectType,
                obj        => $obj,
            },
        },
        jive => {
            actions => {
                go => {
                    cmd    => [ 'sugarcube', 'setting', 'flipmode:0' ],
                    params => {
                        menu => 1,
                        id   => $obj->id,
                    },
                    nextWindow => 'nowPlaying',
                }
            }
        },
    };
}

sub enable_disable {
    my ( $client, $url, $obj, $remoteMeta, $tags, $objectType ) = @_;
    return unless $client;
    return {
        type      => 'redirect',
        name      => $client->string('PLUGIN_SUGARCUBE_TOGGLE'),
        favorites => 0,
        player    => {
            mode       => 'PLUGIN_SUGARCUBE_TOGGLE',
            modeParams => {
                objectType => $objectType,
                obj        => $obj,
            },
        },
        jive => {
            actions => {
                go => {
                    cmd    => [ 'sugarcube', 'setting', 'enable_disable:0' ],
                    params => {
                        menu => 1,
                        id   => $obj->id,
                    },
                    nextWindow => 'nowPlaying',
                }
            }
        },
    };

}

sub mixfromhere {
    my ( $client, $url, $obj, $remoteMeta, $tags, $objectType ) = @_;
    return unless $client;
    return {
        type      => 'redirect',
        name      => $client->string('PLUGIN_SG_MIXFROMHERE'),
        favorites => 0,
        player    => {
            mode       => 'PLUGIN_SG_MIXFROMHERE',
            modeParams => {
                objectType => $objectType,
                obj        => $obj,
            },
        },
        jive => {
            actions => {
                go => {
                    cmd    => [ 'sugarcube', 'setting', 'mixfromhere:0' ],
                    params => {
                        menu => 1,
                        id   => $obj->id,
                    },
                    nextWindow => 'nowPlaying',
                }
            }
        },
    };
}

sub playthealbum {
    my ( $client, $url, $obj, $remoteMeta, $tags, $objectType ) = @_;
    return unless $client;
    return {
        type      => 'redirect',
        name      => $client->string('PLUGIN_SG_PLAYALBUM'),
        favorites => 0,
        player    => {
            mode       => 'PLUGIN_SG_PLAYALBUM',
            modeParams => {
                objectType => $objectType,
                obj        => $obj,
            },
        },
        jive => {
            actions => {
                go => {
                    cmd    => [ 'sugarcube', 'setting', 'playalbum:0' ],
                    params => {
                        menu => 1,
                        id   => $obj->id,
                    },
                    nextWindow => 'nowPlaying',
                }
            }
        },
    };
}

sub sendtoplayer {
    my ( $client, $url, $obj, $remoteMeta, $tags, $objectType ) = @_;
    return unless $client;
    return {
        type      => 'redirect',
        name      => $client->string('PLUGIN_SG_SENDTOPLAYER'),
        favorites => 0,
        player    => {
            mode       => 'PLUGIN_SG_SENDTOPLAYER',
            modeParams => {
                objectType => $objectType,
                obj        => $obj,
            },
        },
        jive => {
            actions => {
                go => {
                    cmd    => [ 'sugarcube', 'setting', 'sendtoplayer:0' ],
                    params => {
                        menu => 1,
                        id   => $obj->id,
                    }
                }
            }
        },
    };
}

sub jiveSugarCubeMenu {

    no warnings 'numeric';    # stop annoying warnings about numerics

    $log->debug("jiveSugarCubeMenu\n");
    my $request = shift;
    my $client  = $request->client();

    if ( !defined $client ) {
        $request->setStatusNeedsClient();
        return;
    }
    my $sugarcube_style = $prefs->client($client)->get('sugarcube_style');
    my $style_menu;
    if ( $sugarcube_style == 0 || $sugarcube_style < 20 ) { $style_menu = 1; }
    elsif ( $sugarcube_style == 20 || $sugarcube_style < 40 ) {
        $style_menu = 2;
    }
    elsif ( $sugarcube_style == 40 || $sugarcube_style < 60 ) {
        $style_menu = 3;
    }
    elsif ( $sugarcube_style == 60 || $sugarcube_style < 80 ) {
        $style_menu = 4;
    }
    elsif ( $sugarcube_style == 80 || $sugarcube_style < 100 ) {
        $style_menu = 5;
    }
    elsif ( $sugarcube_style == 100 || $sugarcube_style < 120 ) {
        $style_menu = 6;
    }
    elsif ( $sugarcube_style == 120 || $sugarcube_style < 140 ) {
        $style_menu = 7;
    }
    elsif ( $sugarcube_style == 140 || $sugarcube_style < 160 ) {
        $style_menu = 8;
    }
    elsif ( $sugarcube_style == 160 || $sugarcube_style < 180 ) {
        $style_menu = 9;
    }
    elsif ( $sugarcube_style == 180 || $sugarcube_style < 200 ) {
        $style_menu = 10;
    }
    elsif ( $sugarcube_style == 200 ) { $style_menu = 11; }

    my $sugarcube_variety = $prefs->client($client)->get('sugarcube_variety');
    my $variety_menu;
    if    ( $sugarcube_variety == 0 ) { $variety_menu = 1; }
    elsif ( $sugarcube_variety == 1 ) { $variety_menu = 2; }
    elsif ( $sugarcube_variety == 2 ) { $variety_menu = 3; }
    elsif ( $sugarcube_variety == 3 ) { $variety_menu = 4; }
    elsif ( $sugarcube_variety == 4 ) { $variety_menu = 5; }
    elsif ( $sugarcube_variety == 5 ) { $variety_menu = 6; }
    elsif ( $sugarcube_variety == 6 ) { $variety_menu = 7; }
    elsif ( $sugarcube_variety == 7 ) { $variety_menu = 8; }
    elsif ( $sugarcube_variety == 8 ) { $variety_menu = 9; }
    elsif ( $sugarcube_variety == 9 ) { $variety_menu = 10; }

    my @menuItems = (
        {
            text =>
              Slim::Utils::Strings::string('PLUGIN_SUGARCUBE_JIVE_STATUS'),
            choiceStrings => [
                ucfirst( Slim::Utils::Strings::string('OFF') ),
                ucfirst( Slim::Utils::Strings::string('ON') )
            ],
            selectedIndex => $prefs->client($client)->get('sugarcube_status') +
              1,
            actions => {
                do => {
                    choices => [
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_status:0' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_status:1' ],
                        },
                    ]
                },
            },
        },
        {
            text          => Slim::Utils::Strings::string('PLUGIN_JIVE_NEXT'),
            choiceStrings => ["Replacing"],
            selectedIndex => 0,
            actions       => {
                do => {
                    choices => [
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_next:0' ],
                        },
                    ]
                },
            },
        },
        {
            text => Slim::Utils::Strings::string('PLUGIN_SUGARCUBE_KICKOFF'),
            choiceStrings => ["Starting"],
            selectedIndex => 0,
            actions       => {
                do => {
                    choices => [
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_auto:0' ],
                        },
                    ]
                },
            },
        },

        {
            text =>
              Slim::Utils::Strings::string('PLUGIN_SUGARCUBE_JIVE_VOLUME_FADE'),
            choiceStrings => [
                ucfirst( Slim::Utils::Strings::string('OFF') ),
                ucfirst( Slim::Utils::Strings::string('ON') )
            ],
            selectedIndex =>
              $prefs->client($client)->get('sugarcube_volume_flag') + 1,
            actions => {
                do => {
                    choices => [
                        {
                            player => 0,
                            cmd    => [
                                'sugarcube', 'setting',
                                'sugarcube_volume_flag:0'
                            ],
                        },
                        {
                            player => 0,
                            cmd    => [
                                'sugarcube', 'setting',
                                'sugarcube_volume_flag:1'
                            ],
                        },
                    ]
                },
            },
        },
        {
            text => Slim::Utils::Strings::string('PLUGIN_SUGARCUBE_JIVE_SLEEP'),
            choiceStrings => [
                ucfirst( Slim::Utils::Strings::string('OFF') ),
                ucfirst( Slim::Utils::Strings::string('ON') )
            ],
            selectedIndex => $prefs->client($client)->get('sugarcube_sleep') +
              1,
            actions => {
                do => {
                    choices => [
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_sleep:0' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_sleep:1' ],
                        },
                    ]
                },
            },
        },
        {
            text =>
              Slim::Utils::Strings::string('PLUGIN_SUGARCUBE_JIVE_UPNEXT'),
            choiceStrings => [
                ucfirst( Slim::Utils::Strings::string('OFF') ),
                ucfirst( Slim::Utils::Strings::string('ON') )
            ],
            selectedIndex => $prefs->client($client)->get('sugarcube_upnext') +
              1,
            actions => {
                do => {
                    choices => [
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_upnext:0' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_upnext:1' ],
                        },
                    ]
                },
            },
        },

        {
            text =>
              Slim::Utils::Strings::string('PLUGIN_SUGARCUBE_JIVE_SHUFFLE'),
            choiceStrings => [
                ucfirst( Slim::Utils::Strings::string('OFF') ),
                ucfirst( Slim::Utils::Strings::string('ON') )
            ],
            selectedIndex => $prefs->client($client)->get('sugarcube_shuffle')
              + 1,
            actions => {
                do => {
                    choices => [
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_shuffle:0' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_shuffle:1' ],
                        },
                    ]
                },
            },
        },
        {
            text =>
              Slim::Utils::Strings::string('PLUGIN_SUGARCUBE_JIVE_MIXTYPE'),
            selectedIndex => $prefs->client($client)->get('sugarcube_mix_type')
              + 1,
            choiceStrings => [ "None", "Filter", "Genre", "Artist" ],
            actions       => {
                do => {
                    choices => [
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_mixtype:0' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_mixtype:1' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_mixtype:2' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_mixtype:3' ],
                        },
                    ],
                },
            },
        },
        {
            text    => Slim::Utils::Strings::string('PLUGIN_ARTISTS'),
            actions => {
                go => {
                    player => 0,
                    cmd =>
                      [ 'sugarcube', 'setting', 'sugarcube_artisttypes:0' ],
                },
            },
        },
        {
            text    => Slim::Utils::Strings::string('PLUGIN_FILTERS'),
            actions => {
                go => {
                    player => 0,
                    cmd =>
                      [ 'sugarcube', 'setting', 'sugarcube_filtertypes:0' ],
                },
            },
        },
        {
            text    => Slim::Utils::Strings::string('PLUGIN_GENRES'),
            actions => {
                go => {
                    player => 0,
                    cmd => [ 'sugarcube', 'setting', 'sugarcube_genretypes:0' ],
                },
            },
        },

        {
            text =>
              Slim::Utils::Strings::string('PLUGIN_SUGARCUBE_JIVE_SONG_ALBUM'),
            selectedIndex =>
              $prefs->client($client)->get('sugarcube_album_song') + 1,
            choiceStrings => [ "Album", "Song" ],
            actions       => {
                do => {
                    choices => [
                        {
                            player => 0,
                            cmd    => [
                                'sugarcube', 'setting',
                                'sugarcube_album_song:0'
                            ],
                        },
                        {
                            player => 0,
                            cmd    => [
                                'sugarcube', 'setting',
                                'sugarcube_album_song:1'
                            ],
                        },
                    ],
                },
            },
        },
        {
            text =>
              Slim::Utils::Strings::string('PLUGIN_SUGARCUBE_JIVE_MIXSTYLE'),
            selectedIndex => $style_menu,
            choiceStrings => [
                "0",   "20",  "40",  "60",  "80", "100",
                "120", "140", "160", "180", "200"
            ],
            actions => {
                do => {
                    choices => [
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_style:0' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_style:20' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_style:40' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_style:60' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_style:80' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_style:100' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_style:120' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_style:140' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_style:160' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_style:180' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_style:200' ],
                        },
                    ],
                },
            },
        },
        {
            text =>
              Slim::Utils::Strings::string('PLUGIN_SUGARCUBE_JIVE_VARIETY'),
            selectedIndex => $variety_menu,
            choiceStrings =>
              [ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" ],
            actions => {
                do => {
                    choices => [
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_variety:0' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_variety:1' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_variety:2' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_variety:3' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_variety:4' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_variety:5' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_variety:6' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_variety:7' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_variety:8' ],
                        },
                        {
                            player => 0,
                            cmd =>
                              [ 'sugarcube', 'setting', 'sugarcube_variety:9' ],
                        },
                    ],
                },
            },
        },
    );
    my $cnt = 0;
    foreach my $item (@menuItems) {
        $request->setResultLoopHash( 'item_loop', $cnt, $item );
        $cnt++;
    }
    $request->addResult( 'offset', 0 );
    $request->addResult( 'count',  scalar(@menuItems) );
    $request->setStatusDone();
}

sub filter_filter {
    $log->debug("Filter_filter\n");

    my $request   = shift;
    my $client    = $request->client();
    my $l_filters = Plugins::SugarCube::PlayerSettings::getFilterList($client);
    my @listRef   = ();
    foreach my $filter ( sort keys %$l_filters ) {
        push @listRef, $l_filters->{$filter};
    }

    my $activefilter = $prefs->client($client)->get('sugarcube_filteractive');

    my @filtermenu = ();
    my $val;
    foreach my $filter (@listRef) {
        if ( $filter eq $activefilter ) {
            $val = 1;
        }
        else { $val = 0; }
        push @filtermenu,
          {
            id      => $filter,
            text    => $filter,
            radio   => $val,
            actions => {
                do => {
                    player => 0,
                    cmd    => [ 'sugarcube', 'filters', $filter ],
                },
            },
          };
    }

    my $numitems = scalar(@filtermenu);

    $request->addResult( "base", { window => { titleStyle => 'noidea' } } );
    $request->addResult( "count",  $numitems );
    $request->addResult( "offset", 0 );
    my $cnt = 0;
    for my $eachPreset ( @filtermenu[ 0 .. $#filtermenu ] ) {
        $request->setResultLoopHash( 'item_loop', $cnt, $eachPreset );
        $cnt++;
    }

    $request->setStatusDone();

    Slim::Control::Jive::sliceAndShip( $request, $client, \@filtermenu );
}

sub artist_filter {
    $log->debug("artist_filter\n");
    my $request = shift;
    my $client  = $request->client();

    my $artists = Plugins::SugarCube::PlayerSettings::getArtistsList($client);

    my @listRef = ();
    foreach my $artist ( sort keys %$artists ) {
        push @listRef, $artists->{$artist};
    }

    my $activefilter = $prefs->client($client)->get('sugarcube_artist');

    my @filtermenu = ();
    my $val;
    foreach my $artist (@listRef) {
        if ( $artist eq $activefilter ) {
            $val = 1;
        }
        else { $val = 0; }
        push @filtermenu,
          {
            id      => $artist,
            text    => $artist,
            radio   => $val,
            actions => {
                do => {
                    player => 0,
                    cmd    => [ 'sugarcube', 'artist', $artist ],
                },
            },
          };
    }

    my $numitems = scalar(@filtermenu);

    $request->addResult( "base", { window => { titleStyle => 'noidea' } } );
    $request->addResult( "count",  $numitems );
    $request->addResult( "offset", 0 );
    my $cnt = 0;
    for my $eachPreset ( @filtermenu[ 0 .. $#filtermenu ] ) {
        $request->setResultLoopHash( 'item_loop', $cnt, $eachPreset );
        $cnt++;
    }

    $request->setStatusDone();

    Slim::Control::Jive::sliceAndShip( $request, $client, \@filtermenu );
}

sub genre_filter {
    $log->debug("Genre_filter\n");

    my $request = shift;
    my $client  = $request->client();

    my $genres  = Plugins::SugarCube::PlayerSettings::getGenresList($client);
    my @listRef = ();
    foreach my $genre ( sort keys %$genres ) {
        push @listRef, $genres->{$genre};
    }

    my $activefilter = $prefs->client($client)->get('sugarcube_genre');

    my @filtermenu = ();
    my $val;
    foreach my $genre (@listRef) {
        if ( $genre eq $activefilter ) {
            $val = 1;
        }
        else { $val = 0; }
        push @filtermenu,
          {
            id      => $genre,
            text    => $genre,
            radio   => $val,
            actions => {
                do => {
                    player => 0,
                    cmd    => [ 'sugarcube', 'genre', $genre ],
                },
            },
          };
    }

    my $numitems = scalar(@filtermenu);

    $request->addResult( "base", { window => { titleStyle => 'noidea' } } );
    $request->addResult( "count",  $numitems );
    $request->addResult( "offset", 0 );
    my $cnt = 0;
    for my $eachPreset ( @filtermenu[ 0 .. $#filtermenu ] ) {
        $request->setResultLoopHash( 'item_loop', $cnt, $eachPreset );
        $cnt++;
    }

    $request->setStatusDone();

    Slim::Control::Jive::sliceAndShip( $request, $client, \@filtermenu );
}

sub playalbum {
    my $client   = shift;
    my $song     = Slim::Player::Playlist::url($client);
    my $SCQAlbum = Plugins::SugarCube::Breakout::getalbum( $client, $song );
    my $request  = $client->execute( [ "playlist", 'clear' ] );
    my $request =
      $client->execute( [ "playlist", 'addtracks', "album.id=$SCQAlbum" ] );
    my $request = $client->execute( ["play"] );
    my $msg = ('Album Queued');
    $client->showBriefly(
        {
            'jive' => {
                'type' => 'popupplay',
                'text' => [ $client->string('PLUGIN_SUGARCUBE'), ' ', $msg ],
              }

        }
    );
}

sub toggle_state {
    my $request   = shift;
    my $whocalled = shift;
    my $client;

    no warnings 'numeric';

    if ( $whocalled eq "yes" )
    {    # if yes then came from web page otherwise came from player
        $client = $request;
    }
    else {
        $client = $request->client();
    }

    my $msg;

    #	my $current_status = $prefs->client($client)->get('sugarcube_status');
    if ( $prefs->client($client)->get('sugarcube_status') == 1 ) {    # Enabled
        $msg = 'SugarCube DISABLED';
        $prefs->client($client)->set( 'sugarcube_status', "0" );
    }
    else {
        $msg = 'SugarCube ENABLED';
        $prefs->client($client)->set( 'sugarcube_status', "1" );
    }

    $client->showBriefly(
        {
            'jive' => {
                'type' => 'popupplay',
                'text' => [ $client->string('PLUGIN_SUGARCUBE'), ' ', $msg ],
            }
        }
    );

}

# Fires an Auto Mix.  Called from player or from web page
sub mixfromplaying {
    my $request   = shift;
    my $whocalled = shift;
    my $client;

    no warnings 'numeric';

    if ( $whocalled eq "yes" )
    {    # if yes then came from web page otherwise came from player
        $client = $request;
    }
    else {
        $client = $request->client();
    }

    my $msg = 'SugarCube is creating Mix';

    $client->showBriefly(
        {
            'jive' => {
                'type' => 'popupplay',
                'text' => [ $client->string('PLUGIN_SUGARCUBE'), ' ', $msg ],
            }
        }
    );

    AutoStartMix($client);

}

# Send Request to MIP Async
# Set up Async HTTP request
sub sc_one_off {
    my $client    = shift;
    my $mypageurl = shift;
    my $http      = Slim::Networking::SimpleAsyncHTTP->new(
        \&gotMIP,
        \&gotErrorViaHTTP,
        {
            caller     => 'SpiceflyONE',
            callerProc => \&sc_one_off,
            client     => $client,
            timeout    => 60
        }
    );
    $log->debug("Sending URL Request;\n $mypageurl\n");
    $http->get($mypageurl);
}

sub flipmixmode {
    no warnings 'numeric';

    my $request = shift;
    my $client  = $request->client();
    my $msg;
    my $sugarcube_mode = $prefs->client($client)->get('sugarcube_mode');
    if ( $sugarcube_mode == 0 || $sugarcube_mode eq '' )
    {    # Standard MusicIP Mode - default failback if no prefs set
        $prefs->client($client)->set( 'sugarcube_mode', 1 );
        $msg = ('FreeStyle Mode Engaged');
    }
    else {
        $prefs->client($client)->set( 'sugarcube_mode', 0 );
        $msg = ('MusicIP Mode Engaged');
    }

    $client->showBriefly(
        {
            'jive' => {
                'type' => 'popupplay',
                'text' => [ $client->string('PLUGIN_SUGARCUBE'), ' ', $msg ],
            }
        }
    );
}

sub sendtoanotherplayer {
    my $request   = shift;
    my $client    = $request->client();
    my $myplayers = Plugins::SugarCube::PlayerSettings::grabPlayers();
    my @listRef   = ();
    foreach my $player ( sort keys %$myplayers ) {
        push @listRef, $myplayers->{$player};
    }

    my @filtermenu = ();
    my $val;
    foreach my $player (@listRef) {
        $val = 0;
        push @filtermenu,
          {
            id      => $player,
            text    => $player,
            radio   => $val,
            actions => {
                do => {
                    player => 0,
                    cmd    => [ 'sugarcube', 'players', $player ],
                },
            },
          };
    }
    my $numitems = scalar(@filtermenu);

    $request->addResult( "base", { window => { titleStyle => 'noidea' } } );
    $request->addResult( "count",  $numitems );
    $request->addResult( "offset", 0 );
    my $cnt = 0;
    for my $eachPreset ( @filtermenu[ 0 .. $#filtermenu ] ) {
        $request->setResultLoopHash( 'item_loop', $cnt, $eachPreset );
        $cnt++;
    }
    $request->setStatusDone();
    Slim::Control::Jive::sliceAndShip( $request, $client, \@filtermenu );
}

sub jive_menu_save_genre {
    my $request = shift;
    my $client  = $request->client();

    $log->debug("jive_menu_save_genre\n");

    if ( !defined $client ) {
        $request->setStatusNeedsClient();
        return;
    }
    if ( defined( $request->getParam('_genre') ) ) {
        $log->debug("Save Genres\n");
        $prefs->client($client)
          ->set( 'sugarcube_genre', $request->getParam('_genre') );
    }
    $request->setStatusDone();
}

sub jive_menu_save_artist {
    my $request = shift;
    my $client  = $request->client();

    $log->debug("jive_menu_save_artist\n");

    if ( !defined $client ) {
        $request->setStatusNeedsClient();
        return;
    }
    if ( defined( $request->getParam('_artist') ) ) {
        $log->debug("Save Artist . $request->getParam('_artist') \n");
        $prefs->client($client)
          ->set( 'sugarcube_artist', $request->getParam('_artist') );
    }
    $request->setStatusDone();
}

# Jive Menu Save Filter
sub jive_menu_save_filter {
    my $request = shift;
    my $client  = $request->client();

    #	$log->debug("jive_menu_save_filter\n");

    if ( !defined $client ) {
        $request->setStatusNeedsClient();
        return;
    }
    if ( defined( $request->getParam('_filter') ) ) {
        $log->debug("Param _filter\n");
        $prefs->client($client)
          ->set( 'sugarcube_filteractive', $request->getParam('_filter') );
    }
    $request->setStatusDone();
}

sub jiveSugarCubeSetting {
    no warnings 'numeric';

    my $request = shift;
    my $client  = $request->client();

    #	$log->debug("jiveSugarCubeSetting\n");

    if ( !defined $client ) { $request->setStatusNeedsClient(); return; }

    if ( defined( $request->getParam('sugarcube_volume_flag') ) ) {
        $prefs->client($client)
          ->set( 'sugarcube_volume_flag',
            $request->getParam('sugarcube_volume_flag') );
    }
    if ( defined( $request->getParam('sugarcube_next') ) ) {
        SugarCubeReplaceNext($client);
    }
    if ( defined( $request->getParam('playalbum') ) ) {
        playalbum($client);
    }
    if ( defined( $request->getParam('flipmode') ) ) {
        flipmixmode($request);
    }
    if ( defined( $request->getParam('enable_disable') ) ) {
        toggle_state( $request, "no" );
    }
    if ( defined( $request->getParam('mixfromhere') ) ) {
        mixfromplaying( $request, "no" );
    }
    if ( defined( $request->getParam('sendtoplayer') ) ) {
        sendtoanotherplayer($request);
    }

    # goes into a random loop for reasons unknown
    if ( defined( $request->getParam('sugarcube_artisttypes') ) ) {
        artist_filter($request);
    }

    if ( defined( $request->getParam('sugarcube_filtertypes') ) ) {
        filter_filter($request);
    }
    if ( defined( $request->getParam('sugarcube_genretypes') ) ) {
        genre_filter($request);
    }
    if ( defined( $request->getParam('sugarcube_auto') ) ) {
        AutoStartMix($client);
    }

    if ( defined( $request->getParam('_sendplayer') ) ) {
        my $newplayer = $request->getParam('_sendplayer');
        my $player    = Slim::Player::Client::getClient($newplayer);
        my $song      = Slim::Player::Playlist::url($client);
        my $track     = Slim::Utils::Misc::pathFromFileURL($song);
        my $request   = $player->execute( [ "playlist", 'clear' ] );
        my $request   = $player->execute( [ "playlist", "add", $track ] );
        my $request   = $player->execute( ["play"] );
    }

    if ( defined( $request->getParam('sugarcube_sleep') ) ) {
        $prefs->client($client)
          ->set( 'sugarcube_sleep', $request->getParam('sugarcube_sleep') );
    }
    if ( defined( $request->getParam('sugarcube_status') ) ) {
        $prefs->client($client)
          ->set( 'sugarcube_status', $request->getParam('sugarcube_status') );
        if ( $request->getParam('sugarcube_status') == 1 ) {
            SugarCubeEnabled($client);
        }
        else { SugarCubeDisabled($client) }
    }
    if ( defined( $request->getParam('sugarcube_shuffle') ) ) {
        $prefs->client($client)
          ->set( 'sugarcube_shuffle', $request->getParam('sugarcube_shuffle') );
    }
    if ( defined( $request->getParam('sugarcube_upnext') ) ) {
        $prefs->client($client)
          ->set( 'sugarcube_upnext', $request->getParam('sugarcube_upnext') );
    }
    if ( defined( $request->getParam('sugarcube_mixtype') ) ) {
        $prefs->client($client)
          ->set( 'sugarcube_mix_type',
            $request->getParam('sugarcube_mixtype') );
    }
    if ( defined( $request->getParam('sugarcube_album_song') ) ) {
        $prefs->client($client)
          ->set( 'sugarcube_album_song',
            $request->getParam('sugarcube_album_song') );
    }
    if ( defined( $request->getParam('sugarcube_style') ) ) {
        $prefs->client($client)
          ->set( 'sugarcube_style', $request->getParam('sugarcube_style') );
    }
    if ( defined( $request->getParam('sugarcube_variety') ) ) {
        $prefs->client($client)
          ->set( 'sugarcube_variety', $request->getParam('sugarcube_variety') );
    }
    $request->setStatusDone();
}

sub shutdownPlugin {
    Slim::Control::Request::unsubscribe( \&commandCallback );
}

sub SugarCubeReplaceNext {
    no warnings 'numeric';

    my $client = shift;
    my $request;
    my $songIndex = Slim::Player::Source::streamingSongIndex($client);
    $songIndex++;
    my $listlength = Slim::Player::Playlist::count($client);
    if ( $listlength == 1 || $listlength == 0 || $listlength == $songIndex ) {
    }
    else {
        (
            my $UPNArtist,
            my $UPNTrack,
            my $UPNAlbum,
            my $UPNGenre,
            my $UPNAlbumArt,
            my $UPNFULLAlbum
        ) = Plugins::SugarCube::Breakout::getmyNextSong($client);
        Plugins::SugarCube::Breakout::SaveHistory( $client, $UPNArtist,
            $UPNTrack, $UPNAlbum, $UPNGenre, $UPNAlbumArt, $UPNFULLAlbum );
        $request = $client->execute( [ 'playlist', 'delete', $songIndex ] );
    }
    my $msg = ('Replacing Track');
    $client->showBriefly(
        {
            'jive' => {
                'type' => 'popupplay',
                'text' => [ $client->string('PLUGIN_SUGARCUBE'), ' ', $msg ],
              }

        }
    );
    kickoff($client);
}

sub setMode {
    no warnings 'numeric';

    my $class  = shift;
    my $client = shift;
    my $method = shift || '';
    my $item;
    if ( $method eq 'pop' ) { Slim::Buttons::Common::popMode($client); return; }
    my $sugarcube_status = $prefs->client($client)->get('sugarcube_status');
    my $sugarcube_upnext = $prefs->client($client)->get('sugarcube_upnext');
    my $sugarcube_volume_flag =
      $prefs->client($client)->get('sugarcube_volume_flag');
    my $sugarcube_sleep   = $prefs->client($client)->get('sugarcube_sleep');
    my $sugarcube_shuffle = $prefs->client($client)->get('sugarcube_shuffle');

    my @topMenuItems = ();
    push @topMenuItems, '{PLUGIN_SUGARCUBE_KICKOFF}';

    if ( $sugarcube_status == 1 ) {
        push @topMenuItems, '{PLUGIN_SUGARCUBE_INJECTOR_OFF}';
    }
    if ( $sugarcube_status == 0 ) {
        push @topMenuItems, '{PLUGIN_SUGARCUBE_INJECTOR_ON}';
    }
    push @topMenuItems, '{PLUGIN_JIVE_NEXT}';
    push @topMenuItems, '{PLUGIN_SG_PLAYALBUM}';    #test

    if ( $sugarcube_sleep == 1 ) {
        push @topMenuItems, '{PLUGIN_SUGARCUBE_SLEEP_OFF}';
    }
    if ( $sugarcube_sleep == 0 ) {
        push @topMenuItems, '{PLUGIN_SUGARCUBE_SLEEP_ON}';
    }
    if ( $sugarcube_volume_flag == 1 ) {
        push @topMenuItems, '{PLUGIN_SUGARCUBE_VOLUME_FADE_OFF}';
    }
    if ( $sugarcube_volume_flag == 0 ) {
        push @topMenuItems, '{PLUGIN_SUGARCUBE_VOLUME_FADE_ON}';
    }
    if ( $sugarcube_upnext == 1 ) {
        push @topMenuItems, '{PLUGIN_SUGARCUBE_UPNEXT_OFF}';
    }
    if ( $sugarcube_upnext == 0 ) {
        push @topMenuItems, '{PLUGIN_SUGARCUBE_UPNEXT_ON}';
    }
    if ( $sugarcube_shuffle == 1 ) {
        push @topMenuItems, '{PLUGIN_SUGARCUBE_SHUFFLEOFF}';
    }
    if ( $sugarcube_shuffle == 0 ) {
        push @topMenuItems, '{PLUGIN_SUGARCUBE_SHUFFLEON}';
    }
    push @topMenuItems, '{PLUGIN_FILTERS}';
    push @topMenuItems, '{PLUGIN_GENRES}';
    push @topMenuItems, '{PLUGIN_ARTISTS}';

    push @topMenuItems, '{PLUGIN_SC_MENU_MIXTYPE}';

    my %params = (
        header   => '{PLUGIN_SUGARCUBE} {count}',
        listRef  => \@topMenuItems,
        modeName => 'MYSUGARCUBE',
        onRight  => sub {
            ( $client, $item ) = @_;
            enterCategoryItem( $client, $item );
            $client->update();
        },
    );
    if ( $method eq 'push' ) {
        Slim::Buttons::Common::pushModeLeft( $client, 'INPUT.Choice',
            \%params );
    }
    else {
        Slim::Buttons::Common::pushMode( $client, 'INPUT.Choice', \%params );
        $client->update();
    }
}

sub getDisplayText {
    my ( $client, $item ) = @_;
    my $name = '';
    if ($item) {
        $name = $item->{'name'};
    }
    return $name;
}

sub getFunctions {
    return {};
}

sub enterCategoryItem {
    no warnings 'numeric';

    my $client = shift;
    my $item   = shift;
    if ( $item eq '{PLUGIN_SUGARCUBE_VOLUME_FADE_ON}' ) {
        ToggleVolume( $client, $item );
    }
    elsif ( $item eq '{PLUGIN_SUGARCUBE_KICKOFF}' ) {
        AutoStartMix( $client, $item );
    }
    elsif ( $item eq '{PLUGIN_SUGARCUBE_VOLUME_FADE_OFF}' ) {
        ToggleVolume( $client, $item );
    }
    elsif ( $item eq '{PLUGIN_SUGARCUBE_SLEEP_ON}' ) {
        ToggleSleep( $client, $item );
    }
    elsif ( $item eq '{PLUGIN_SUGARCUBE_SLEEP_OFF}' ) {
        ToggleSleep( $client, $item );
    }
    elsif ( $item eq '{PLUGIN_SUGARCUBE_INJECTOR_ON}' ) {
        ToggleInjector( $client, $item );
    }
    elsif ( $item eq '{PLUGIN_SUGARCUBE_INJECTOR_OFF}' ) {
        ToggleInjector( $client, $item );
    }
    elsif ( $item eq '{PLUGIN_SUGARCUBE_UPNEXT_ON}' ) {
        UpNext( $client, $item );
    }
    elsif ( $item eq '{PLUGIN_SUGARCUBE_UPNEXT_OFF}' ) {
        UpNext( $client, $item );
    }
    elsif ( $item eq '{PLUGIN_SUGARCUBE_SHUFFLEON}' ) {
        Shuffle( $client, $item );
    }
    elsif ( $item eq '{PLUGIN_SUGARCUBE_SHUFFLEOFF}' ) {
        Shuffle( $client, $item );
    }
    elsif ( $item eq '{PLUGIN_JIVE_NEXT}' ) {
        SugarCubeReplaceNext($client);
    }
    elsif ( $item eq '{PLUGIN_SG_PLAYALBUM}' ) {
        playalbum($client);
    }

    elsif ( $item eq '{PLUGIN_FILTERS}' ) {
        my $genres = Plugins::SugarCube::PlayerSettings::getFilterList($client);
        my @listRef = ();
        foreach my $genre ( sort keys %$genres ) {
            push @listRef, $genres->{$genre};
        }
        Slim::Buttons::Common::pushModeLeft(
            $client,
            'INPUT.Choice',
            {
                header         => '{PLUGIN_FILTERS}',
                headerAddCount => 1,
                listRef        => \@listRef,
                modeName       => 'MYSUGARCUBE',
                overlayRef     => sub {
                    my ( $client, $account ) = @_;
                    my $curAccount =
                      $prefs->client($client)->get('sugarcube_filteractive');
                    if ( $account eq $curAccount ) {
                        return [ undef, '[X]' ];
                    }
                    else {
                        return [ undef, '[ ]' ];
                    }
                },
                callback => sub {
                    my ( $client, $exittype ) = @_;
                    $exittype = uc $exittype;
                    if ( $exittype eq 'LEFT' ) {
                        Slim::Buttons::Common::popModeRight($client);
                    }
                    elsif ( $exittype eq 'RIGHT' ) {
                        my $value = $client->modeParam('valueRef');
                        my $curAccount;
                        if ( $$value == 0 ) { $curAccount = "(None)"; }
                        $prefs->client($client)
                          ->set( 'sugarcube_filteractive', "$$value" );
                        $client->update();
                    }
                    else {
                        $client->bumpRight;
                    }
                },
            }
        );
        $client->update();
    }

    elsif ( $item eq '{PLUGIN_GENRES}' ) {
        my $genres = Plugins::SugarCube::PlayerSettings::getGenresList($client);
        my @listRef = ();
        foreach my $genre ( sort keys %$genres ) {
            push @listRef, $genres->{$genre};
        }
        Slim::Buttons::Common::pushModeLeft(
            $client,
            'INPUT.Choice',
            {
                header         => '{PLUGIN_FILTERS}',
                headerAddCount => 1,
                listRef        => \@listRef,
                modeName       => 'MYSUGARCUBE',
                overlayRef     => sub {
                    my ( $client, $account ) = @_;
                    my $curAccount =
                      $prefs->client($client)->get('sugarcube_genre');
                    if ( $account eq $curAccount ) {
                        return [ undef, '[X]' ];
                    }
                    else {
                        return [ undef, '[ ]' ];
                    }
                },
                callback => sub {
                    my ( $client, $exittype ) = @_;
                    $exittype = uc $exittype;
                    if ( $exittype eq 'LEFT' ) {
                        Slim::Buttons::Common::popModeRight($client);
                    }
                    elsif ( $exittype eq 'RIGHT' ) {
                        my $value = $client->modeParam('valueRef');

                        $prefs->client($client)
                          ->set( 'sugarcube_genre', "$value" );
                        $client->update();

                    }
                    else {
                        $client->bumpRight;
                    }
                },
            }
        );
        $client->update();
    }
    elsif ( $item eq '{PLUGIN_ARTISTS}' ) {
        my $genres =
          Plugins::SugarCube::PlayerSettings::getArtistsList($client);
        my @listRef = ();
        foreach my $genre ( sort keys %$genres ) {
            push @listRef, $genres->{$genre};
        }
        Slim::Buttons::Common::pushModeLeft(
            $client,
            'INPUT.Choice',
            {
                header         => '{PLUGIN_ARTISTS}',
                headerAddCount => 1,
                listRef        => \@listRef,
                modeName       => 'MYSUGARCUBE',
                overlayRef     => sub {
                    my ( $client, $account ) = @_;
                    my $curAccount =
                      $prefs->client($client)->get('sugarcube_artist');
                    if ( $account eq $curAccount ) {
                        return [ undef, '[X]' ];
                    }
                    else {
                        return [ undef, '[ ]' ];
                    }
                },
                callback => sub {
                    my ( $client, $exittype ) = @_;
                    $exittype = uc $exittype;
                    if ( $exittype eq 'LEFT' ) {
                        Slim::Buttons::Common::popModeRight($client);
                    }
                    elsif ( $exittype eq 'RIGHT' ) {
                        my $value = $client->modeParam('valueRef');

                        $prefs->client($client)
                          ->set( 'sugarcube_artist', "$value" );
                        $client->update();

                    }
                    else {
                        $client->bumpRight;
                    }
                },
            }
        );
        $client->update();
    }

    elsif ( $item eq '{PLUGIN_SC_MENU_MIXTYPE}' ) {
        my @listRef = ();
        push @listRef, '(None)';
        push @listRef, 'Filter Mixing';
        push @listRef, 'Genre Mixing';
        push @listRef, 'Artist Mixing';

        Slim::Buttons::Common::pushModeLeft(
            $client,
            'INPUT.Choice',
            {
                header         => '{PLUGIN_SC_MENU_MIXTYPE}',
                headerAddCount => 1,
                listRef        => \@listRef,
                modeName       => 'MYSUGARCUBE',
                overlayRef     => sub {
                    my ( $client, $account ) = @_;

                    my $curAccount =
                      $prefs->client($client)->get('sugarcube_mix_type');

                    if ( $curAccount == 0 ) { $curAccount = '(None)'; }
                    if ( $curAccount == 1 ) { $curAccount = 'Filter Mixing'; }
                    if ( $curAccount == 2 ) { $curAccount = 'Genre Mixing'; }
                    if ( $curAccount == 3 ) { $curAccount = 'Artist Mixing'; }

                    if ( $account eq $curAccount ) {
                        return [ undef, '[X]' ];
                    }
                    else {
                        return [ undef, '[ ]' ];
                    }
                },
                callback => sub {
                    my ( $client, $exittype ) = @_;
                    $exittype = uc $exittype;
                    if ( $exittype eq 'LEFT' ) {
                        Slim::Buttons::Common::popModeRight($client);
                    }
                    elsif ( $exittype eq 'RIGHT' ) {
                        my $value = $client->modeParam('valueRef');
                        my $curAccount;
                        my $savevalue;

                        if ( $$value eq '(None)' )        { $savevalue = 0 }
                        if ( $$value eq 'Filter Mixing' ) { $savevalue = 1 }
                        if ( $$value eq 'Genre Mixing' )  { $savevalue = 2 }
                        if ( $$value eq 'Artist Mixing' ) { $savevalue = 3 }

                        $prefs->client($client)
                          ->set( 'sugarcube_mix_type', "$savevalue" );
                        $client->update();
                    }
                    else {
                        $client->bumpRight;
                    }
                },
            }
        );
        $client->update();
    }
}

# Fires on track change and when timers expire
sub kickoff {
    no warnings 'numeric';

    my $client = shift;
    return unless $client;    # Catch when client has disappeared
    my $track;
    my $song;

    my $quicksong = Slim::Player::Playlist::url($client);

    # BLOCK STREAMS
    if ( Slim::Music::Info::isRemoteURL($quicksong) == 1 ) {
        return;
    }

    #  If making changes here dont forget to make same in SugarPlayerCheck
    #  If streaming dont queue up a track
    if (   $quicksong =~ m/^napster:/i
        || $quicksong =~ m/.pls/i
        || $quicksong =~ m/http:/i
        || $quicksong =~ m/.asx/i
        || $quicksong =~ m/rtmp:/i
        || $quicksong =~ m/^lfm:/i
        || $quicksong =~ m/^pandora:/i
        || $quicksong =~ m/^slacker:/i
        || $quicksong =~ m/^live365:/i
        || $quicksong =~ m/^mediafly:/i
        || $quicksong =~ m/^mog:/i
        || $quicksong =~ m/https:/i
        || $quicksong =~ m/^deezer:/i
        || $quicksong =~ m/^spotify:/i
        || $quicksong =~ m/^rhapd:/i
        || $quicksong =~ m/^classical:/i
        || $quicksong =~ m/^loop:/i )
    {    #  Check whether we are streaming if so abort
        return;
    }

    if ( !defined($song) ) { $song = Slim::Player::Playlist::url($client); }

   #  If playing tracks not in the library LMS uses tmp which you cant seed from
   #  Try replacing it with file and then request a track
    if ( $song =~ m/^tmp:/i ) {
        my $z = substr $song, 0, 3, "file";    # replaces tmp with file
    }

    $track = Slim::Utils::Misc::pathFromFileURL($song);
    my $untouchedtrack = $track;

    $track = Plugins::SugarCube::Plugin::dirtyencoder($track);
    Plugins::SugarCube::Breakout::TrackTracker( $client, $track )
      if length $track;                        # if Track isnt empty

# Dynamic queuing - if we are playing the last track in the current playing queue
    my $sugarcube_dynamicq = $prefs->client($client)->get('sugarcube_dynamicq')
      ;                                        # Check dynamic queueing enabled

    if ( $sugarcube_dynamicq == 1 ) {
        my $scposition = Plugins::SugarCube::Breakout::CheckPosition($client)
          ;    #  If we dont require a track exit the routine

        if ( $scposition != 1 ) {
            $prefs->client($client)->set( 'sugarcube_working', 0 )
              ;    # reset for the stats page
            return;
        }
    }
    $prefs->client($client)->set( 'sugarcube_working', 1 )
      ;            # reset for the stats page
    $prefs->client($client)->set( 'sugarcube_stats_mip_size', "A" )
      ;            # reset tracking for whether MIP is OK or not

    #
    # Add routine to randomly select a track here
    #
    my $sugarcube_mode = $prefs->client($client)->get('sugarcube_mode');

    if ( $sugarcube_mode == 0 || $sugarcube_mode eq '' )
    {    # Standard MusicIP Mode - default failback if no prefs set
        my $mypageurl = buildMIPReq( $client, $untouchedtrack );
        my $diditwork = SendtoMIPAsync( $client, $mypageurl );
    }
    else {
        FreeStyle($client);    # FreeStyle Mode
    }
}

####
sub FreeStyle {
    no warnings 'numeric';
    my $client = shift;

    my $sugarcube_year_on_off =
      $prefs->client($client)->get('sugarcube_year_on_off');

    if ( $sugarcube_year_on_off == 0 || $sugarcube_year_on_off eq '' ) {

        # This will pull 10 tracks from the SC db so should always work
        @unique = Plugins::SugarCube::Breakout::FSgetRealRandomSubset($client)
          ;    # getRealRandom - get a random track

    }
    elsif ( $sugarcube_year_on_off == 1 ) {

        # Select tracks between a year range
        @unique =
          Plugins::SugarCube::Breakout::FSgetRealRandomSubsetYearRangeStrict(
            $client);

    }
    else {
     # Select tracks between a year range take into account where no year is set
        @unique =
          Plugins::SugarCube::Breakout::FSgetRealRandomSubsetYearRangeAny(
            $client);
    }

    my ( $element, $song, $track, $changeindex, $temptrack );
    my @quickone;

    ## Current Playing Track Details
    $song = Slim::Player::Playlist::url($client);
    $song = Slim::Utils::Misc::pathFromFileURL($song);
    $song = dirtyencoder($song);
    (
        my $PlayArtist,
        my $PlayTrack,
        my $PlayAlbum,
        my $CurrentGenre,
        my $CurrentAlbumArt,
        my $FullAlbum
    ) = Plugins::SugarCube::Breakout::getSongDetails($song);
    if ( length($CurrentAlbumArt) == 0 ) { $CurrentAlbumArt = "0"; }
    $cpartist{$client}    = $PlayArtist;
    $cptrack{$client}     = $PlayTrack;
    $cpalbum{$client}     = $PlayAlbum;
    $cpgenre{$client}     = $CurrentGenre;
    $cpalbumart{$client}  = $CurrentAlbumArt;
    $cpfullalbum{$client} = $FullAlbum;

    if ( length($PlayArtist) == 0 ) {
        $log->info(
"PANIC - Failed to obtain Artist, Track and Album details from the database\n"
        );
    }

    Plugins::SugarCube::Breakout::AlbumArtistTracker( $client, $PlayAlbum,
        $PlayArtist );    # Save current Album, Save current Artist

    my $dbh           = Slim::Schema->storage->dbh();
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    ## When TrackStat is ENABLED
    my $sugarlvTS = $prefs->get('sugarlvTS');
    if ($sugarlvTS) {
    	my $statsSource = (($sugarlvTS == 1) || !$TSenabled) ? "tracks_persistent" : "track_statistics"; # 1 = LMS, 2 = TS
        my $query =
"SELECT tracks.url, tracks.title, albums.title, genres.name, contributors.name, $statsSource.playCount, $statsSource.rating, $statsSource.lastPlayed, tracks.coverid, tracks.album, tracks.id FROM contributors, tracks INNER JOIN genre_track ON (genre_track.track = tracks.id) INNER JOIN $statsSource ON (tracks.urlmd5 = $statsSource.urlmd5) INNER JOIN genres ON (genre_track.genre = genres.id) INNER JOIN albums ON (tracks.album = albums.id) INNER JOIN contributor_track ON tracks.id = contributor_track.track AND contributor_track.contributor = contributors.id AND contributor_track.role in (1,6) WHERE tracks.url = ";

        my $changeindex = 0;
        foreach (@unique) {
            my $addme = $dbh->quote( @unique[$changeindex] );
            $query = ( $query . $addme . " OR tracks.url = " );
            $changeindex++;
        }
        $query = substr( $query, 0, -17 );
        $query = $query
          . " group by tracks.url"
          ;    # Handles multiple genres, last genre is the dominate one
        my $sth = $dbh->prepare($query);
        $sth->execute();

        while ( my @results = $sth->fetchrow_array() ) {
            push @quickone, $results[0], $results[1], $results[2], $results[3],
              $results[4], $results[5], $results[6], $results[7], $results[8],
              $results[9], $results[10];
        }
        if ( $sth->rows == 0 ) {
            $log->debug("Failed to obtain LMS metadata from database\n\n")
              ;    # Need to do something probably :)
        }

    }
    else {
###
        # NO TrackStat - When TrackStat is DISABLED - Normal Function
###
        my $query =
"SELECT tracks.url, tracks.title, albums.title, genres.name, contributors.name, tracks.coverid, tracks.album, tracks.id FROM contributors, tracks INNER JOIN genre_track ON (genre_track.track = tracks.id) INNER JOIN genres ON (genre_track.genre = genres.id) INNER JOIN albums ON (tracks.album = albums.id) INNER JOIN contributor_track ON tracks.id = contributor_track.track AND contributor_track.contributor = contributors.id AND contributor_track.role in (1,6) WHERE tracks.url = ";

        my $changeindex = 0;
        foreach (@unique) {
            my $addme = $dbh->quote( @unique[$changeindex] );
            $query = ( $query . $addme . " OR tracks.url = " );
            $changeindex++;
        }
        $query = substr( $query, 0, -17 );
        $query = $query
          . " group by tracks.url"
          ;    # Handles multiple genres last genre is the dominate one
        my $sth = $dbh->prepare($query);

        $sth->execute();

        while ( my @results = $sth->fetchrow_array ) {
            push @quickone, $results[0], $results[1], $results[2], $results[3],
              $results[4], ' ', ' ', ' ', $results[5], $results[6], $results[7];

        }
        if ( $sth->rows == 0 ) {
            $log->debug("Failed to obtain LMS metadata from database\n\n")
              ;    # Need to do something probably :)
        }

    }

    Plugins::SugarCube::Breakout::myworkingset( $client, @quickone )
      ;            # Save all our stuff
    Plugins::SugarCube::Breakout::DropGenreAndXMas($client)
      ;            # Drop Genres and Christmas
    Plugins::SugarCube::Breakout::DropArtists($client);  # Drops blocked artists
    Plugins::SugarCube::Breakout::DropAlbums($client);   # Drop Albums

    Plugins::SugarCube::Breakout::DropEmPunk($client);

    # If TrackStat ENABLED
    my $sugarlvTS = $prefs->get('sugarlvTS');

    if ($sugarlvTS) {
        $log->debug("Dropping as per TrackStat Block metrics\n");
        Plugins::SugarCube::Breakout::droptsmetrics($client);

        my $sugarcube_ts_recentplayed =
          $prefs->client($client)->get('sugarcube_ts_recentplayed');
        my $sugarcube_ts_playcount =
          $prefs->client($client)->get('sugarcube_ts_playcount');
        my $sugarcube_ts_rating =
          $prefs->client($client)->get('sugarcube_ts_rating');

        # TrackStat Settings default to 0 if not defined

        if ( $sugarcube_ts_recentplayed eq '' ) {

            #		$log->debug("sugarcube_ts_recentplayed; NOT defined\n");
            $prefs->client($client)->set( 'sugarcube_ts_recentplayed', 0 );
        }
        if ( $sugarcube_ts_playcount eq '' ) {

            #		$log->debug("sugarcube_ts_playcount; NOT defined\n");
            $prefs->client($client)->set( 'sugarcube_ts_playcount', 0 );
        }
        if ( $sugarcube_ts_rating eq '' ) {

            #		$log->debug("sugarcube_ts_rating; NOT defined\n");
            $prefs->client($client)->set( 'sugarcube_ts_rating', 0 );
        }

        if (   ( $sugarcube_ts_playcount == 0 )
            && ( $sugarcube_ts_rating == 0 )
            && ( $sugarcube_ts_recentplayed == 0 ) )
        {
            #			$log->debug("TS 0 - Raw Pulling\n");
            @myworkingset = Plugins::SugarCube::Breakout::mystuff($client)
              ;    # Dont TS Sort just pull results

        }
        else {
# Remove tracks TS rating between x  Remove tracks TS playcount x  Remove tracks TS played recently x
            @myworkingset =
              Plugins::SugarCube::Breakout::tssorting( $client,
                $sugarcube_ts_recentplayed, $sugarcube_ts_playcount,
                $sugarcube_ts_rating );
        }
    }
    else {
        #		$log->debug("No TrackStat Sorting Required Raw Pull\n");
        @myworkingset = Plugins::SugarCube::Breakout::mystuff($client)
          ;    # Dont TS Sort just pull results
    }

###
    #    $log->debug("Normal SugarCube Mode\n\n");

    # SELECT THE FIRST TRACK AND ADD DETAILS INTO OUR HISTORY ARRAY

    $song = $myworkingset[0];

    #$log->debug("First Track $song\n");

    if ( length($song) == 0 ) {
        $song = randompuller($client);
        $log->debug("Random Track Picked assumed Genre available\n");

        if ( $song eq 'FAILED' ) {
            $log->debug(
                "RandomPuller Failed, likely no playing track to use\n");
            $song = Plugins::SugarCube::Breakout::getRealRandom();
            $log->debug("getRealRandom returned with $song\n");
        }

    }
    else {
        if ( length( $myworkingset[8] ) == 0 ) { $myworkingset[8] = "0"; }
        $upnartist{$client}    = $myworkingset[4];
        $upntrack{$client}     = $myworkingset[1];
        $upnalbum{$client}     = $myworkingset[2];
        $upngenre{$client}     = $myworkingset[3];
        $upnalbumart{$client}  = $myworkingset[8];
        $upnfullalbum{$client} = $myworkingset[9];

        #$log->debug("First Track Selected; Save History::$myworkingset[4]\n" );
        Plugins::SugarCube::Breakout::SaveHistory(
            $client,          $myworkingset[4], $myworkingset[1],
            $myworkingset[2], $myworkingset[3], $myworkingset[8],
            $myworkingset[9]
        );
    }
    $track = $song;
    $log->debug("Queuing Up Track;$track\n");

    #		$prefs->client($client)->set('sugarcube_randomtrack', ' ');
    $song = Slim::Schema->rs('Track')->objectForUrl($track);

    # Reset Random Flag

    $log->debug("Adding Track; $song\n");
    if ( length($song) == 0 ) {
        $log->info("*********FAILED STOP *********\n");
    }
    addtrack( $client, $song );    # song is hashed up

    # End of classic mode

    $#unique = -1;
    my $sugarcube_volume_flag =
      $prefs->client($client)->get('sugarcube_volume_flag');
    if ( $sugarcube_volume_flag == 1 ) { slideVolume($client); }
    Plugins::SugarCube::Breakout::playlistcull($client);
    sleepplayer($client);

}
###
# gotMIP - Receive back list URL data dump and process
###
sub gotMIP {
    no warnings 'numeric';

    my $http   = shift;
    my $params = $http->params();
    my $client = $params->{'client'};
    my ( $element, $song, $track, $changeindex, $temptrack );
    my @quickone;
    my $content = $http->content();
    my @miparray = split( /\n/, $content );

    $log->debug("\n#### MusicIP Responded with ####\n$content\n");

    $mixstatus = '';    # Reset MIP Status

    my $creator = $params->{'caller'};  # CHECK WHETHER ASYNC WAS FROM QUICK MIX

    if ( $creator eq 'SpiceflyONE' ) {
        $global_quickmix = 1;
    }
    else {
        $global_quickmix = 0;
    }

    my $changeindex = 0;
    my $sugardpc    = $prefs->get('sugardpc');    # Dynamic Path Conversion

    foreach (@miparray) {
        my $enc =
          Slim::Utils::Unicode::encodingFromString( @miparray[$changeindex] );
        $element =
          Slim::Utils::Unicode::utf8decode_guess( @miparray[$changeindex],
            $enc );

        if ( $sugardpc == 1 ) {                   # Dynamic Path Conversion

            my $nasconvertpath = $prefs->get('nasconvertpath');
            my $localmediapath = $prefs->get('localmediapath');

            #			$log->debug("nasconvertpath Change Using;$nasconvertpath\n");

            $nasconvertpath = quotemeta $nasconvertpath;

            #			$log->debug("Dynamic Change Using;$nasconvertpath\n");
            #			$log->debug("Dynamic Replace With;$localmediapath\n");
            #			$log->debug("Original element;$element\n");
            $element =~ s/$nasconvertpath/$localmediapath/i;

            #			$log->debug("Converted element;$element\n");

            my $nasconvertpath_2 = $prefs->get('nasconvertpath_2');
            my $localmediapath_2 = $prefs->get('localmediapath_2');

           #			$log->debug("nasconvertpath_2 Change Using;$nasconvertpath_2\n");

            $nasconvertpath_2 = quotemeta $nasconvertpath_2;

            #			$log->debug("Dynamic Change Using;$nasconvertpath_2\n");
            #			$log->debug("Dynamic Replace With;$localmediapath_2\n");
            #			$log->debug("Original element;$element\n");
            $element =~ s/$nasconvertpath_2/$localmediapath_2/i;

            #			$log->debug("Converted element;$element\n");

        }

        $element = dirtyencoder($element);
        push( @unique, $element );
        $changeindex++;
    }

    my $x       = Slim::Player::Playlist::url($client);
    my $creator = $params->{'caller'}
      ; # CHECK WHETHER ASYNC WAS FROM ALARM or AUTOMIX - IF SO THEN DONT SAVE CURRENT TRACK

    # START ALARM CHECK - IF NOT ALARM SITUATION - SAVE CURRENT PLAYING TRACK
    if (   $x ne 'sugarcube:track'
        && $creator ne 'SpiceflyAutoMix'
        && $creator ne 'SpiceflyONE' )
    {
        $song = Slim::Player::Playlist::url($client);

        if ( $song =~ m/^tmp:/i ) {

            #	$log->debug("\nTrying to correct tmp file\n");
            my $z = substr $song, 0, 3, "file";    # replaces tmp with file
        }

        $song = Slim::Utils::Misc::pathFromFileURL($song);
        $song = dirtyencoder($song);
        ## Current Playing Track Details
        (
            my $PlayArtist,
            my $PlayTrack,
            my $PlayAlbum,
            my $CurrentGenre,
            my $CurrentAlbumArt,
            my $FullAlbum
        ) = Plugins::SugarCube::Breakout::getSongDetails($song);
        if ( length($CurrentAlbumArt) == 0 ) { $CurrentAlbumArt = "0"; }
        $cpartist{$client}    = $PlayArtist;
        $cptrack{$client}     = $PlayTrack;
        $cpalbum{$client}     = $PlayAlbum;
        $cpgenre{$client}     = $CurrentGenre;
        $cpalbumart{$client}  = $CurrentAlbumArt;
        $cpfullalbum{$client} = $FullAlbum;

        if ( length($PlayArtist) == 0 ) {    ## IF NO DETAILS ARE RETURNED
            $log->info(
"PANIC - Failed to obtain Artist, Track and Album details from the database\n"
            );
            $log->info(
"This is most likely an encoding problem, please check the file for hidden or extended characters and then rescan it with MIP and LMS\n"
            );

        }
        Plugins::SugarCube::Breakout::AlbumArtistTracker( $client, $PlayAlbum,
            $PlayArtist );    # Save current Album Save current Artist
    }

    # END OF ALARM CHECK

    my $dbh           = Slim::Schema->storage->dbh();
    my $sqlitetimeout = $prefs->get('sqlitetimeout');
    $dbh->sqlite_busy_timeout( $sqlitetimeout * 1000 );

    my $sugarlvTS = $prefs->get('sugarlvTS');    # Show TrackStat
##
## TRACKSTAT ENABLED
##
    if ($sugarlvTS) {
    	my $statsSource = (($sugarlvTS == 1) || !$TSenabled) ? "tracks_persistent" : "track_statistics"; # 1 = LMS, 2 = TS
        my $query =
"SELECT tracks.url, tracks.title, albums.title, genres.name, contributors.name, $statsSource.playCount, $statsSource.rating, $statsSource.lastPlayed, tracks.coverid, tracks.album, tracks.id FROM contributors, tracks INNER JOIN genre_track ON (genre_track.track = tracks.id) INNER JOIN $statsSource ON (tracks.urlmd5 = $statsSource.urlmd5) INNER JOIN genres ON (genre_track.genre = genres.id) INNER JOIN albums ON (tracks.album = albums.id) INNER JOIN contributor_track ON tracks.id = contributor_track.track AND contributor_track.contributor = contributors.id AND contributor_track.role in (1,6) WHERE tracks.url = ";

        my $changeindex = 0;
        foreach (@unique) {
            my $addme = $dbh->quote( @unique[$changeindex] );
            $query = ( $query . $addme . " OR tracks.url = " );
            $changeindex++;
        }

        $query = substr( $query, 0, -17 );
        $query = $query
          . " group by tracks.url"
          ;    # Handles multiple genres last genre is the dominate one
        my $sth = $dbh->prepare($query);
        $sth->execute();

        while ( my @results = $sth->fetchrow_array() ) {
            push @quickone, $results[0], $results[1], $results[2], $results[3],
              $results[4], $results[5], $results[6], $results[7], $results[8],
              $results[9], $results[10];
        }
        if ( $sth->rows == 0 ) {
            $log->debug("Failed to obtain LMS metadata from database\n\n")
              ;    # Need to do something probably :)
        }

        Plugins::SugarCube::Breakout::myworkingset( $client, @quickone )
          ;        # Save all our stuff

        if ( $creator ne 'SpiceflyONE' )
        {          # If quick fire mix skip all this stuff
            Plugins::SugarCube::Breakout::DropGenreAndXMas($client);
            Plugins::SugarCube::Breakout::DropArtists($client);
            Plugins::SugarCube::Breakout::DropAlbums($client);
            Plugins::SugarCube::Breakout::DropEmPunk($client)
              ;    # Drop XMas Genre and Artists we dont want

#  Try and detect when return track is the same as the playing track but from a different directory
#  Ie. greatest hits, do a comparison of the track title to guess
#	    my $duplicate = $prefs->client($client)->get('sugarcube_dupper');			# Experimental Duplication
#		if ($duplicate == 1) {
#			dupper($client);
#		}
#		$log->debug("Dropping as per TrackStat Block metrics\n");
            Plugins::SugarCube::Breakout::droptsmetrics($client);

            my $sugarcube_ts_recentplayed =
              $prefs->client($client)->get('sugarcube_ts_recentplayed');
            my $sugarcube_ts_playcount =
              $prefs->client($client)->get('sugarcube_ts_playcount');
            my $sugarcube_ts_rating =
              $prefs->client($client)->get('sugarcube_ts_rating');

            # TrackStat Settings default to 0 if not defined

            if ( $sugarcube_ts_recentplayed eq '' ) {
                $log->debug("sugarcube_ts_recentplayed; NOT defined\n");
                $prefs->client($client)->set( 'sugarcube_ts_recentplayed', 0 );
            }
            if ( $sugarcube_ts_playcount eq '' ) {
                $log->debug("sugarcube_ts_playcount; NOT defined\n");
                $prefs->client($client)->set( 'sugarcube_ts_playcount', 0 );
            }
            if ( $sugarcube_ts_rating eq '' ) {
                $log->debug("sugarcube_ts_rating; NOT defined\n");
                $prefs->client($client)->set( 'sugarcube_ts_rating', 0 );
            }

            if (   ( $sugarcube_ts_playcount == 0 )
                && ( $sugarcube_ts_rating == 0 )
                && ( $sugarcube_ts_recentplayed == 0 ) )
            {
                $log->debug("TS 0 - Raw Pulling\n");
                @myworkingset = Plugins::SugarCube::Breakout::mystuff($client)
                  ;    # Dont TS Sort just pull results

            }
            else {
# Remove tracks TS rating between x  Remove tracks TS playcount x  Remove tracks TS played recently x
                @myworkingset =
                  Plugins::SugarCube::Breakout::tssorting( $client,
                    $sugarcube_ts_recentplayed, $sugarcube_ts_playcount,
                    $sugarcube_ts_rating );
            }
        }
        else {
            @myworkingset = Plugins::SugarCube::Breakout::mystuff($client)
              ;    # Pull everything for quick fire mix
        }

    }
    else {
###
        # NO TrackStat - When TrackStat is DISABLED - Normal Function
###
        #						0		1	2		3		4		8		9		10
        my $query =
"SELECT tracks.url, tracks.title, albums.title, genres.name, contributors.name, tracks.coverid, tracks.album, tracks.id FROM contributors, tracks INNER JOIN genre_track ON (genre_track.track = tracks.id) INNER JOIN genres ON (genre_track.genre = genres.id) INNER JOIN albums ON (tracks.album = albums.id) INNER JOIN contributor_track ON tracks.id = contributor_track.track AND contributor_track.contributor = contributors.id AND contributor_track.role in (1,6) WHERE tracks.url = ";

        my $changeindex = 0;
        foreach (@unique) {
            my $addme = $dbh->quote( @unique[$changeindex] );
            $query = ( $query . $addme . " OR tracks.url = " );
            $changeindex++;
        }

        $query = substr( $query, 0, -17 );
        $query = $query
          . " group by tracks.url"
          ;    # Handles multiple genres last genre is the dominate one
        my $sth = $dbh->prepare($query);

        $sth->execute();

        while ( my @results = $sth->fetchrow_array ) {
            push @quickone, $results[0], $results[1], $results[2], $results[3],
              $results[4], ' ', ' ', ' ', $results[5], $results[6], $results[7];

#	    $log->debug("Quickone; $results[0],$results[1],$results[2],$results[3],$results[4],' ',' ',' ',$results[5],$results[6],$results[7]\n");

        }

        if ( $sth->rows == 0 ) {
            $log->debug("Failed to obtain LMS metadata from database\n\n")
              ;    # Need to do something probably :)
        }

        Plugins::SugarCube::Breakout::myworkingset( $client, @quickone )
          ;        # Save all our stuff

        if ( $creator ne 'SpiceflyONE' ) {
            Plugins::SugarCube::Breakout::DropGenreAndXMas($client);
            Plugins::SugarCube::Breakout::DropArtists($client);
            Plugins::SugarCube::Breakout::DropAlbums($client);
            Plugins::SugarCube::Breakout::DropEmPunk($client)
              ;    # Trying to remove this out

#	    my $duplicate = $prefs->client($client)->get('sugarcube_dupper');			# Experimental Duplication
#		if ($duplicate == 1) {
#			dupper($client);
#		}

        }
        $log->debug("No TrackStat Sorting Required (TS Disabled)\n");
        @myworkingset = Plugins::SugarCube::Breakout::mystuff($client)
          ;    # Dont TS Sort just pull results

    }

###
### MUSICIP VINTAGE MODE
### Limitations; Live View and tracks within the queue stack can be from the same album
###
    my $sugarcube_vintage = $prefs->client($client)->get('sugarcube_vintage');
    if ( ( $sugarcube_vintage == 1 ) || ( $creator eq 'SpiceflyONE' ) ) {
        my $arraysize = scalar $#myworkingset + 1;

        # Divide by 10 = number of tracks
        if ( $arraysize != 0 ) {
            my $stack_size = $arraysize / 10;
            for ( my $i = 0 ; $i < $stack_size ; $i++ ) {
                if ( $creator eq 'SpiceflyONE' ) {
                }
                else {
                    $log->debug(
                        "Vintage Mode; Save History; $myworkingset[$i*10]\n");

                    Plugins::SugarCube::Breakout::SaveHistory(
                        $client,
                        $myworkingset[ ( $i * 10 ) + 4 ],
                        $myworkingset[ ( $i * 10 ) + 1 ],
                        $myworkingset[ ( $i * 10 ) + 2 ],
                        $myworkingset[ ( $i * 10 ) + 3 ],
                        $myworkingset[ ( $i * 10 ) + 8 ],
                        $myworkingset[ ( $i * 10 ) + 9 ]
                    );
                }
                addtrack( $client, $myworkingset[ $i * 10 ] )
                  ;    # song is hashed up
            }
        }
        else {
            $log->debug("Vintage Mode with no Tracks\n");
            gotErrorContinue( $client, $http );
        }

    }
    else {
###
###	Just take a single track
###

        my $sugarcube_wobble = $prefs->client($client)->get('sugarcube_wobble');
        if (   $sugarcube_wobble == 1
            || $sugarcube_wobble == 2
            || $sugarcube_wobble == 3 )
        {

            #	$log->debug("Wobble Mode Active\n");

## 0 (Disabled)
## 1 Tight Wobble (First 3)
## 2 Medium Wobble (First 5)
## 3 Loose Wobble (Any)

            my $arraysize = scalar @myworkingset;

            my $random_number = 0;

            #divide by 10 = number of tracks
            if ( $arraysize != 0 ) {

                $random_number = ( $arraysize / 10 );

                #		$log->debug("Random Sized array; $random_number\n");

                if ( $sugarcube_wobble == 1 && $arraysize > 31 ) {
                    $random_number = int( rand(3) );   ## Number between 0 and 3

                    $random_number = $random_number * 10;
                }
                elsif ( $sugarcube_wobble == 2 && $arraysize > 51 ) {
                    $random_number =
                      int( rand($random_number) );     ## Number between 0 and 5

                    $random_number = $random_number * 10;
                }
                else {
                    $random_number = int( rand($random_number) )
                      ;    ## Number between 0 and random_number (Max)

                    $random_number = $random_number * 10;
                }

                $song = $myworkingset[$random_number];

                #		$log->debug("Pushing to Save History;$song\n");
                Plugins::SugarCube::Breakout::SaveHistory(
                    $client,
                    $myworkingset[ $random_number + 4 ],
                    $myworkingset[ $random_number + 1 ],
                    $myworkingset[ $random_number + 2 ],
                    $myworkingset[ $random_number + 3 ],
                    $myworkingset[ $random_number + 8 ],
                    $myworkingset[ $random_number + 9 ]
                );

            }
            else {
                $log->debug(
"Not enough tracks for Wobbling - Nothing to push to Save History\n"
                );
                $log->debug(
                    "Getting a Random Track based on Playing Tracks Genre\n");
                $song = randompuller($client);

                if ( $song eq 'FAILED' ) {
                    $log->debug(
"RandomPuller (Genre) Failed, likely no playing track or track has no Genre to use\n"
                    );
                    $song = Plugins::SugarCube::Breakout::getRealRandom();
                    $log->debug("getRealRandom returned with $song\n");
                }
            }
            $log->debug("Asking LMS to Queue Track;$song\n");
            $song = Slim::Schema->rs('Track')->objectForUrl($song);

        }
        else {

            # SELECT THE FIRST TRACK AND ADD DETAILS INTO OUR HISTORY ARRAY
            $song = $myworkingset[0];

            if ( length($song) == 0 ) {

                $log->debug(
"No enough Tracks available could be selection has discounted all tracks, genre, artist blocking etc; $song\n"
                );

                my $creator = $params->{'caller'}
                  ;    # CHECK WHETHER ASYNC WAS FROM ALARM or AUTOMIX

                # ALARM CHECK
                if (   ( $creator eq 'SpiceflyAutoMix' )
                    || ( $creator eq 'SpiceflyAlarm' ) )
                {
                    my $scalarm_genre =
                      $prefs->client($client)->get('scalarm_genre')
                      ;    # Get Genre from prefs
                    my (
                        $SCTRACKURL,   $CurrentArtist, $CurrentTrack,
                        $CurrentAlbum, $CurrentGenre,  $CurrentAlbumArt,
                        $FullAlbum
                      )
                      = Plugins::SugarCube::Breakout::getRandom( $client,
                        $scalarm_genre );    # Get Random based on prefs
                    $song = $SCTRACKURL;
                    $log->debug(
"Get Track from LMS based on;$scalarm_genre and got track;$song\n"
                    );
                }
                else {
                    if ( length($song) == 0 ) {
                        $song = randompuller($client)
                          ; # Random track selector assuming that we have a track currently playing (otherwise it will fail)
                        $log->debug(
"First Track from MIP was empty.  Got Random Track instead;$song\n"
                        );
                    }
                }
                if ( ( length($song) == 0 ) || ( $song eq 'FAILED' ) ) {
                    $log->debug(
"Track still not good have;$song .Getting RealRandom track to use\n"
                    );
                    $song = Plugins::SugarCube::Breakout::getRealRandom();
                    $log->debug("getRealRandom returned with $song\n");
                }
            }
            else {
                if ( length( $myworkingset[8] ) == 0 ) {
                    $myworkingset[8] = "0";
                }
                $upnartist{$client}    = $myworkingset[4];
                $upntrack{$client}     = $myworkingset[1];
                $upnalbum{$client}     = $myworkingset[2];
                $upngenre{$client}     = $myworkingset[3];
                $upnalbumart{$client}  = $myworkingset[8];
                $upnfullalbum{$client} = $myworkingset[9];
                $log->debug(
"\nInserting into Database; $myworkingset[4] : $myworkingset[1]\n"
                );
                Plugins::SugarCube::Breakout::SaveHistory(
                    $client,          $myworkingset[4], $myworkingset[1],
                    $myworkingset[2], $myworkingset[3], $myworkingset[8],
                    $myworkingset[9]
                );
            }

            $log->debug("Asking LMS to Queue Track;\n$song\n");
            $song = Slim::Schema->rs('Track')->objectForUrl($song);
        }

        if ( length($song) == 0 ) {
            $log->info(
                "********* FAILED STOP - Nothing to work with *********\n");
        }
        else {
            addtrack( $client, $song );    # song is hashed up
        }
    }

    # End of classic mode

    $#unique = -1;
    my $sugarcube_volume_flag =
      $prefs->client($client)->get('sugarcube_volume_flag');
    if ( $sugarcube_volume_flag == 1 ) { slideVolume($client); }
    Plugins::SugarCube::Breakout::playlistcull($client);
    sleepplayer($client);

    my $creator = $params->{'caller'};

    # ASYNC WAS FROM ALARM DO THE TIDY UP FUNCTIONS
    if ( $creator eq 'SpiceflyAlarm' ) {

        my $request = $client->execute( [ 'playlist', 'delete', 0 ] );
        $request->source('PLUGIN_SUGARCUBE');
        my $request = $client->execute( ['play'] );
        $request->source('PLUGIN_SUGARCUBE');
        return 1;    # Need to return 1 to stop being attacked by alarm calls
    }
    if ( $creator eq 'SpiceflyAutoMix' || $creator eq 'SpiceflyONE' ) {
        my $request = $client->execute( ['play'] );
        $request->source('PLUGIN_SUGARCUBE');
    }
}

sub isPluginsInstalled {
    my $client        = shift;
    my $pluginList    = shift;
    my $enabledPlugin = 1;
    foreach my $plugin ( split /,/, $pluginList ) {
        if ($enabledPlugin) {
            $enabledPlugin = grep( /$plugin/,
                Slim::Utils::PluginManager->enabledPlugins($client) );
        }
    }
    return $enabledPlugin;
}

# Random track selector assuming that we have a track currently playing (otherwise it will fail)
# Random track based on Currently Playing Genre
sub randompuller {
    my $client = shift;

    my $sugarcube_randomstatus = "Req. Random Track Based on Genre";
    $prefs->client($client)
      ->set( 'sugarcube_randomstatus', "$sugarcube_randomstatus" );

    my $song = Slim::Player::Playlist::url($client)
      ; # CHECK WHETHER ASYNC WAS FROM ALARM or AUTOMIX - IF SO THEN DONT SAVE CURRENT TRACK
    $log->debug("\nLMS Reported Track Playing;\n$song\n");

    if ( $song eq 'sugarcube:track' )
    { # Breakout if there is no currently playing track we can pull the genre from
        $song = "FAILED";
        $log->debug("\nNo Currently Playing Track to get Genre from\n");
        return $song;
    }

    ( my $NEWSCgenre ) =
      Plugins::SugarCube::Breakout::getGenre( $client, $song );
    $log->debug("\nCurrently Playing; $song\n");
    $log->debug("\nCurrently Playing Genre; $NEWSCgenre\n");

    (
        my $SCTRACKURL,
        my $RNDArtist,
        my $RNDTrack,
        my $RNDAlbum,
        my $RNDGenre,
        my $RNDAlbumArt,
        my $RNDFullAlbum
    ) = Plugins::SugarCube::Breakout::getRandom( $client, $NEWSCgenre );

    if ( length($RNDAlbumArt) == 0 ) { $RNDAlbumArt = "0"; }

    my $sugarcube_mode = $prefs->client($client)->get('sugarcube_mode');

    if ( $sugarcube_mode == 0 || $sugarcube_mode eq '' )
    {    # Standard MusicIP Mode so record random.  If FreeStyle dont record it

        ## Random Recording Start
        $log->debug(
"\nInsert into Database Random fallback track: $RNDTrack by $RNDArtist\n"
        );
        $upnartist{$client}    = $RNDArtist;
        $upntrack{$client}     = $RNDTrack;
        $upnalbum{$client}     = $RNDAlbum;
        $upngenre{$client}     = $RNDGenre;
        $upnalbumart{$client}  = $RNDAlbumArt;
        $upnfullalbum{$client} = $RNDFullAlbum;
        $RNDGenre              = $RNDGenre . '    (SugarCube Random Selection)';
        Plugins::SugarCube::Breakout::SaveHistory( $client, $RNDArtist,
            $RNDTrack, $RNDAlbum, $RNDGenre, $RNDAlbumArt, $RNDFullAlbum );
        $prefs->client($client)
          ->set( 'sugarcube_randomtrack', "$RNDTrack by $RNDArtist" );

        # Went Random
        # Last Random Time
        my @months   = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
        my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
        my (
            $second,     $min,       $hour,
            $dayOfMonth, $month,     $yearOffset,
            $dayOfWeek,  $dayOfYear, $daylightSavings
        ) = localtime();
        my $year = 1900 + $yearOffset;
        if ( $hour < 10 )   { $hour   = '0' . $hour }
        if ( $min < 10 )    { $min    = '0' . $min }
        if ( $second < 10 ) { $second = '0' . $second }
        my $theTime =
"$hour:$min:$second on $weekDays[$dayOfWeek] $months[$month] $dayOfMonth, $year";
        $prefs->client($client)
          ->set( 'sugarcube_stats_random_time', "$theTime" );
        my $sugarcube_randomcount =
          $prefs->client($client)->get('sugarcube_randomcount');
        $sugarcube_randomcount++;
        $prefs->client($client)
          ->set( 'sugarcube_randomcount', "$sugarcube_randomcount" );
        ## Record randomcount and random track
    }
##        $song = Slim::Schema->rs('Track')->objectForUrl($SCTRACKURL);
    return $SCTRACKURL;

}

sub SugarDelay {
    my $client = shift;

    my $sugarcube_sn = $prefs->client($client)->get('sugarcube_sn');
    if ( $sugarcube_sn == 1 ) {
        my $sugarcube_sn_active =
          $prefs->client($client)->get('sugarcube_ns_active');

        if ( $sugarcube_sn_active == 1 ) {
            my $sugarcube_fade = $prefs->client($client)->get('sugarcube_fade');
            $prefs->client($client)->set( 'sugarcube_ns_active', 0 );
            my $aprefs = preferences('server');
            $aprefs->client($client)
              ->set( 'transitionType', "$sugarcube_fade" );
            $client->execute( [ "playlist", "repeat", 0 ] );
        }
    }

    my $shufflesetting = $prefs->client($client)->get('sugarcube_shuffle');
    if ( $shufflesetting == 1 ) {
        if (   Slim::Player::Playlist::shuffle($client) == 1
            || Slim::Player::Playlist::shuffle($client) == 2 )
        {
            $client->execute( [ "playlist", "shuffle", 0 ] );
        }
    }

    if ( Slim::Player::Sync::isSlave($client) ) {
        return;
    }
    else { kickoff($client); }
}

sub SugarPlayerCheck {
    my $client = shift;
    Slim::Utils::Timers::killTimers( $client, \&SugarPlayerCheck )
      ;    #Paranoia check

    my $timer =
      Slim::Utils::Timers::setTimer( $client, Time::HiRes::time() + 20,
        \&SugarPlayerCheck );
    my $quicksong = Slim::Player::Playlist::url($client);

    #  Blocking Streaming
    if ( Slim::Music::Info::isRemoteURL($quicksong) == 1 ) {
        return;
    }

    if (   $quicksong =~ m/^napster:/i
        || $quicksong =~ m/.pls/i
        || $quicksong =~ m/http:/i
        || $quicksong =~ m/.asx/i
        || $quicksong =~ m/rtmp:/i
        || $quicksong =~ m/^lfm:/i
        || $quicksong =~ m/^pandora:/i
        || $quicksong =~ m/^slacker:/i
        || $quicksong =~ m/^live365:/i
        || $quicksong =~ m/^mediafly:/i
        || $quicksong =~ m/^mog:/i
        || $quicksong =~ m/https:/i
        || $quicksong =~ m/^deezer:/i
        || $quicksong =~ m/^spotify:/i
        || $quicksong =~ m/^rhapd:/i
        || $quicksong =~ m/^classical:/i
        || $quicksong =~ m/^loop:/i )

    {    #  Check whether we are streaming if so abort!
        return;
    }
    elsif ( $quicksong =~ m/^sugarcube:track/i )
    {    # ASYNC WAS FROM ALARM DO TIDY UP

        my $listlength = Slim::Player::Playlist::count($client);

        if ( $listlength == 2
          )    ## That bloody alarm track but we have something else we can play
        {
            my $request = $client->execute( [ 'playlist', 'delete', 0 ] );
            $request->source('PLUGIN_SUGARCUBE');

            my $request = $client->execute( ['play'] );
            $request->source('PLUGIN_SUGARCUBE');
            return;
        }
    }

    my $request = $client->power() ? 'on' : 'off';
    my $playstatus = Slim::Player::Source::playmode($client);

    if ( $playstatus eq 'play' && $request eq 'on' ) {

        ## GOOGLE TRAFFIC START
        my $traf_enable = $prefs->get('traf_enable');    # If Traffic Enabled
        if ( $traf_enable == 1 ) {
            Plugins::SugarCube::Traffic::start($client);
        }
        ## TRAFFIC END

## COMING UP NEXT BUILD FOR THE LIVE VIEW
        my $currentsong = Slim::Player::Playlist::url($client);

        if ( $currentsong =~ m/^tmp:/i ) {
            $log->debug("\nTrying to correct tmp file\n");
            my $z = substr $currentsong, 0, 3, "file";  # replaces tmp with file
        }

        $currentsong = Slim::Utils::Misc::pathFromFileURL($currentsong);
        $currentsong = dirtyencoder($currentsong);

        #  If using TrackStat pull stats for liveview
        my $sugarlvTS = $prefs->get('sugarlvTS');       # Show TrackStat
        if ($sugarlvTS) {
            ## Current Playing Track Details
            (
                my $PlayArtist,
                my $PlayTrack,
                my $PlayAlbum,
                my $CurrentGenre,
                my $CurrentAlbumArt,
                my $FullAlbum,
                my $PC,
                my $Rat,
                my $LP
            ) = Plugins::SugarCube::Breakout::getTSSongDetails($currentsong);
            if ( length($CurrentAlbumArt) == 0 ) { $CurrentAlbumArt = "0"; }
            $cpartist{$client}    = $PlayArtist;
            $cptrack{$client}     = $PlayTrack;
            $cpalbum{$client}     = $PlayAlbum;
            $cpgenre{$client}     = $CurrentGenre;
            $cpalbumart{$client}  = $CurrentAlbumArt;
            $cpfullalbum{$client} = $FullAlbum;
            $cppc{$client}        = $PC;
            $cprat{$client}       = $Rat;
            $cplp{$client}        = $LP;

            (
                my $UPNArtist,
                my $UPNTrack,
                my $UPNAlbum,
                my $UPNGenre,
                my $UPNAlbumArt,
                my $UPNFULLAlbum,
                my $UPNPC,
                my $UPNRAT,
                my $UPNLP
            ) = Plugins::SugarCube::Breakout::getmyTSNextSong($client);
            if ( length($UPNAlbumArt) == 0 ) { $UPNAlbumArt = "0"; }
            $upnartist{$client}    = $UPNArtist;
            $upntrack{$client}     = $UPNTrack;
            $upnalbum{$client}     = $UPNAlbum;
            $upngenre{$client}     = $UPNGenre;
            $upnalbumart{$client}  = $UPNAlbumArt;
            $upnfullalbum{$client} = $UPNFULLAlbum;
            $upnpc{$client}        = $UPNPC;
            $upnrat{$client}       = $UPNRAT;
            $upnlp{$client}        = $UPNLP;

        }
        else {
            ## Current Playing Track Details
            (
                my $PlayArtist,
                my $PlayTrack,
                my $PlayAlbum,
                my $CurrentGenre,
                my $CurrentAlbumArt,
                my $FullAlbum
            ) = Plugins::SugarCube::Breakout::getSongDetails($currentsong);

            if ( length($CurrentAlbumArt) == 0 ) { $CurrentAlbumArt = "0"; }
            $cpartist{$client}    = $PlayArtist;
            $cptrack{$client}     = $PlayTrack;
            $cpalbum{$client}     = $PlayAlbum;
            $cpgenre{$client}     = $CurrentGenre;
            $cpalbumart{$client}  = $CurrentAlbumArt;
            $cpfullalbum{$client} = $FullAlbum;
            (
                my $UPNArtist,
                my $UPNTrack,
                my $UPNAlbum,
                my $UPNGenre,
                my $UPNAlbumArt,
                my $UPNFULLAlbum
            ) = Plugins::SugarCube::Breakout::getmyNextSong($client);
            if ( length($UPNAlbumArt) == 0 ) { $UPNAlbumArt = "0"; }
            $upnartist{$client}    = $UPNArtist;
            $upntrack{$client}     = $UPNTrack;
            $upnalbum{$client}     = $UPNAlbum;
            $upngenre{$client}     = $UPNGenre;
            $upnalbumart{$client}  = $UPNAlbumArt;
            $upnfullalbum{$client} = $UPNFULLAlbum;
        }
## END - COMING UP NEXT BUILD FOR THE LIVE VIEW

        my $line1;
        my $line2;
        my $line3;    # These hold our display lines

        my $sugarcube_display =
          $prefs->client($client)->get('sugarcube_display');
        if ( $sugarcube_display == 0 ) {
            return;    # None Selected
        }

        if ( $sugarcube_display == 1 ) {    # Coming Up Next

            $line1 = ("Coming Up Next; $upnartist{$client}");
            $line2 = $upntrack{$client};
            $line3 = $upnalbum{$client};
        }

        if ( $sugarcube_display == 2 ) {    # Technical Information
            my $song = Slim::Player::Playlist::url($client);
            $song = Slim::Utils::Misc::pathFromFileURL($song);
            $song = dirtyencoder($song);

            ( my $SCTitle, my $SCCover, my $SCReplaygain, my $SCAlbumgain ) =
              Plugins::SugarCube::Breakout::getSongTechnical( $client, $song );
            $line1 = ("$SCTitle");
            if    ( $SCCover eq '0' ) { $SCCover = "None" }
            elsif ( $SCCover eq '1' ) { $SCCover = "Embedded" }
            else                      { $SCCover = "Folder Based" }
            $line2 = ("Art Cover; $SCCover");
            if ( $SCReplaygain == "" ) { $SCReplaygain = "None" }
            if ( $SCAlbumgain == "" )  { $SCAlbumgain  = "None" }
            $line3 = ("AlbumGain; $SCAlbumgain; TrackGain; $SCReplaygain");
        }    #might be wrong eq instead
        if ( $sugarcube_display == 3 ) {
            my $checklive = $prefs->client($client)->get('sugarcube_status')
              ;    # If SugarCube Disabled
            if ( $checklive == 0 ) {
                return;
            }
            my $sugarcube_randomstatus =
              $prefs->client($client)->get('sugarcube_randomstatus')
              ;    # If we went Random
            if ( $sugarcube_randomstatus eq "Random Track Selected" ) {
                $line1 = "";
                $line2 = $sugarcube_randomstatus;
                $line3 = "";

                $sugarcube_randomstatus = "";    # Clear it
                $prefs->client($client)
                  ->set( 'sugarcube_randomstatus', "$sugarcube_randomstatus" );

            }
            else {
                return;
            }

        }

        # DISPLAY WHAT WE GOT
        $client->showBriefly(
            {
                line => [ $line1, $line2, $line3 ],
                jive => {
                    type     => 'popupplay',
                    text     => [ $line1, $line2, $line3 ],
                    duration => 5000
                },
            },
            {
                scroll    => 1,
                firstline => 1,
                block     => 1,
                duration  => 5,
            }
        );

    }
}

sub buildMIPReq {

    #$log->debug("\n#### Building MusicIP Request ####\n" );
    my $client     = shift;
    my $tracktitle = shift;

    my $sugarport    = $prefs->get('sugarport');
    my $miphosturl   = $prefs->get('miphosturl');
    my $sugarmipsize = $prefs->get('sugarmipsize');

    my $scube_style   = $prefs->client($client)->get('sugarcube_style');
    my $scube_variety = $prefs->client($client)->get('sugarcube_variety');
    if ( !defined $scube_style ) {
        $prefs->client($client)->set( 'sugarcube_style', 20 );

#       $log->debug("No MIP Style Setting - Set for this client, default set to 20.\n" );
    }
    if ( !defined $scube_variety ) {
        $prefs->client($client)->set( 'sugarcube_variety', 0 );

#      $log->debug("No MIP Variety Setting - Set for this client, default set to 0.\n" );
    }
    my $sugarcube_style   = '&style=' . $scube_style;
    my $sugarcube_variety = '&variety=' . $scube_variety;

    my $mypageurl;

    my $sugardpc = $prefs->get('sugardpc');    # Dynamic Path Conversion

    if ( $sugardpc == 1 ) {

        my $nasconvertpath = $prefs->get('nasconvertpath');
        my $localmediapath = $prefs->get('localmediapath');
        $log->debug("localmediapath Change Using;$localmediapath\n");
        $log->debug("nasconvertpath Replace With;$nasconvertpath\n");

        $localmediapath = quotemeta $localmediapath;

        $log->debug("Dynamic Change Using;$localmediapath\n");
        $log->debug("Dynamic Replace With;$nasconvertpath\n");
        $log->debug("Original tracktitle;$tracktitle\n");
        $tracktitle =~ s/$localmediapath/$nasconvertpath/i;
        $log->debug("Converted tracktitle;$tracktitle\n");

        my $nasconvertpath_2 = $prefs->get('nasconvertpath_2');
        my $localmediapath_2 = $prefs->get('localmediapath_2');
        $log->debug("localmediapath_2 Change Using;$localmediapath_2\n");
        $log->debug("nasconvertpath_2 Replace With;$nasconvertpath_2\n");

        $localmediapath_2 = quotemeta $localmediapath_2;

        $log->debug("Dynamic Change Using;$localmediapath_2\n");
        $log->debug("Dynamic Replace With;$nasconvertpath_2\n");
        $log->debug("Original tracktitle;$tracktitle\n");
        $tracktitle =~ s/$localmediapath_2/$nasconvertpath_2/i;
        $log->debug("Converted tracktitle;$tracktitle\n");

        my $findos = index( $tracktitle, "/", 0 );
        if ( $findos != 0 ) {

     # Works with Linux LMS and Wintel MIP
     #			$log->debug("LINUX LMS with Wintel MIP - PreTracktitle;$tracktitle\n");
            $tracktitle = Slim::Utils::Unicode::utf8decode_locale($tracktitle);
            $tracktitle = escape($tracktitle);
            $tracktitle =~ s/%2F/%5C/g;
            $tracktitle =~ s/:/%3A/g;
        }
        else {
            # Wintel LMS and Linux MIP
            $tracktitle =~ s/\\/\//g;

     #			$log->debug("WINTEL LMS with LINUX MIP - PreTracktitle;$tracktitle\n");
        }

    }
    else {
#       $log->debug("\nTrack title before decoding;\n$tracktitle\n");
# Without this LMS explodes for Deadmau5%5C01%20-%20Deadmau5%20%96%20Sofi%20Needs%20A%20Ladder.mp3
# However it enocdes it as 2596 so need to switch it back to 96
        $tracktitle =~ s/�/%96/g;
        $tracktitle = Slim::Utils::Unicode::utf8decode_locale($tracktitle);
        $tracktitle = escape($tracktitle);
        $tracktitle =~ s/%2596/%96/g;

        #      $log->debug("Track title after decoding;$tracktitle\n\n");
    }
    my $sugarcube_style =
      '&style=' . $prefs->client($client)->get('sugarcube_style');
    my $sugarcube_variety =
      '&variety=' . $prefs->client($client)->get('sugarcube_variety');
    my $sugarcube_album_song =
      $prefs->client($client)->get('sugarcube_album_song');
    my $album_or_song;

    if ( $sugarcube_album_song == 0 ) {
        $album_or_song = '&album%3d';    # album
    }
    else {
        $album_or_song = '&song%3d';     # song
    }

    $mypageurl =
      (     'http://'
          . $miphosturl . ':'
          . $sugarport
          . '/api/mix?&sizetype=tracks&size='
          . $sugarmipsize
          . $album_or_song
          . $tracktitle
          . $sugarcube_style
          . $sugarcube_variety );

    my $sugarcube_mix_type = $prefs->client($client)->get('sugarcube_mix_type');
    if ( $sugarcube_mix_type == 2 ) {    # Genre Mixing

        my $sugarcube_genre = $prefs->client($client)->get('sugarcube_genre');
        if ( $sugarcube_genre eq '0' || $sugarcube_genre eq '(None)' ) {
            $log->debug("Genre Filter is not set\n");
        }
        else {
            $log->debug("Genre Mixing Using:$sugarcube_genre\n");
            $mypageurl = $mypageurl . '&filter=' . $sugarcube_genre;
        }
    }
    elsif ( $sugarcube_mix_type == 1 ) {    # Filter Mixing

        my $sugarcube_activefilter =
          $prefs->client($client)->get('sugarcube_filteractive');

        if ( $sugarcube_activefilter eq '0' ) {
            $log->debug("Filter Mixing but filter is set to NONE\n");
        }
        else {
            my $myos = Slim::Utils::OSDetect::OS();
            if ( $myos eq 'win' || $myos eq 'mac' ) {
                $sugarcube_activefilter =
                  URI::Escape::uri_escape($sugarcube_activefilter);
            }
            else {
                $sugarcube_activefilter =
                  Slim::Utils::Misc::escape($sugarcube_activefilter);
            }
            $mypageurl = $mypageurl . '&filter=' . $sugarcube_activefilter;
        }
    }
    elsif ( $sugarcube_mix_type == 3 ) {    # Artist Mixing
        my $sugarcube_artist = $prefs->client($client)->get('sugarcube_artist');
        $log->debug("Artist Mixing:$sugarcube_artist\n");

        if ( $sugarcube_artist eq '0' ) {
            $log->debug("Artist Mixing but artist is set to NONE\n");
        }
        $mypageurl =
          (     'http://'
              . $miphosturl . ':'
              . $sugarport
              . '/api/mix?&sizetype=tracks&size='
              . $sugarmipsize
              . '&artist%3d'
              . $sugarcube_artist
              . $sugarcube_style
              . $sugarcube_variety );
    }
    my $sugarcube_receipes =
      '&recipe=' . $prefs->client($client)->get('sugarcube_receipes');
    if ( $sugarcube_receipes ne '&recipe=0' ) {
        $mypageurl = $mypageurl . $sugarcube_receipes;
    }
    my $sugarcube_restrict_genre =
      $prefs->client($client)->get('sugarcube_restrict_genre');
    if ( $sugarcube_restrict_genre == 1 ) {
        $mypageurl = $mypageurl . '&mixgenre=1';
    }

# Use to generate a MIP Error for testing
#		$mypageurl = 'http://localhost:10002/api/mix?&sizetype=tracks&size=15&genre=a';
#
#		$log->debug("\nURL to Request:\n$mypageurl\n");
    return $mypageurl;
}

sub objectForUrl {
    my $url = shift;
    return Slim::Schema->objectForUrl( { 'url' => $url } );
}

sub gotErrorViaHTTP {
    my $http   = shift;
    my $params = $http->params();
    my $client = $params->{'client'};
    gotErrorContinue( $client, $http );
}

sub gotErrorContinue {
    my $client = shift;
    my $http   = shift;

    my $content = $http->content();

    #	$log->debug("MIP Error - Response;\n$content\n");

    if ( $content eq 'API error - invalid request or internal error.' ) {

        $log->debug(
            "MUSICIP RETURNED API error - invalid request or internal error\n");

        $mixstatus =
          'MUSICIP RETURNED API error - invalid request or internal error'
          ;    # Error reporting

        my $msg =
          ('CAUTION: MusicIP API error - invalid request or internal error');
        $client->showBriefly(
            {
                'jive' => {
                    'type' => 'popupplay',
                    'text' =>
                      [ $client->string('PLUGIN_SUGARCUBE'), ' ', $msg ],
                }
            }
        );
    }
    elsif ( $content eq '' ) {
        $log->debug("\n#### MUSICIP FAILED ####\n");
        $log->debug(
            "\nMUSICIP RETURNED NOTHING\nCheck API Service is Running\n");
        $log->debug("\n#### MUSICIP FAILED ####\n");

        $mixstatus = 'MUSICIP RETURNED NOTHING - Check API Service is Running'
          ;    # Error reporting

        my $msg = ('CAUTION: MusicIP API error - Check API Service is Running');
        $client->showBriefly(
            {
                'jive' => {
                    'type' => 'popupplay',
                    'text' =>
                      [ $client->string('PLUGIN_SUGARCUBE'), ' ', $msg ],
                }
            }
        );
    }

    $log->debug(
"\nKeeping music playing requesting (from LMS db) a Random Track matching the Current Playing Tracks Genre\n"
    );
    my $song = randompuller($client);
    if ( $song eq 'FAILED' ) {
        $log->debug(
            "\nFAILED, likely no playing track to use or track has no Genre\n");
        $log->debug("Requesting a completely Random Track (from LMS db)\n");
        my $track = Plugins::SugarCube::Breakout::getRealRandom();
        $log->debug("Selected Completely Random Track;\n$track\n");
        my (
            $CurrentArtist, $CurrentTrack,    $CurrentAlbum,
            $CurrentGenre,  $CurrentAlbumArt, $FullAlbum
        ) = Plugins::SugarCube::Breakout::getSongDetails($track);
        $upnartist{$client}    = $CurrentArtist;
        $upntrack{$client}     = $CurrentTrack;
        $upnalbum{$client}     = $CurrentAlbum;
        $upngenre{$client}     = $CurrentGenre;
        $upnalbumart{$client}  = $CurrentAlbumArt;
        $upnfullalbum{$client} = $FullAlbum;

        #   $log->debug("Save History; $CurrentArtist\n" );

        Plugins::SugarCube::Breakout::SaveHistory(
            $client,       $CurrentArtist,   $CurrentTrack, $CurrentAlbum,
            $CurrentGenre, $CurrentAlbumArt, $FullAlbum
        );

        addtrack( $client, $track );    # song is hashed up
        my $request = $client->execute( ["play"] );

    }
    else {                              # Random Track selected was ok

        my $currentsong = Slim::Player::Playlist::url($client);
        if ( length($currentsong) != 0 ) {
            $currentsong = Slim::Utils::Misc::pathFromFileURL($currentsong);
            $currentsong = dirtyencoder($currentsong);
            ## Current Playing Track Details
            (
                my $PlayArtist,
                my $PlayTrack,
                my $PlayAlbum,
                my $CurrentGenre,
                my $CurrentAlbumArt,
                my $FullAlbum
            ) = Plugins::SugarCube::Breakout::getSongDetails($currentsong);
            if ( length($CurrentAlbumArt) == 0 ) { $CurrentAlbumArt = "0"; }
            $cpartist{$client}    = $PlayArtist;
            $cptrack{$client}     = $PlayTrack;
            $cpalbum{$client}     = $PlayAlbum;
            $cpgenre{$client}     = $CurrentGenre;
            $cpalbumart{$client}  = $CurrentAlbumArt;
            $cpfullalbum{$client} = $FullAlbum;
            $log->debug(
"\nRandom Track Selected matching Current Playing Genre;$CurrentGenre\n"
            );
            $log->debug("\nTrying to Queue Track;$song\n");

            addtrack( $client, $song );    # song is hashed up
        }
        else {
            $log->debug(
"\nCould not use Playing Tracks Genre and LMS did not return anything usable\n"
            );
            $log->debug("\n$song\n");
        }
    }
}

# 	Return the Url of the track in the playlist at specified position 0 being the first item
#	my $track_url = findtrackurl_frompos($client,4);
sub findtrackurl_frompos {
    my $client    = shift;
    my $find_pos  = shift;
    my $track2    = Slim::Player::Playlist::song( $client, $find_pos );
    my $track2url = $track2->url;
    return $track2url;
}

# Merge track and album
# Try and determine if they are the same track but a greatest hits or similar to the playing track
# Compare them then drop static list if 0 then duplicate and update db
sub dupper {
    my $client = shift;
    my $song;
    my @static_list =
      ( "Various", "Artists", "-", "//", "\\", "Instrumental", "Acoustic" );

    ## Current Playing Track Details
    $song = Slim::Player::Playlist::url($client);
    $song = Slim::Utils::Misc::pathFromFileURL($song);
    $song = dirtyencoder($song);
    (
        my $CurrentArtist,
        my $CurrentTrack,
        my $CurrentAlbum,
        my $CurrentGenre,
        my $CurrentAlbumArt,
        my $FullAlbum
    ) = Plugins::SugarCube::Breakout::getSongDetails($song);

    #temptrack, SCTrack, SCalbum, SCgenres, SCartist
    my @stack = Plugins::SugarCube::Breakout::dup_tracks($client)
      ;    # Grab tracks from working set

    my $arraysize = scalar $#stack + 1;

    # Divide by 5 = number of rows
    if ( $arraysize != 0 ) {
        my $stack_size = $arraysize / 5;

        for ( my $i = 0 ; $i < $stack_size ; $i++ ) {

            #				foreach (@stack) {$log->debug("$_");}	# array dumper

            my $check_track_url =
              $stack[ ( $i * 5 ) ];    # pull each element from array
            my $check_track  = $stack[ ( $i * 5 ) + 1 ];
            my $check_artist = $stack[ ( $i * 5 ) + 4 ];

            my $current_track_merged = $CurrentTrack . " " . $CurrentArtist;
            my $next_track_merged    = $check_track . " " . $check_artist;

            my @list1;
            my @list2;

            if ( length $next_track_merged < length $current_track_merged )
            {    # which is longest should be the compared against
                @list1 = split( ' ', $current_track_merged );
                @list2 = split( ' ', $next_track_merged );
            }
            else {
                @list1 = split( ' ', $next_track_merged );
                @list2 = split( ' ', $current_track_merged );
            }

            my %diff;

            @diff{@list1} = undef;
            delete @diff{@list2};

            delete @diff{@static_list}; # remove various artists plus non-alphas

            my $z = scalar keys %diff;

            $log->debug("Current; $current_track_merged\n");
            $log->debug("Against; $next_track_merged\n");
            $log->debug("Scored for URL $z; $check_track_url\n");

            if ( $z == 0 ) {
                $log->debug("Mark as duplicate; $check_track_url\n");
                Plugins::SugarCube::Breakout::update_duplicate( $client,
                    $check_track_url );
            }
        }    # end of for each
    }
}

# Set up Async HTTP request
sub SendtoMIPAsync {
    my $client    = shift;
    my $mypageurl = shift;
    my $http      = Slim::Networking::SimpleAsyncHTTP->new(
        \&gotMIP,
        \&gotErrorViaHTTP,
        {
            caller     => 'Spicefly',
            callerProc => \&SendtoMIPAsync,
            client     => $client,
            timeout    => 60
        }
    );
    $log->debug("\n#### Built URL Request for MusicIP:\n $mypageurl\n####\n");
    $http->get($mypageurl);
}

# Add Track at End of Queue
sub addtrack {
    my $client = shift;
    my $track  = shift;
    my $sugarcube_trackcount =
      $prefs->client($client)->get('sugarcube_trackcount');
    $sugarcube_trackcount++;
    $prefs->client($client)
      ->set( 'sugarcube_trackcount', "$sugarcube_trackcount" );
    if ( $track ne "" ) {
        my $request = $client->execute( [ "playlist", "add", $track ] );
        $request->source('PLUGIN_SUGARCUBE');
    }
}

*escape =
  main::ISWINDOWS ? \&URI::Escape::uri_escape : \&URI::Escape::uri_escape_utf8;

sub commandCallback {
    my $request = shift;
    my $client  = $request->client();
    return unless $client;    # Catch when client has disappeared
    my $checklive = $prefs->client($client)->get('sugarcube_status');
    if ( !defined $checklive ) {
        $prefs->client($client)->set( 'sugarcube_status', 0 );
        $log->debug(
            "SugarCube Prefs Not Set for this client, default to Disabled.\n");
    }

    if ( $checklive == 0 ) {    # Disabled if DISABLED and NOT called by DTSM

        my $DTSM_prefs = preferences('plugin.dontstopthemusic');
        my $provider = $DTSM_prefs->client($client)->get('provider') || '';

        if ( $provider eq 'PLUGIN_SUGARCUBE' ) {
            $log->debug("SugarCube is set to DISABLED for this client\n");
            $log->debug(
                "But SugarCube is ACTIVE DTSM Provider so continue...\n");
        }
        else { return; }
    }

    if (   $request->source && ( $request->source eq 'PLUGIN_SUGARCUBE' )
        || ( $request->source eq 'ALARM' )
        || ( $request->source eq 'SpiceflyONE' ) )
    {
        return 1;
    }

    if ( $request->isCommand( [ ['play'] ] ) ) {
        my $sugarcube_sn = $prefs->client($client)->get('sugarcube_sn');
        if ( $sugarcube_sn == 1 ) {

            my $sugarcube_sn_active =
              $prefs->client($client)->get('sugarcube_ns_active');

            if ( $sugarcube_sn_active == 1 ) {
                my $sugarcube_fade =
                  $prefs->client($client)->get('sugarcube_fade');
                $prefs->client($client)->set( 'sugarcube_ns_active', 0 );
                my $aprefs = preferences('server');
                $aprefs->client($client)
                  ->set( 'transitionType', "$sugarcube_fade" );
                $client->execute( [ "playlist", "repeat", 0 ] );
            }

        }
        Slim::Utils::Timers::setTimer( $client, Time::HiRes::time() + 10,
            \&SugarPlayerCheck );

        my $sugarcube_fade_on_off =
          $prefs->client($client)->get('sugarcube_fade_on_off')
          ;    # Fade or not fade
        if ( $sugarcube_fade_on_off == 1 ) {
            Slim::Utils::Timers::setTimer( $client, Time::HiRes::time() + 20,
                \&CheckSong );
        }

        #		$log->debug("SugarCube Timer Set\n");

    }

    if ( $request->isCommand( [ ['playlist'], ['clear'] ] ) ) {
        my $sugarcube_clear = $prefs->client($client)->get('sugarcube_clear');
        if ( $sugarcube_clear == 1 ) {
            Plugins::SugarCube::Breakout::wipeourtracks($client);
        }
    }

    if ( $request->isCommand( [ ['playlist'], ['newsong'] ] ) ) {
        my $sugardelay = $prefs->get('sugardelay');
        if ( length($sugardelay) == 1 || length($sugardelay) == 2 ) {

            #			$log->debug("SugarCube Delay OK\n");
        }
        else { $sugardelay = 1; }
        Slim::Utils::Timers::killTimers( $client, \&SugarDelay );
        Slim::Utils::Timers::setTimer( $client,
            Time::HiRes::time() + $sugardelay,
            \&SugarDelay );
        Slim::Utils::Timers::setTimer( $client, Time::HiRes::time() + 15,
            \&SugarPlayerCheck );

        my $sugarcube_fade_on_off =
          $prefs->client($client)->get('sugarcube_fade_on_off')
          ;    # Fade or not fade
        if ( $sugarcube_fade_on_off == 1 ) {
            if ( $global_slide_on{$client} eq "on" ) {    # We are fading
                $log->debug("Already Fading during Track Change\n");
                $log->debug("Killing CheckSong Timer\n");
                $log->debug("Queued CheckSong in 20 secs\n");
                Slim::Utils::Timers::killTimers( $client, \&CheckSong );
                Slim::Utils::Timers::killTimers( $client, \&Volume_Save )
                  ;                                       # Save Volume and Fade
                Slim::Utils::Timers::setTimer( $client,
                    Time::HiRes::time() + 20,
                    \&CheckSong );
            }
            else {
                $log->debug("Track Skipped reseting Clocks\n");
                $log->debug("Killing CheckSong Timer\n");
                Slim::Utils::Timers::killTimers( $client, \&CheckSong );
                $log->debug("Killing StartFade Timer\n");
                Slim::Utils::Timers::killTimers( $client, \&StartFade )
                  ;                                       #Paranoia check
                Slim::Utils::Timers::killTimers( $client, \&Volume_Save )
                  ;                                       #Paranoia check

#				Slim::Utils::Timers::killTimers( $client, \&ReverseFade );    #Paranoia check
                $log->debug("Queued CheckSong in 20 secs\n");
                Slim::Utils::Timers::setTimer( $client,
                    Time::HiRes::time() + 20,
                    \&CheckSong );
            }

        }
    }
    if ( $request->isCommand( [ ['stop'] ] ) ) {
        $log->debug("We Stopped :(\n");
        Slim::Utils::Timers::killTimers( $client, \&CheckSong ); #Paranoia check
        Slim::Utils::Timers::killTimers( $client, \&StartFade ); #Paranoia check
        Slim::Utils::Timers::killTimers( $client, \&Volume_Save )
          ;                                                      #Paranoia check
        Slim::Utils::Timers::killTimers( $client, \&ReverseFade )
          ;                                                      #Paranoia check

        my $volume_end = $slide_start_volume{$client};
        Volume_Reset($client) if length $volume_end;             # Reset Volume
    }
    if ( $request->isCommand( [ ['pause'] ] ) ) {
        $log->debug("We Paused :(\n");
        Slim::Utils::Timers::killTimers( $client, \&Volume_Save )
          ;                                                      #Paranoia check
        Slim::Utils::Timers::killTimers( $client, \&CheckSong ); #Paranoia check
        Slim::Utils::Timers::killTimers( $client, \&StartFade ); #Paranoia check
        Slim::Utils::Timers::killTimers( $client, \&ReverseFade )
          ;                                                      #Paranoia check
        my $volume_end = $slide_start_volume{$client};
        Volume_Reset($client) if length $volume_end;             # Reset Volume
    }

}

sub slideVolume {
    my $client = shift;
    my $sugarcube_reducevolume =
      $prefs->client($client)->get('sugarcube_reducevolume');
    my $sugarcube_volumetimefrom =
      $prefs->client($client)->get('sugarcube_volumetimefrom');
    my $sugarcube_volumetimeto =
      $prefs->client($client)->get('sugarcube_volumetimeto');
    my $volumeslide = Slim::Player::Client::volume($client);
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime(time);
    if (   $sugarcube_volumetimefrom - $hour <= 0
        && $sugarcube_volumetimeto - $hour <= 0
        || $sugarcube_volumetimefrom - $hour >= 0
        && $sugarcube_volumetimeto - $hour > 0 )
    {
        $volumeslide = $volumeslide - $sugarcube_reducevolume;
        if ( $volumeslide < 0 ) { $volumeslide = 0; }
        $client->execute( [ "mixer", "volume", $volumeslide ] );
    }
}

sub sleepplayer {
    my $client          = shift;
    my $sugarcube_sleep = $prefs->client($client)->get('sugarcube_sleep');
    if ( $sugarcube_sleep == 1 ) {
        my $sleeper = $client->sleepTime();
        if ( $sleeper == 0 ) {
            my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst )
              = localtime(time);
            my $sugarcube_sleepfrom =
              $prefs->client($client)->get('sugarcube_sleepfrom');
            my $sugarcube_sleepto =
              $prefs->client($client)->get('sugarcube_sleepto');
            my $sugarcube_sleepduration =
              $prefs->client($client)->get('sugarcube_sleepduration');
            if (   $sugarcube_sleepfrom - $hour <= 0
                && $sugarcube_sleepto - $hour <= 0
                || $sugarcube_sleepfrom - $hour >= 0
                && $sugarcube_sleepto - $hour > 0 )
            {
                $sugarcube_sleepduration = $sugarcube_sleepduration * 60;
                $client->execute( [ "sleep", $sugarcube_sleepduration ] );
            }
        }
    }
}

#  This always felt terrible but it did the job
sub dirtyencoder {
    my $mytitle = shift;

    #$log->debug("Pre-Conversion; $mytitle\n");
    $mytitle =~ s/%/%25/g;
    $mytitle =~ s/\^/%5E/g;
    $mytitle =~ s/{/%7B/g;
    $mytitle =~ s/}/%7D/g;
    $mytitle =~ s/�/%80/g;
    $mytitle =~ s/�/%82/g;
    $mytitle =~ s/�/%83/g;
    $mytitle =~ s/�/%84/g;
    $mytitle =~ s/�/%85/g;
    $mytitle =~ s/�/%86/g;
    $mytitle =~ s/�/%87/g;
    $mytitle =~ s/�/%88/g;
    $mytitle =~ s/�/%89/g;
    $mytitle =~ s/�/%8A/g;
    $mytitle =~ s/�/%8B/g;
    $mytitle =~ s/�/%8C/g;
    $mytitle =~ s/�/%91/g;
    $mytitle =~ s/�/%92/g;
    $mytitle =~ s/�/%93/g;
    $mytitle =~ s/�/%94/g;
    $mytitle =~ s/�/%95/g;
    $mytitle =~ s/�/%96/g;
    $mytitle =~ s/�/%97/g;
    $mytitle =~ s/�/%98/g;
    $mytitle =~ s/�/%99/g;
    $mytitle =~ s/�/%9A/g;
    $mytitle =~ s/�/%9B/g;
    $mytitle =~ s/�/%9C/g;
    $mytitle =~ s/�/%9E/g;
    $mytitle =~ s/�/%9F/g;
    $mytitle =~ s/�/%A1/g;
    $mytitle =~ s/�/%A2/g;
    $mytitle =~ s/�/%A3/g;
    $mytitle =~ s/�/%A5/g;
    $mytitle =~ s/�/%A7/g;
    $mytitle =~ s/�/%A8/g;
    $mytitle =~ s/�/%A9/g;
    $mytitle =~ s/�/%AA/g;
    $mytitle =~ s/�/%AB/g;
    $mytitle =~ s/�/%AC/g;
    $mytitle =~ s/�/%AE/g;
    $mytitle =~ s/�/%AF/g;
    $mytitle =~ s/�/%B0/g;
    $mytitle =~ s/�/%B1/g;
    $mytitle =~ s/�/%B2/g;
    $mytitle =~ s/�/%B3/g;
    $mytitle =~ s/�/%B4/g;
    $mytitle =~ s/�/%B5/g;
    $mytitle =~ s/�/%B6/g;
    $mytitle =~ s/�/%B7/g;
    $mytitle =~ s/�/%B8/g;
    $mytitle =~ s/�/%B9/g;
    $mytitle =~ s/�/%BA/g;
    $mytitle =~ s/�/%BB/g;
    $mytitle =~ s/�/%BC/g;
    $mytitle =~ s/�/%BD/g;
    $mytitle =~ s/�/%BE/g;
    $mytitle =~ s/�/%BF/g;
    $mytitle =~ s/�/%C0/g;
    $mytitle =~ s/�/%C1/g;
    $mytitle =~ s/�/%C2/g;
    $mytitle =~ s/�/%C3/g;
    $mytitle =~ s/�/%C4/g;
    $mytitle =~ s/�/%C5/g;
    $mytitle =~ s/�/%C6/g;
    $mytitle =~ s/�/%C7/g;
    $mytitle =~ s/�/%C8/g;
    $mytitle =~ s/�/%C9/g;
    $mytitle =~ s/�/%CA/g;
    $mytitle =~ s/�/%CB/g;
    $mytitle =~ s/�/%CC/g;
    $mytitle =~ s/�/%CD/g;
    $mytitle =~ s/�/%CE/g;
    $mytitle =~ s/�/%CF/g;
    $mytitle =~ s/�/%D0/g;
    $mytitle =~ s/�/%D1/g;
    $mytitle =~ s/�/%D2/g;
    $mytitle =~ s/�/%D3/g;
    $mytitle =~ s/�/%D4/g;
    $mytitle =~ s/�/%D5/g;
    $mytitle =~ s/�/%D6/g;
    $mytitle =~ s/�/%D7/g;
    $mytitle =~ s/�/%D8/g;
    $mytitle =~ s/�/%D9/g;
    $mytitle =~ s/�/%DA/g;
    $mytitle =~ s/�/%DB/g;
    $mytitle =~ s/�/%DC/g;
    $mytitle =~ s/�/%DD/g;
    $mytitle =~ s/�/%DE/g;
    $mytitle =~ s/�/%DF/g;
    $mytitle =~ s/�/%E0/g;
    $mytitle =~ s/�/%E1/g;
    $mytitle =~ s/�/%E2/g;
    $mytitle =~ s/�/%E3/g;
    $mytitle =~ s/�/%E4/g;
    $mytitle =~ s/�/%E5/g;
    $mytitle =~ s/�/%E6/g;
    $mytitle =~ s/�/%E7/g;
    $mytitle =~ s/�/%E8/g;
    $mytitle =~ s/�/%E9/g;
    $mytitle =~ s/�/%EA/g;
    $mytitle =~ s/�/%EB/g;
    $mytitle =~ s/�/%EC/g;
    $mytitle =~ s/�/%ED/g;
    $mytitle =~ s/�/%EE/g;
    $mytitle =~ s/�/%EF/g;
    $mytitle =~ s/�/%F0/g;
    $mytitle =~ s/�/%F1/g;
    $mytitle =~ s/�/%F2/g;
    $mytitle =~ s/�/%F3/g;
    $mytitle =~ s/�/%F4/g;
    $mytitle =~ s/�/%F5/g;
    $mytitle =~ s/�/%F6/g;
    $mytitle =~ s/�/%F7/g;
    $mytitle =~ s/�/%F8/g;
    $mytitle =~ s/�/%F9/g;
    $mytitle =~ s/�/%FA/g;
    $mytitle =~ s/�/%FB/g;
    $mytitle =~ s/�/%FC/g;
    $mytitle =~ s/�/%FD/g;
    $mytitle =~ s/�/%FE/g;
    $mytitle =~ s/�/%FF/g;
    $mytitle =~ s/'/%27/g;
    $mytitle =~ s/\#/%23/g;
    $mytitle =~ s/;/%3B/g;
    $mytitle =~ s/\\/\//g;
    $mytitle =~ s/ /%20/g;
    $mytitle =~ s/`/%60/g;
    $mytitle =~ s/\?/%BF/g;
    $mytitle =~ s/�/%A9/g;
    $mytitle =~ s/\xa0/%A0/g;

    #$log->debug("Post Conversion but Pre-Encoded Path; $mytitle\n");
    my $a = substr( $mytitle, 0, 4 );
    if   ( $a =~ m/:/i ) { $mytitle = 'file:///' . $mytitle; }
    else                 { $mytitle = 'file://' . $mytitle; }

    #$log->debug("Post-Encoded Path; $mytitle\n");
    return $mytitle;
}

sub Shuffle {
    my ( $client, $item ) = @_;
    my $sugarcube_shuffle;
    my $line;

    if ( $item eq '{PLUGIN_SUGARCUBE_SHUFFLEON}' ) {
        $sugarcube_shuffle = 1;
        my $players = Slim::Player::Client::name($client);
        $prefs->client($client)
          ->set( 'sugarcube_shuffle', "$sugarcube_shuffle" );
        $line = $client->string('PLUGIN_SUGARCUBE_SHUFFLEENABLE');
    }
    else {
        $sugarcube_shuffle = 0;
        my $players = Slim::Player::Client::name($client);
        $prefs->client($client)
          ->set( 'sugarcube_shuffle', "$sugarcube_shuffle" );
        $line = $client->string('PLUGIN_SUGARCUBE_SHUFFLEDISABLE');
    }
    $client->showBriefly(
        {
            'line1' => $client->string('PLUGIN_SUGARCUBE'),
            'line2' => $line
        },
        { 'duration' => 5, 'block' => 0 }
    );
    return;
}

sub ToggleInjector {
    my ( $client, $item ) = @_;
    my $sugarcube_status;
    my $line;
    if ( $item eq '{PLUGIN_SUGARCUBE_INJECTOR_ON}' ) {
        $sugarcube_status = 1;
        my $players = Slim::Player::Client::name($client);
        $prefs->client($client)->set( 'sugarcube_status', "$sugarcube_status" );
        $line = $client->string('PLUGIN_INJECTORON_MENU_ENABLE');
        SugarCubeEnabled($client);
    }
    else {
        $sugarcube_status = 0;
        my $players = Slim::Player::Client::name($client);
        $prefs->client($client)->set( 'sugarcube_status', "$sugarcube_status" );
        $line = $client->string('PLUGIN_INJECTOROFF_MENU_DISABLED');
        SugarCubeDisabled($client);
    }
    $client->showBriefly(
        {
            'line1' => $client->string('PLUGIN_SUGARCUBE'),
            'line2' => $line
        },
        { 'duration' => 5, 'block' => 0 }
    );
    return;
}

sub UpNext {
    my ( $client, $item ) = @_;
    my $line;
    my $sugarcube_upnext;
    if ( $item eq '{PLUGIN_SUGARCUBE_UPNEXT_ON}' ) {
        $sugarcube_upnext = 1;
        my $players = Slim::Player::Client::name($client);
        $prefs->client($client)->set( 'sugarcube_upnext', "$sugarcube_upnext" );
        $line = $client->string('PLUGIN_UPNEXT_MENU_ENABLE');
    }
    else {
        $sugarcube_upnext = 0;
        my $players = Slim::Player::Client::name($client);
        $prefs->client($client)->set( 'sugarcube_upnext', "$sugarcube_upnext" );
        $line = $client->string('PLUGIN_UPNEXT_MENU_DISABLED');
    }
    $client->showBriefly(
        {
            'line1' => $client->string('PLUGIN_SUGARCUBE'),
            'line2' => $line
        },
        { 'duration' => 5, 'block' => 0 }
    );
    return;
}

sub AutoStartMix {
    my ( $client, $item ) = @_;
    my $line = $client->string('PLUGIN_SUGARCUBE_START');
    $client->showBriefly(
        {
            'line1' => $client->string('PLUGIN_SUGARCUBE'),
            'line2' => $line
        },
        { 'duration' => 5, 'block' => 0 }
    );
    my $request = $client->execute( [ 'playlist', 'clear' ] );
    $request->source('PLUGIN_SUGARCUBE');

    my $sugarcube_activefilter;
    my $scalarm_genre = $prefs->client($client)->get('scalarm_genre');
    my $sugarport     = $prefs->get('sugarport');
    my $miphosturl    = $prefs->get('miphosturl');
    my $sugarmipsize  = $prefs->get('sugarmipsize');

    my $mypageurl =
      (     'http://'
          . $miphosturl . ':'
          . $sugarport
          . '/api/mix?&sizetype=tracks&size='
          . $sugarmipsize );

    my $sugarcube_alarm_type =
      $prefs->client($client)->get('sugarcube_alarm_type')
      ;    # 0 is filter 1 is genre

    if ( $sugarcube_alarm_type == 0 ) {    # Filter Mode
        $sugarcube_activefilter =
          $prefs->client($client)->get('scalarm_filter');
        if (   $sugarcube_activefilter eq '0'
            || $sugarcube_activefilter eq '(None)' )
        {
            $log->debug("Alarm Filter is not set\n");
            $sugarcube_activefilter = '';
        }
        else {
            my $myos = Slim::Utils::OSDetect::OS();
            if ( $myos eq 'win' || $myos eq 'mac' ) {
                $sugarcube_activefilter =
                  URI::Escape::uri_escape($sugarcube_activefilter);
            }
            else {
                $sugarcube_activefilter =
                  Slim::Utils::Misc::escape($sugarcube_activefilter);
            }
            $mypageurl = ( $mypageurl . '&filter=' . $sugarcube_activefilter );
        }
    }
    else {    # Genre Mode
        $sugarcube_activefilter = $prefs->client($client)->get('scalarm_genre');

        if (   $sugarcube_activefilter eq '0'
            || $sugarcube_activefilter eq '(None)' )
        {
            $log->debug("Genre Filter is not set\n");
        }
        else {
            $mypageurl = ( $mypageurl . '&filter=' . $sugarcube_activefilter );
        }
    }

    my $http = Slim::Networking::SimpleAsyncHTTP->new(
        \&gotMIP,
        \&gotErrorViaHTTP,
        {
            caller     => 'SpiceflyAutoMix',
            callerProc => \&AutoStartMix,
            client     => $client,
            timeout    => 60
        }
    );
    $http->get($mypageurl);
}

sub ToggleVolume {
    my ( $client, $item ) = @_;
    my $sugarcubevolume_flag;
    my $line;
    if ( $item eq '{PLUGIN_SUGARCUBE_VOLUME_FADE_ON}' ) {
        $sugarcubevolume_flag = 0;
        $prefs->client($client)
          ->set( 'sugarcubevolume_flag', "$sugarcubevolume_flag" );
        $line = $client->string('PLUGIN_SUGARCUBE_MENU_VOL_DISABLED');
    }
    else {
        $sugarcubevolume_flag = 1;
        $prefs->client($client)
          ->set( 'sugarcubevolume_flag', "$sugarcubevolume_flag" );
        $line = $client->string('PLUGIN_SUGARCUBE_MENU_VOL_ENABLE');
    }
    $client->showBriefly(
        {
            'line1' => $client->string('PLUGIN_SUGARCUBE'),
            'line2' => $line
        },
        { 'duration' => 5, 'block' => 0 }
    );
    return;
}

sub ToggleSleep {
    my ( $client, $item ) = @_;
    my $sugarcube_sleep;
    my $line;
    if ( $item eq '{PLUGIN_SUGARCUBE_MENU_SLEEP_ENABLE}' ) {
        $sugarcube_sleep = 0;
        $prefs->client($client)->set( 'sugarcube_sleep', "$sugarcube_sleep" );
        $line = $client->string('PLUGIN_SUGARCUBE_MENU_SLEEP_DISABLED');
    }
    else {
        $sugarcube_sleep = 1;
        $prefs->client($client)->set( 'sugarcube_sleep', "$sugarcube_sleep" );
        $line = $client->string('PLUGIN_SUGARCUBE_MENU_SLEEP_ENABLE');
    }
    $client->showBriefly(
        {
            'line1' => $client->string('PLUGIN_SUGARCUBE'),
            'line2' => $line
        },
        { 'duration' => 5, 'block' => 0 }
    );
    return;
}

sub SugarCubeEnabled {
    my $client = shift;
    my $sugarcube_albumoveride =
      $prefs->client($client)->get('sugarcube_albumoveride');
    if ( $sugarcube_albumoveride == 1 ) {
        my $aprefs = preferences('server');
        $aprefs->client($client)->set( 'playtrackalbum', 0 );
    }
}

sub SugarCubeDisabled {
    my $client = shift;
    my $sugarcube_albumoveride =
      $prefs->client($client)->get('sugarcube_albumoveride');
    if ( $sugarcube_albumoveride == 1 ) {
        my $aprefs = preferences('server');
        $aprefs->client($client)->set( 'playtrackalbum', 1 );
    }
}

sub getAlarmPlaylists {
    my $class = shift;
    Slim::Utils::Alarm->addPlaylists(
        'PLUGIN_SUGARCUBE',
        [
            {
                title => '{PLUGIN_SUGARCUBE_TRACK}',
                url   => 'sugarcube:track'
            },
        ]
    );
}

sub AlarmFired {
    my $client = shift;
    my $track;
    my $mypageurl;
    my $sugarcube_activefilter;
    my $sugarmipsize = $prefs->get('sugarmipsize');
    my $sugarport    = $prefs->get('sugarport');
    my $miphosturl   = $prefs->get('miphosturl');

    $mypageurl =
      (     'http://'
          . $miphosturl . ':'
          . $sugarport
          . '/api/mix?&sizetype=tracks&size='
          . $sugarmipsize );

    my $sugarcube_alarm_type =
      $prefs->client($client)->get('sugarcube_alarm_type')
      ;    # 0 is filter 1 is genre

    if ( $sugarcube_alarm_type == 0 ) {    # Filter Mode
        $sugarcube_activefilter =
          $prefs->client($client)->get('scalarm_filter');
        if (   $sugarcube_activefilter eq '0'
            || $sugarcube_activefilter eq '(None)' )
        {
            $log->debug("Alarm Filter is not set\n");
            $sugarcube_activefilter = '';
        }
        else {
            my $myos = Slim::Utils::OSDetect::OS();
            if ( $myos eq 'win' || $myos eq 'mac' ) {
                $sugarcube_activefilter =
                  URI::Escape::uri_escape($sugarcube_activefilter);
            }
            else {
                $sugarcube_activefilter =
                  Slim::Utils::Misc::escape($sugarcube_activefilter);
            }
            $mypageurl = ( $mypageurl . '&filter=' . $sugarcube_activefilter );
        }
    }
    else {    # Genre Mode
        $sugarcube_activefilter = $prefs->client($client)->get('scalarm_genre');

        if (   $sugarcube_activefilter eq '0'
            || $sugarcube_activefilter eq '(None)' )
        {
            $log->debug("Genre Filter is not set\n");
        }
        else {
            $mypageurl = ( $mypageurl . '&filter=' . $sugarcube_activefilter );
        }
    }

    $log->debug("Alarm URL created; $mypageurl\n");

    my $http = Slim::Networking::SimpleAsyncHTTP->new(
        \&gotMIP,
        \&gotErrorViaHTTP,
        {
            caller     => 'SpiceflyAlarm',
            callerProc => \&AlarmFired,
            client     => $client,
            timeout    => 60
        }
    );
    $http->get($mypageurl);
}

sub webPages {
    my $class   = shift;
    my $urlBase = 'plugins/SugarCube/settings';

    my $sugarlvweight = $prefs->get('sugarlvweight');
    if (   length($sugarlvweight) == 1
        || length($sugarlvweight) == 2
        || length($sugarlvweight) == 3 )
    {
    }
    else {
        $sugarlvweight = 84;
    }
    my $sugarhisweight = $prefs->get('sugarhisweight');
    if (   length($sugarhisweight) == 1
        || length($sugarhisweight) == 2
        || length($sugarhisweight) == 3 )
    {
    }
    else {
        $sugarhisweight = 85;
    }

    Slim::Web::Pages->addPageLinks( "browseiPeng",
        { 'PLUGIN_SUGARCUBELV' => $htmlTemplateLV } );    #fuck knows
    Slim::Web::Pages->addPageLinks( "browseiPeng",
        { 'PLUGIN_SUGARCUBEHIS' => $htmlTemplate } );
    Slim::Web::Pages->addPageLinks( "browseiPeng",
        { 'PLUGIN_SUGARCUBEQP' => $htmlQuickPlay } );

    Slim::Web::Pages->addPageLinks( "browse",
        { 'PLUGIN_SUGARCUBELV' => $htmlTemplateLV } );
    Slim::Web::Pages->addPageLinks(
        "icons",
        {
            'PLUGIN_SUGARCUBELV' =>
              'plugins/SugarCube/HTML/images/sugarcube.png'
        }
    );
    Slim::Web::Pages->addPageFunction( "$urlBase/liveview.html",
        \&handleWebList );
    Slim::Web::HTTP::CSRF->protectURI("$urlBase/liveview.html");

    Slim::Web::Pages->addPageLinks( "browse",
        { 'PLUGIN_SUGARCUBEHIS' => $htmlTemplate } );
    Slim::Web::Pages->addPageLinks(
        "icons",
        {
            'PLUGIN_SUGARCUBEHIS' =>
              'plugins/SugarCube/HTML/images/sugarcube.png'
        }
    );
    Slim::Web::Pages->addPageFunction( "$urlBase/history.html",
        \&handleWebListHistory );
    Slim::Web::HTTP::CSRF->protectURI("$urlBase/history.html");

    Slim::Web::Pages->addPageLinks( "browse",
        { 'PLUGIN_SUGARCUBEQP' => $htmlQuickPlay } );
    Slim::Web::Pages->addPageLinks(
        "icons",
        {
            'PLUGIN_SUGARCUBEQP' =>
              'plugins/SugarCube/HTML/images/sugarcube.png'
        }
    );
    Slim::Web::Pages->addPageFunction( "$urlBase/quickplay.html",
        \&handleWebQP );
    Slim::Web::HTTP::CSRF->protectURI("$urlBase/quickplay.html");

    if ( UNIVERSAL::can( "Slim::Plugin::Base", "addWeight" ) ) {
        Slim::Plugin::Base->addWeight( "PLUGIN_SUGARCUBELV",  $sugarlvweight );
        Slim::Plugin::Base->addWeight( "PLUGIN_SUGARCUBEHIS", $sugarhisweight );
        Slim::Plugin::Base->addWeight( "PLUGIN_SUGARCUBEQP",  $sugarhisweight );
    }
}

sub handleWebQP {
    my ( $client, $params ) = @_;
    $client = Slim::Player::Client::getClient( $params->{player} );
    if ($client) {
        mixfromplaying( $client, "yes" );
        return Slim::Web::HTTP::filltemplatefile( $htmlQuickPlay, $params );
    }
}

sub handleWebListHistory {
    my ( $client, $params ) = @_;
    $client = Slim::Player::Client::getClient( $params->{player} );

    my $aprefs      = preferences('server');
    my $refreshRate = $aprefs->get('refreshRate');
    $params->{'refreshRate'} = $refreshRate * 1000;

    my $sugarlvwidth = $prefs->get('sugarlvwidth');
    $params->{'tablewidth'} = $sugarlvwidth;

    my $sugarlviconsize = $prefs->get('sugarlviconsize');
    $params->{'size'} = $sugarlviconsize;

    if ($client) {

        my $sugarcubeworking = $prefs->client($client)->get('sugarcube_working')
          ;    # reset for the stats page
        my $sugarcube_randomtrack =
          $prefs->client($client)->get('sugarcube_randomtrack');
        my $quicktrackcount =
          $prefs->client($client)->get('sugarcube_trackcount');

        if ( !defined $quicktrackcount ) {
            $params->{'sugarcube_trackcount'} = 0;
            $quicktrackcount = 0;
        }
        else {
            $params->{'sugarcube_trackcount'} =
              $prefs->client($client)->get('sugarcube_trackcount');
        }

        my $quickrandomcount =
          $prefs->client($client)->get('sugarcube_randomcount');

        if ( !defined $quickrandomcount ) {
            $params->{'sugarcube_randomcount'} = 0;
            $quickrandomcount = 0;
        }
        else {
            $params->{'sugarcube_randomcount'} =
              $prefs->client($client)->get('sugarcube_randomcount');
        }
        my $randompercentage;

        if ( $quicktrackcount == 0 ) {
            $randompercentage = 0;
        }
        else {
            $randompercentage = ( $quickrandomcount / $quicktrackcount ) * 100;
        }
        $randompercentage = substr( $randompercentage, 0, 5 ) . "%";
        $params->{'sugarcube_randomcountpercentage'} = $randompercentage;

        my $sugarcube_stats_random_time =
          $prefs->client($client)->get('sugarcube_stats_random_time');
        if ( !defined $sugarcube_stats_random_time ) {
            $params->{'sugarcube_stats_random_time'} = 'N/A';
        }
        else {
            $params->{'sugarcube_stats_random_time'} =
              $sugarcube_stats_random_time;
            $params->{'sugarcube_randomtrack'} = $sugarcube_randomtrack;
        }

        if ( ( $sugarcubeworking == 0 ) && ( $global_quickmix == 0 ) ) {
            $params->{'sugarcube_stats_mip_status'} = ' ';
            $params->{refresh}                      = 1;
            $params->{'filters'}                    = ' ';
            $params->{'track'} =
'SugarCube Disabled or Album/Playlist playing.  SugarCube is waiting.';

        }
        else {
            my $url = Slim::Player::Playlist::song($client);
            if ( $url ne '' ) {
                my $track =
                  Slim::Schema->rs('Track')->objectForUrl( { 'url' => $url, } );
                $params->{'track'} = $track->title;
            }
            $params->{refresh}                      = 1;
            $params->{'filters'}                    = ' ';
            $params->{'sugarcube_stats_mip_status'} = ' ';
        }
        my @history = Plugins::SugarCube::Breakout::GrabHistory($client)
          ;    # Get History from db
        my $historysize = @history;

        my ( $line, $index, $x );

#	                   artist, track, album, genre, albumart, fullalbum FROM History WHERE client ='$clientid'" );
#0		1		2		3		4		5
#	push @previousset, $PlayArtist, $PlayTrack, $PlayAlbum, $CurrentGenre, $CurrentAlbumArt, $FullAlbum;

        for ( $index = 0 ; $index < @history ; ( $index = $index + 6 ) ) {
            $x = $x + 6;

            my $build =
"<a class='myButton' title='Play Album' onclick=\"SqueezeJS.Controller.urlRequest('/anyurl?p0=playlistcontrol&amp;p1=cmd:load&amp;p2=album_id:"
              . @history[ $x - 1 ]
              . "&amp;player="
              . $client
              . "', 1, SqueezeJS.string('Loading Album'));\">Play Album</a>";
            my $icon = @history[ $x - 2 ];
            if ( length($icon) == 0 ) {
                $line =
                    $line
                  . '<tr><td rowspan=5 class=pic><img width='
                  . $sugarlviconsize
                  . ' height='
                  . $sugarlviconsize
                  . ' src=/music/0/cover.jpg></td><td>'
                  . $build
                  . '</td></tr><tr><td>'
                  . @history[ $x - 5 ]
                  . '</td></tr><tr><td>'
                  . @history[ $x - 4 ]
                  . '</td></tr><tr><td>'
                  . @history[ $x - 6 ]
                  . '</td></tr><tr><td>'
                  . @history[ $x - 3 ]
                  . '</td></tr><tr><td colspan=2 class=end>&nbsp;</td></tr><tr><td colspan=2>&nbsp;</td></tr>';
            }
            else {
                $line =
                    $line
                  . '<tr><td rowspan=5 class=pic><img width='
                  . $sugarlviconsize
                  . ' height='
                  . $sugarlviconsize
                  . " src=/music/"
                  . @history[ $x - 2 ]
                  . "/cover_"
                  . $sugarlviconsize . 'x'
                  . $sugarlviconsize
                  . '_o.jpg></td><td>'
                  . $build
                  . '</td></tr><tr><td>'
                  . @history[ $x - 5 ]
                  . '</td></tr><tr><td>'
                  . @history[ $x - 4 ]
                  . '</td></tr><tr><td>'
                  . @history[ $x - 6 ]
                  . '</td></tr><tr><td>'
                  . @history[ $x - 3 ]
                  . '</td></tr><tr><td colspan=2 class=end>&nbsp;</td></tr><tr><td colspan=2>&nbsp;</td></tr>';
            }
        }

        $params->{'filters'} = $line;
    }
    else {
        $params->{'filters'} = 'No Client';
    }
    return Slim::Web::HTTP::filltemplatefile( $htmlTemplate, $params );
}

# LiveView
sub handleWebList {
    my ( $client, $params ) = @_;
    $client = Slim::Player::Client::getClient( $params->{player} );

    my $aprefs      = preferences('server');
    my $refreshRate = $aprefs->get('refreshRate');
    $params->{'refreshRate'} = $refreshRate * 1000;

    my $sugarlvwidth = $prefs->get('sugarlvwidth');
    $params->{'tablewidth'} = $sugarlvwidth;

    my $sugarlviconsize = $prefs->get('sugarlviconsize');
    $params->{'size'}  = $sugarlviconsize;
    $params->{'track'} = '';

    if ($client) {

        my $sugarcube_mode = $prefs->client($client)->get('sugarcube_mode');

        if ( $sugarcube_mode == 0 || $sugarcube_mode eq '' )
        {    # Standard MusicIP Mode (default failback if no prefs set)
            $params->{'mode'} = 'MusicIP Track Recommendations';
        }
        else {
            $params->{'mode'} = 'FreeStyle Track Recommendations';
        }

        my $master = Slim::Player::Sync::isMaster($client);  # Returns 1 if true
        my $slave  = Slim::Player::Sync::isSlave($client);   # Returns 1 if true
        my $name   = Slim::Player::Client::name($client);
        if ( $master == 1 ) {
            $params->{'master'} = '';
        }
        elsif ( $slave == 1 ) {
            my $sync_master = $client->master()->name();
            $params->{'master'} =
"#### Warning $name is a slave in sync group, make changes at $sync_master ####";
        }
        else { $params->{'master'} = ''; }

        my $sugarcubeworking = $prefs->client($client)->get('sugarcube_working')
          ;    # reset for the stats page
        my $sugarcube_randomtrack =
          $prefs->client($client)->get('sugarcube_randomtrack');

        # IF DISABLED
        my $checklive = $prefs->client($client)->get('sugarcube_status');

        if ( !defined $checklive || $checklive == 0 ) {
            my $aprefs      = preferences('server');
            my $refreshRate = $aprefs->get('refreshRate');
            $params->{'refreshRate'}                = $refreshRate * 1000;
            $params->{'track'}                      = 'SugarCube is DISABLED';
            $params->{'filters'}                    = ' ';
            $params->{'sugarcube_stats_mip_status'} = ' ';
            $params->{'currentalbumart'}            = '0';
            $params->{'comingupnextalbumart'}       = '0';
            $params->{'currenttrack'}               = 'SugarCube Disabled';
            $params->{'currentalbum'}               = 'SugarCube Disabled';
            $params->{'currentartist'}              = 'SugarCube Disabled';
            $params->{'currentgenre'}               = 'SugarCube Disabled';
            $params->{'master'}                     = '';

            my $quicktrackcount =
              $prefs->client($client)->get('sugarcube_trackcount');
            if ( !defined $quicktrackcount ) {
                $params->{'sugarcube_trackcount'} = 0;
                $quicktrackcount = 0;
            }
            else {
                $params->{'sugarcube_trackcount'} =
                  $prefs->client($client)->get('sugarcube_trackcount');
            }

            my $quickrandomcount =
              $prefs->client($client)->get('sugarcube_randomcount');

            if ( !defined $quickrandomcount ) {
                $params->{'sugarcube_randomcount'} = 0;
                $quickrandomcount = 0;
            }
            else {
                $params->{'sugarcube_randomcount'} =
                  $prefs->client($client)->get('sugarcube_randomcount');
            }

            my $randompercentage;
            if ( $quicktrackcount == 0 ) {
                $randompercentage = 0;
            }
            else {
                $randompercentage =
                  ( $quickrandomcount / $quicktrackcount ) * 100;
            }
            $randompercentage = substr( $randompercentage, 0, 5 ) . "%";
            $params->{'sugarcube_randomcountpercentage'} = $randompercentage;

            my $sugarcube_stats_random_time =
              $prefs->client($client)->get('sugarcube_stats_random_time');
            if ( !defined $sugarcube_stats_random_time ) {
                $params->{'sugarcube_stats_random_time'} = 'N/A';
            }
            else {
                $params->{'sugarcube_stats_random_time'} =
                  $sugarcube_stats_random_time;
                $params->{'sugarcube_randomtrack'} = $sugarcube_randomtrack;
            }
            return Slim::Web::HTTP::filltemplatefile( $htmlTemplateLV,
                $params );
        }

        # IF ACTIVE
        $params->{'mixstatus'} = $mixstatus;    # Error reporting

        my $quicktrackcount =
          $prefs->client($client)->get('sugarcube_trackcount');
        if ( !defined $quicktrackcount ) {
            $params->{'sugarcube_trackcount'} = 0;
            $quicktrackcount = 0;
        }
        else {
            $params->{'sugarcube_trackcount'} =
              $prefs->client($client)->get('sugarcube_trackcount');
        }

        my $quickrandomcount =
          $prefs->client($client)->get('sugarcube_randomcount');

        if ( !defined $quickrandomcount ) {
            $params->{'sugarcube_randomcount'} = 0;
            $quickrandomcount = 0;
        }
        else {
            $params->{'sugarcube_randomcount'} =
              $prefs->client($client)->get('sugarcube_randomcount');
        }
        my $randompercentage;

        if ( $quicktrackcount == 0 ) {
            $randompercentage = 0;
        }
        else {
            $randompercentage = ( $quickrandomcount / $quicktrackcount ) * 100;
        }
        $randompercentage = substr( $randompercentage, 0, 5 ) . "%";
        $params->{'sugarcube_randomcountpercentage'} = $randompercentage;

        my $sugarcube_stats_random_time =
          $prefs->client($client)->get('sugarcube_stats_random_time');
        if ( !defined $sugarcube_stats_random_time ) {
            $params->{'sugarcube_stats_random_time'} = 'N/A';
        }
        else {
            $params->{'sugarcube_stats_random_time'} =
              $sugarcube_stats_random_time;
            $params->{'sugarcube_randomtrack'} = $sugarcube_randomtrack;
        }

        if ( $sugarcubeworking == 0 ) {
            $params->{'sugarcube_stats_mip_status'} = ' ';
            $params->{refresh}                      = 1;
            $params->{'filters'}                    = ' ';

            $params->{'track'} =
              'Disabled or Album/Playlist playing.  SugarCube is waiting.';

        }
        else {
            # Show error in Live view if Genre mixing but genre is set to None
            my $sugarcube_mix_type =
              $prefs->client($client)->get('sugarcube_mix_type');
            if ( $sugarcube_mix_type == 2 ) {
                my $sugarcube_genre =
                  $prefs->client($client)->get('sugarcube_genre');
                if ( $sugarcube_genre eq '0' ) {
                    $params->{'mixstatus'} =
"CONFIGURATION ERROR: Select Mix Type by Genre: No Genre is specified";
                }
            }
            elsif ( $sugarcube_mix_type == 1 ) {
                my $sugarcube_activefilter =
                  $prefs->client($client)->get('sugarcube_filteractive');
                if ( $sugarcube_activefilter eq '0' ) {
                    $params->{'mixstatus'} =
"CONFIGURATION ERROR: Select Mix Type by Filter: No Filter is specified";
                }
            }
            elsif ( $sugarcube_mix_type == 3 ) {    # Artist Mixing
                my $sugarcube_artist =
                  $prefs->client($client)->get('sugarcube_artist');
                if ( $sugarcube_artist eq '0' ) {
                    $params->{'mixstatus'} =
"CONFIGURATION ERROR: Select Mix Type by Artist: No Artist is specified";
                }
            }

            # Get Currently Playing Metric - Rest are held in previousset array

            my $url = Slim::Player::Playlist::song($client);
            if ( $url ne '' ) {
                my $track =
                  Slim::Schema->rs('Track')->objectForUrl( { 'url' => $url, } );
                $params->{'track'} = $track->title;
                $params->{refresh} = 1;
            }
            $params->{'filters'} =
              Plugins::SugarCube::Breakout::StatsPuller($client);

        }
        if ( $upnartist{$client} ne '' ) {
            my $sugarlvTS = $prefs->get('sugarlvTS');    # use stats
            if ($sugarlvTS) {
                $params->{'showstats'}       = "ON";
                $params->{'currentpc'}       = $cppc{$client};
                $params->{'currentrat'}      = $cprat{$client};
                $params->{'currentlp'}       = $cplp{$client};
                $params->{'comingupnextpc'}  = $upnpc{$client};
                $params->{'comingupnextrat'} = $upnrat{$client};
                $params->{'comingupnextlp'}  = $upnlp{$client};
            }

            $params->{'comingupnextartist'}   = $upnartist{$client};
            $params->{'comingupnexttrack'}    = $upntrack{$client};
            $params->{'comingupnextalbum'}    = $upnalbum{$client};
            $params->{'comingupnextgenre'}    = $upngenre{$client};
            $params->{'comingupnextalbumart'} = $upnalbumart{$client};
            $params->{'currentartist'}        = $cpartist{$client};
            $params->{'currenttrack'}         = $cptrack{$client};
            $params->{'currentalbum'}         = $cpalbum{$client};
            $params->{'currentgenre'}         = $cpgenre{$client};
            $params->{'currentalbumart'}      = $cpalbumart{$client};
        }
        else {
            $params->{'currentartist'}        = "N/A";
            $params->{'currenttrack'}         = "N/A";
            $params->{'currentalbum'}         = "N/A";
            $params->{'currentgenre'}         = "N/A";
            $params->{'currentalbumart'}      = '0';
            $params->{'comingupnextartist'}   = 'N/A';
            $params->{'comingupnexttrack'}    = 'N/A';
            $params->{'comingupnextalbum'}    = 'N/A';
            $params->{'comingupnextgenre'}    = 'N/A';
            $params->{'comingupnextalbumart'} = '0';
        }
    }
    else {
        $params->{'currentartist'}        = "N/A";
        $params->{'currenttrack'}         = "N/A";
        $params->{'currentalbum'}         = "N/A";
        $params->{'currentgenre'}         = "N/A";
        $params->{'currentalbumart'}      = '0';
        $params->{'comingupnextartist'}   = 'N/A';
        $params->{'comingupnexttrack'}    = 'N/A';
        $params->{'comingupnextalbum'}    = 'N/A';
        $params->{'comingupnextgenre'}    = 'N/A';
        $params->{'comingupnextalbumart'} = '0';
    }

    return Slim::Web::HTTP::filltemplatefile( $htmlTemplateLV, $params );
}

sub CheckSong {
    $log->debug("###CheckSong\n");
    my $client      = shift;
    my $currentsong = Slim::Player::Playlist::url($client);
    $currentsong = Slim::Utils::Misc::pathFromFileURL($currentsong);
    $currentsong = dirtyencoder($currentsong);

    my $song_length =
      Plugins::SugarCube::Breakout::get_track_length( $client, $currentsong );

    my $songtime = Slim::Player::Source::songTime($client);

    $log->debug("SongPosition; $songtime\n");

    my $sugarcube_fade_time =
      $prefs->client($client)->get('sugarcube_fade_time');    # Fade timeline

    $log->debug("Fade Length; $sugarcube_fade_time\n");
    $log->debug("Song Length; $song_length\n");
    $song_length = $song_length - $sugarcube_fade_time - $songtime;

    $log->debug("Sleeping waking back up in Secs; $song_length\n");

    if ( $song_length > 30 ) {
        Slim::Utils::Timers::setTimer( $client,
            Time::HiRes::time() + $song_length,
            \&Volume_Save );
        $log->debug("Volume Timer Set\n");
    }
}

sub Volume_Save {
    $log->debug("In Volume Save\n");

    my $client       = shift;
    my $volume_start = Slim::Player::Client::volume($client);

    my $sugarcube_fade_time =
      $prefs->client($client)->get('sugarcube_fade_time');    # Fade timeline

    if ( $global_slide_on{$client} eq "off" )
    {    # If we are not fading save the volume
        $slide_start_volume{$client} = $volume_start;
        $log->debug("Saved slide_start_volume; $slide_start_volume{$client}\n");
    }
    elsif ( !exists $global_slide_on{$client} )
    {    # If we are not fading save the volume
        if ( $volume_start == 0 ) {
            $log->debug("Volume; No Save\n");
        }
        else {
            $slide_start_volume{$client} = $volume_start;
            $log->debug("Saved defective hash; $slide_start_volume{$client}\n");
        }
    }

    StartFade($client);

}

sub StartFade {
    my $client = shift;
    $log->debug("In StartFade\n");

    $global_slide_on{$client} = "on";    # We are fading

    my $sugarcube_fade_time =
      $prefs->client($client)->get('sugarcube_fade_time');    # Fade timeline
    my $volume_start = $slide_start_volume{$client};

    my $volumeslide = Slim::Player::Client::volume($client);
    $log->debug("Reported Volume; $volumeslide\n");
    $volumeslide = $volumeslide - ( $volume_start / $sugarcube_fade_time );

    $volumeslide = int($volumeslide);                         # Round Up

    if ( $volumeslide < 0 ) {
        $volumeslide = 0;
    }
    $log->debug("Dropping Volume to; $volumeslide\n");
    $client->execute( [ "mixer", "volume", $volumeslide ] );

    if ( $volumeslide <= 0 ) {

   #	Slim::Utils::Timers::killTimers( $client, \&StartFade );    #Paranoia check
        Slim::Utils::Timers::setTimer( $client, Time::HiRes::time() + 1,
            \&ReverseFade );    # Fade Volume back up
    }
    else {
        Slim::Utils::Timers::setTimer( $client, Time::HiRes::time() + 1,
            \&StartFade );
    }

}

sub ReverseFade {
    my $client = shift;
    $log->debug("In ReverseFade\n");

    my $volumeslide = Slim::Player::Client::volume($client);
    $log->debug("Current Volume; $volumeslide\n");

    my $sugarcube_fade_time =
      $prefs->client($client)->get('sugarcube_fade_time');    # Fade timeline

    my $volume_end = $slide_start_volume{$client};
    $log->debug("ReverseFade roll back to; $volume_end\n");

    $volumeslide = $volumeslide + ( $volume_end / $sugarcube_fade_time );
    $volumeslide = int($volumeslide);

    if ( $volumeslide > 100 ) {
        $volumeslide = 100;
    }
    $log->debug("Increasing Volume to; $volumeslide\n");
    $client->execute( [ "mixer", "volume", $volumeslide ] );

    if ( $volumeslide >= $volume_end ) {
        Slim::Utils::Timers::killTimers( $client, \&StartFade );
        Slim::Utils::Timers::killTimers( $client, \&ReverseFade );
        $client->execute( [ "mixer", "volume", $volume_end ] )
          ;    #  Set it incase we went above it
        $global_slide_on{$client} = "off";    # We have finished fading
    }
    else {
        Slim::Utils::Timers::setTimer( $client, Time::HiRes::time() + 1,
            \&ReverseFade );
    }
}

# Jump Volume back
sub Volume_Reset {
    my $client     = shift;
    my $volume_end = $slide_start_volume{$client};

    $client->execute( [ "mixer", "volume", $volume_end ] );
    $global_slide_on{$client} = "off";    # We have finished fading
    $log->debug("Volume_Reset; $volume_end\n");

}

1;
