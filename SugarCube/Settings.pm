package Plugins::SugarCube::Settings;

use strict;
use base qw(Slim::Web::Settings);
use Slim::Utils::Prefs;

my $prefs = preferences('plugin.SugarCube');

use Slim::Utils::Log;
sub getDisplayName { return 'PLUGIN_SUGARCUBE'; }
my $log = Slim::Utils::Log->addLogCategory(
    {
        'category'     => 'plugin.sugarcube',
        'defaultLevel' => 'WARN',
        'description'  => getDisplayName(),
    }
);

sub name {
    return Slim::Web::HTTP::CSRF->protectName('PLUGIN_SUGARCUBE');
}

sub page {
    return Slim::Web::HTTP::CSRF->protectURI(
        'plugins/SugarCube/settings/settings.html');
}

sub handler {
    my ( $class, $client, $params ) = @_;
    if ( $params->{'saveSettings'} ) {    # SAVE MODE
        my $sugarport = $params->{'sugarport'};
        $prefs->set( 'sugarport', "$sugarport" );
        my $miphosturl = $params->{'miphosturl'};
        $prefs->set( 'miphosturl', "$miphosturl" );
        my $sugardelay = $params->{'sugardelay'};
        $prefs->set( 'sugardelay', "$sugardelay" );
        my $sugarlvwidth = $params->{'sugarlvwidth'};
        $prefs->set( 'sugarlvwidth', "$sugarlvwidth" );
        my $sugarlviconsize = $params->{'sugarlviconsize'};
        $prefs->set( 'sugarlviconsize', "$sugarlviconsize" );
        my $sugarlvTS = $params->{'sugarlvTS'};
        $prefs->set( 'sugarlvTS', "$sugarlvTS" );
        my $rating_10scale = $params->{'rating_10scale'};
        $prefs->set( 'rating_10scale', "$rating_10scale" );
        my $useAPCvalues = $params->{'useapcvalues'};
        $prefs->set( 'useapcvalues', "$useAPCvalues" );
        my $sugarmipsize = $params->{'sugarmipsize'};
        $prefs->set( 'sugarmipsize', "$sugarmipsize" );
        my $sugarhisweight = $params->{'sugarhisweight'};
        $prefs->set( 'sugarhisweight', "$sugarhisweight" );
        my $sugarlvweight = $params->{'sugarlvweight'};
        $prefs->set( 'sugarlvweight', "$sugarlvweight" );
        my $sugarxmas = $params->{'sugarxmas'};
        $prefs->set( 'sugarxmas', "$sugarxmas" );
        my $sqlitetimeout = $params->{'sqlitetimeout'};
        $prefs->set( 'sqlitetimeout', "$sqlitetimeout" );
        my $nasconvertpath = $params->{'nasconvertpath'};
        $prefs->set( 'nasconvertpath', "$nasconvertpath" );
        my $localmediapath = $params->{'localmediapath'};
        $prefs->set( 'localmediapath', "$localmediapath" );
        my $nasconvertpath_2 = $params->{'nasconvertpath_2'};
        $prefs->set( 'nasconvertpath_2', "$nasconvertpath_2" );
        my $localmediapath_2 = $params->{'localmediapath_2'};
        $prefs->set( 'localmediapath_2', "$localmediapath_2" );
        my $sugardpc = $params->{'sugardpc'};
        $prefs->set( 'sugardpc', "$sugardpc" );

        my $traf_enable = $params->{'traf_enable'};
        $prefs->set( 'traf_enable', "$traf_enable" );
        my $traf_origin = $params->{'traf_origin'};
        $prefs->set( 'traf_origin', "$traf_origin" );
        my $traf_destination = $params->{'traf_destination'};
        $prefs->set( 'traf_destination', "$traf_destination" );

        my $traf_enable_two = $params->{'traf_enable_two'};
        $prefs->set( 'traf_enable_two', "$traf_enable_two" );
        my $traf_origin_two = $params->{'traf_origin_two'};
        $prefs->set( 'traf_origin_two', "$traf_origin_two" );
        my $traf_destination_two = $params->{'traf_destination_two'};
        $prefs->set( 'traf_destination_two', "$traf_destination_two" );

        my $traf_journey_two = $params->{'traf_journey_two'};
        $prefs->set( 'traf_journey_two', "$traf_journey_two" );
        my $traf_journey_one = $params->{'traf_journey_one'};
        $prefs->set( 'traf_journey_one', "$traf_journey_one" );

        my $traf_key = $params->{'traf_key'};
        $prefs->set( 'traf_key', "$traf_key" );
        my $traf_from = $params->{'traf_from'};
        $prefs->set( 'traf_from', "$traf_from" );
        my $traf_to = $params->{'traf_to'};
        $prefs->set( 'traf_to', "$traf_to" );

        my $traf_mon = $params->{'traf_mon'};
        $prefs->set( 'traf_mon', "$traf_mon" );
        my $traf_tue = $params->{'traf_tue'};
        $prefs->set( 'traf_tue', "$traf_tue" );
        my $traf_wed = $params->{'traf_wed'};
        $prefs->set( 'traf_wed', "$traf_wed" );
        my $traf_thu = $params->{'traf_thu'};
        $prefs->set( 'traf_thu', "$traf_thu" );
        my $traf_fri = $params->{'traf_fri'};
        $prefs->set( 'traf_fri', "$traf_fri" );
        my $traf_sat = $params->{'traf_sat'};
        $prefs->set( 'traf_sat', "$traf_sat" );
        my $traf_sun = $params->{'traf_sun'};
        $prefs->set( 'traf_sun', "$traf_sun" );

    }    # LOAD
    $params->{'prefs'}->{'sugarport'}        = $prefs->get('sugarport');
    $params->{'prefs'}->{'miphosturl'}       = $prefs->get('miphosturl');
    $params->{'prefs'}->{'sugardelay'}       = $prefs->get('sugardelay');
    $params->{'prefs'}->{'sugarlvwidth'}     = $prefs->get('sugarlvwidth');
    $params->{'prefs'}->{'sugarlviconsize'}  = $prefs->get('sugarlviconsize');
    $params->{'prefs'}->{'sugarlvTS'}        = $prefs->get('sugarlvTS');
    $params->{'prefs'}->{'rating_10scale'}   = $prefs->get('rating_10scale');
    $params->{'prefs'}->{'useapcvalues'}     = $prefs->get('useapcvalues');
    $params->{'prefs'}->{'sugarmipsize'}     = $prefs->get('sugarmipsize');
    $params->{'prefs'}->{'sugarhisweight'}   = $prefs->get('sugarhisweight');
    $params->{'prefs'}->{'sugarlvweight'}    = $prefs->get('sugarlvweight');
    $params->{'prefs'}->{'sugarxmas'}        = $prefs->get('sugarxmas');
    $params->{'prefs'}->{'sqlitetimeout'}    = $prefs->get('sqlitetimeout');
    $params->{'prefs'}->{'nasconvertpath'}   = $prefs->get('nasconvertpath');
    $params->{'prefs'}->{'localmediapath'}   = $prefs->get('localmediapath');
    $params->{'prefs'}->{'nasconvertpath_2'} = $prefs->get('nasconvertpath_2');
    $params->{'prefs'}->{'localmediapath_2'} = $prefs->get('localmediapath_2');
    $params->{'prefs'}->{'sugardpc'}         = $prefs->get('sugardpc');

    # Traffic prefs
    $params->{'prefs'}->{'traf_enable'}      = $prefs->get('traf_enable');
    $params->{'prefs'}->{'traf_origin'}      = $prefs->get('traf_origin');
    $params->{'prefs'}->{'traf_destination'} = $prefs->get('traf_destination');
    $params->{'prefs'}->{'traf_enable_two'}  = $prefs->get('traf_enable_two');
    $params->{'prefs'}->{'traf_origin_two'}  = $prefs->get('traf_origin_two');
    $params->{'prefs'}->{'traf_destination_two'} =
      $prefs->get('traf_destination_two');

    $params->{'prefs'}->{'traf_journey_one'} = $prefs->get('traf_journey_one');
    $params->{'prefs'}->{'traf_journey_two'} = $prefs->get('traf_journey_two');

    $params->{'prefs'}->{'traf_key'}  = $prefs->get('traf_key');
    $params->{'prefs'}->{'traf_from'} = $prefs->get('traf_from');
    $params->{'prefs'}->{'traf_to'}   = $prefs->get('traf_to');
    $params->{'prefs'}->{'traf_mon'}  = $prefs->get('traf_mon');
    $params->{'prefs'}->{'traf_tue'}  = $prefs->get('traf_tue');
    $params->{'prefs'}->{'traf_wed'}  = $prefs->get('traf_wed');
    $params->{'prefs'}->{'traf_thu'}  = $prefs->get('traf_thu');
    $params->{'prefs'}->{'traf_fri'}  = $prefs->get('traf_fri');
    $params->{'prefs'}->{'traf_sat'}  = $prefs->get('traf_sat');
    $params->{'prefs'}->{'traf_sun'}  = $prefs->get('traf_sun');

    return $class->SUPER::handler( $client, $params );
}
1;

__END__
