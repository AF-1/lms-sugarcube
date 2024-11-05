# Google Traffic
# Various API/JSON calls

package Plugins::SugarCube::Traffic;

use strict;
use base qw(Slim::Web::Settings);
use Plugins::SugarCube::Plugin;
use Slim::Utils::Prefs;
use Slim::Utils::Log;
use Slim::Utils::DateTime;
use File::Spec::Functions qw(:ALL);
use DBI qw(:sql_types);
use HTML::Entities qw(decode_entities);
use JSON::XS::VersionOneAndTwo;

use POSIX qw(strftime);

my $step_counter = 0;

my $traf_one_two_counter = 0;

sub getDisplayName { return 'PLUGIN_SUGARCUBE'; }

my $log = Slim::Utils::Log->addLogCategory(
    {
        'category'     => 'plugin.sugarcube',
        'defaultLevel' => 'WARN',
        'description'  => getDisplayName(),
    }
);

my $prefs = preferences('plugin.SugarCube');

#
# All starts from this entry sub-routine called from Plugin.pm
#
sub start {
    my $client = shift;

    $step_counter = $step_counter + 1;
    if ( $step_counter > 2 )
    { # Because SugarCube calls every 20secs add a step counter so only fire every minute
        my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
          localtime(time);

        # Dirty routine to determine whether should fire for the current day
        # This can be optimised
        my $mon = $prefs->get('traf_mon');
        my $tue = $prefs->get('traf_tue');
        my $wed = $prefs->get('traf_wed');
        my $thu = $prefs->get('traf_thu');
        my $fri = $prefs->get('traf_fri');
        my $sat = $prefs->get('traf_sat');
        my $sun = $prefs->get('traf_sun');

        my $fire_day;
        if ( $wday == 0 ) {    # sunday
            if   ( $sun == 1 ) { $fire_day = "YES"; }
            else               { $fire_day = "NO"; }
        }
        elsif ( $wday == 1 ) {    # monday
            if   ( $mon == 1 ) { $fire_day = "YES"; }
            else               { $fire_day = "NO"; }
        }
        elsif ( $wday == 2 ) {    # tuesday
            if   ( $tue == 1 ) { $fire_day = "YES"; }
            else               { $fire_day = "NO"; }
        }
        elsif ( $wday == 3 ) {    # weds
            if   ( $wed == 1 ) { $fire_day = "YES"; }
            else               { $fire_day = "NO"; }
        }
        elsif ( $wday == 4 ) {    # thu
            if   ( $thu == 1 ) { $fire_day = "YES"; }
            else               { $fire_day = "NO"; }
        }
        elsif ( $wday == 5 ) {    # fri
            if   ( $fri == 1 ) { $fire_day = "YES"; }
            else               { $fire_day = "NO"; }
        }
        elsif ( $wday == 6 ) {    # sat
            if   ( $sat == 1 ) { $fire_day = "YES"; }
            else               { $fire_day = "NO"; }
        }
        else {
            $fire_day = "NO";
        }

        if ( $fire_day eq "YES" ) { # Should be active today, check firing hours

            my $traf_from = $prefs->get('traf_from');    # Traffic FROM
            my $traf_to   = $prefs->get('traf_to');      # Traffic TO

            if ( $hour >= $traf_from && $hour <= $traf_to ) {
                get_traffic($client)
                  ;    # So active day and active hours so get Traffic report
            }
        }
        if ( $step_counter > 2 ) { $step_counter = 0; }    # reset counter
    }

}

#Set up Async HTTP request to retrieve Information from Google Traffic API
sub get_traffic {
    my $client = shift;

    my $traf_origin;
    my $traf_destination;
    my $traf_journey;

    if ( $traf_one_two_counter == 0 ) {
        $traf_one_two_counter = 1;
        $traf_journey         = $prefs->get('traf_journey_one');  # Traffic Name
        $traf_origin = $prefs->get('traf_origin');    # Traffic Origin
        $traf_destination =
          $prefs->get('traf_destination');            # Traffic Destination
    }
    else {
        $traf_one_two_counter = 0;
        my $traf_enable_two =
          $prefs->get('traf_enable_two');    # Traffic Address two ENABLED

        if ( $traf_enable_two == 1 ) {
            $traf_journey = $prefs->get('traf_journey_two');    # Traffic Name
            $traf_origin = $prefs->get('traf_origin_two');  # Traffic Origin two
            $traf_destination =
              $prefs->get('traf_destination_two');    # Traffic Destination two
        }
        else {
            $traf_journey = $prefs->get('traf_journey_one');    # Traffic Name
            $traf_origin  = $prefs->get('traf_origin');         # Traffic Origin
            $traf_destination =
              $prefs->get('traf_destination');    # Traffic Destination
        }
    }

#	my $traf_origin = $prefs->get('traf_origin');				# Traffic Origin
#	my $traf_destination = $prefs->get('traf_destination');		# Traffic Destination

    my $traf_key = $prefs->get('traf_key');    # API Key

    my $url =
        'https://maps.googleapis.com/maps/api/directions/json?origin='
      . $traf_origin
      . '&destination='
      . $traf_destination
      . '&mode=driving&departure_time=now&key='
      . $traf_key;

    my $http = Slim::Networking::SimpleAsyncHTTP->new(
        \&got_traffic,                         # call sub on return
        \&ErrorWithCall,                       # if error
        {
            caller     => 'get_traffic',
            callerProc => \&get_traffic,
            client     => $client,
            journey    => $traf_journey,
        }
    );                                         # sub that called request
    $log->debug("async request: $url");
    $http->get(
        $url,
        'User-Agent' =>
          'Mozilla/5.0 (Windows NT 5.1; rv:12.0) Gecko/20100101 Firefox/12.0',
        'Accept-Language' => 'en-us,en;q=0.5',
        'Accept'          => 'text/html',
        'Accept-Charset'  => 'UTF-8'
    );
}

# Called on return with data, JSON and extract what we want
sub got_traffic {
    my $http    = shift;
    my $params  = $http->params();
    my $client  = $params->{'client'};     # Get the client (player)
    my $journey = $params->{'journey'};    # Get the journey

    my $data_set = $http->content();       # RAW data set

    #   $log->debug("RETURNED " . $data_set);

    my $json_traffic =
      decode_json($data_set);              # Decode RAW data into JSON format

    my $duration =
      $json_traffic->{routes}[0]{legs}[0]{duration}{text}; # Normal Journey Time
    my $duration_in_traffic =
      $json_traffic->{routes}[0]{legs}[0]{duration_in_traffic}{text}
      ;    # Time taking into account Traffic
    my $traffic_summary = $json_traffic->{routes}[0]{summary};   # Route Summary
    my $duration_in_traffic_secs =
      $json_traffic->{routes}[0]{legs}[0]{duration_in_traffic}{value}
      ;    # Time taking into account Traffic in secs

    $log->debug( "duration: " . $duration );
    $log->debug( "duration_in_traffic: " . $duration_in_traffic );
    $log->debug( "traffic_summary: " . $traffic_summary );
    $log->debug( "duration_in_traffic_secs: " . $duration_in_traffic_secs );
    $log->debug( "journey: " . $journey );

    my $now = time();
    my $arr_time = $now + ( ($duration_in_traffic_secs) );
    $arr_time = strftime "%H:%M", localtime($arr_time);

    foreach my $player ( Slim::Player::Client::clients() )
    {    # Send alert to each player
        display_traffic( $player, $traffic_summary, $duration,
            $duration_in_traffic, $arr_time, $journey )
          ;    # Send data to Display routine
    }

}

# Display Traffic Detail on Player
sub display_traffic {
    my $client          = shift;
    my $traffic_summary = shift;    # Route Summary (text)
    my $duration        = shift;    # Normal Journey Time (text mins)
    my $duration_in_traffic =
      shift;    # Time taking into account Traffic (text mins)
    my $arr_time = shift;    # Estimated Arrival Time
    my $journey  = shift;    # Journey Name

    my $line1 = $journey . " via " . $traffic_summary;
    my $line2 =
      "Duration: " . $duration . "  With Traffic: " . $duration_in_traffic;
    my $line3 = "Estimated Arrival Time: " . $arr_time;

    # DISPLAY WHAT WE GOT
    $client->showBriefly(
        {
            line => [ $line1, $line2, $line3 ],
            jive => {
                type     => 'popupplay',
                text     => [ $line1, $line2, $line3 ],
                duration => 45000
            },
        },
        {
            scroll    => 1,
            firstline => 1,
            block     => 1,
            duration  => 45,
        }
    );
}

# Only called if http call fails
sub ErrorWithCall {
    my $http   = shift;
    my $params = $http->params();
    my $client = $params->{'client'};

    my $content = $http->content();

    $log->debug("Error - Response;\n$content\n");

    my $msg = ('CAUTION: Traffic Failed');
    $client->showBriefly(
        {
            'jive' => {
                'type' => 'popupplay',
                'text' => [ $client->string('PLUGIN_SUGARCUBE'), ' ', $msg ],
            }
        }
    );
}

1;
__END__
