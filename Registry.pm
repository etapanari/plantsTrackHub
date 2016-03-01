package Registry;

use strict;
use warnings;

# in this cript I connect to the trackHub Registry db and I delete the given study_id under the given track hub Registry account

use JSON;
use HTTP::Request::Common qw/GET DELETE POST/;
use LWP::UserAgent;

my $server = "https://beta.trackhubregistry.org";
$| = 1; 

sub new {

  my $class = shift;
  my $username  = shift;
  my $password = shift;
  
  my $self = {
    username  => $username ,
    pwd => $password
  };

  my $auth_token = eval {registry_login($username, $password) };
  if ($@) {
    print STDERR "Couldn't login using username $username and password $password: $@\n";
    die;
  }
  $self->{auth_token} = $auth_token;

  return bless $self,$class;
}

sub register_track_hub{
 
  my $self = shift;
  my $track_hub_id = shift;
  my $trackHub_txt_file_url = shift;
  my $assembly_name_accession_pairs = shift; 

  my $return_string;

  my $username = $self->{username};
  my $password = $self->{pwd};
  my $auth_token = $self->{auth_token};

  my $ua = LWP::UserAgent->new;

  $trackHub_txt_file_url =~ /.+\/(\w+)\/hub\.txt$/ ;
  my $hub_name = $1;

  my $url = $server . '/api/trackhub';

  #my $assembly_name_accession_pairs=  "ASM242v1,GCA_000002425.1,IRGSP-1.0,GCA_000005425.2";
  my @words = split(/,/, $assembly_name_accession_pairs);
  my $assemblies;
  for(my $i=0; $i<$#words; $i+=2) {
    $assemblies->{$words[$i]} = $words[$i+1];
  }

  my $request = 
    POST($url,'Content-type' => 'application/json',
	 #  assemblies => { "$assembly_name" => "$assembly_accession" } }));
    'Content' => to_json({ url => $trackHub_txt_file_url, type => 'transcriptomics', assemblies => $assemblies }));
  $request->headers->header(user => $username);
  $request->headers->header(auth_token => $auth_token);
  my $response = $ua->request($request);

  my $response_code= $response->code;

  if($response_code == 201) {

   $return_string= "	..$hub_name is Registered\n";

  }elsif($response_code == 503 or $response_code == 500 or $response_code == 400){ #and $response->content=~/server response timed out/)) {

    $return_string= "\tCouldn't register track hub with the first attempt: " .$hub_name."\t".$assembly_name_accession_pairs."\t".$response->code."\t" .$response->content."\n";

    my $flag_success=0;

    for(my $i=1; $i<=10; $i++) {

      $return_string = "\t".$return_string. $i .") Retrying attempt: Retrying after 5s...\n";
      sleep 5;
      $response = $ua->request($request);
      $response_code= $response->code;
      if($response_code == 201){
        $flag_success =1 ;
         $return_string = $return_string. "	..$hub_name is Registered\n";
        last;
      }

    }

    if($flag_success ==0){
     
      print STDERR $hub_name."\t".$assembly_name_accession_pairs."\t".$response->code."\t". $response->content."\n\n";
    }

  } else {
    $return_string = "Took a funny respose code: ".$response->code."\n";
    print STDERR "\nERROR: register_track_hub in Registry module ";
    print STDERR "$assembly_name_accession_pairs , ";
    print STDERR  $hub_name."\t".$response->code."\t". $response->content."\n";
    print STDERR "\n";
  } 
  return $return_string;
}

sub delete_track_hub{

  my $self = shift;
  my $track_hub_id = shift;

  my $ua = LWP::UserAgent->new;

  my $auth_token = eval { $self->{auth_token} };

  my @trackhubs;
  my $url = $server . '/api/trackhub';

  $url .= "/$track_hub_id" if $track_hub_id ne 'all';

  my $request = GET($url);
  $request->headers->header(user => $self->{username});
  $request->headers->header(auth_token => $auth_token);
  my $response = $ua->request($request);
  my $response_code= $response->code;

  if($response_code == 200) {
    if ($track_hub_id eq 'all') {
      map { push @trackhubs, $_ } @{from_json($response->content)};
    } else {
      push @trackhubs, from_json($response->content);
    }
  } else { 
    printf STDERR "Couldn't get trackhub(s) %s from the Registry: response code " . $response->code . " and response content ".$response->content . " in script " .__FILE__. " line " .__LINE__."\n", ($track_hub_id ne 'all')?$track_hub_id:'';
  }

  my $counter_of_deleted=0;

  foreach my $track_hub (@trackhubs) {

    $counter_of_deleted++;
    print "$counter_of_deleted.\tDeleting trackhub ". $track_hub->{name}."\t";
    $request = DELETE("$url/" . $track_hub->{name});
    $request->headers->header(user => $self->{username});
    $request->headers->header(auth_token => $auth_token);
    my $response = $ua->request($request);
    my $response_code= $response->code;
    if ($response->code != 200) {
      $counter_of_deleted--;
      print "..Error- couldn't be deleted - check STDERR.\n";
      printf STDERR "\n\tCouldn't delete track hub from THR : " . $track_hub->{name} . " with assemblies " . join(", ", map { $_->{assembly} } @{$track_hub->{trackdbs}}) . "\t"." response code ".$response->code . " and response content ".$response->content." in script " .__FILE__. " line " .__LINE__."\n";
    } else {
      print "..Done\n";
    }
  }
}

sub registry_login {

  my $user = shift;
  my $pass = shift;
  
  defined $server and defined $user and defined $pass
    or die "Some required parameters are missing when trying to login in the Track Hub Registry\n";
  
  my $ua = LWP::UserAgent->new;
  my $endpoint = '/api/login';
  my $url = $server.$endpoint; 

  my $request = GET($url);
  $request->headers->authorization_basic($user, $pass);

  my $response = $ua->request($request);
  my $auth_token;

  if ($response->is_success) {
    $auth_token = from_json($response->content)->{auth_token};
  } else {
    die "Unable to login to Registry, reason: " .$response->code ." , ". $response->content."\n";
  }
  
  defined $auth_token or die "Undefined authentication token when trying to login in the Track Hub Registry\n";
  return $auth_token;

}

sub give_all_Registered_track_hub_names{

  my $self = shift;

  my $registry_user_name= $self->{username};
  my $registry_pwd = $self->{pwd};
  my %track_hub_names;

  my $auth_token = $self->{auth_token};#eval { registry_login($registry_user_name, $registry_pwd) };

  my $ua = LWP::UserAgent->new;
  my $request = GET("$server/api/trackhub");
  $request->headers->header(user => $registry_user_name);
  $request->headers->header(auth_token => $auth_token);
  my $response = $ua->request($request);

  my $response_code= $response->code;

  if($response_code == 200) {
    my $trackhubs = from_json($response->content);
    map { $track_hub_names{$_->{name}} = 1 } @{$trackhubs}; # it is same as : $track_hub_names{$trackhubs->[$i]{name}}=1; 

  }else{

    print "\tCouldn't get Registered track hubs with the first attempt when calling method give_all_Registered_track_hubs in script ".__FILE__."\n";
    print "Got error ".$response->code ." , ". $response->content."\n";
    my $flag_success=0;

    for(my $i=1; $i<=10; $i++) {

      print "\t".$i .") Retrying attempt: Retrying after 5s...\n";
      sleep 5;
      $response = $ua->request($request);
      if($response->is_success){
        $flag_success =1 ;
        my $trackhubs = from_json($response->content);
        map { $track_hub_names{$_->{name}} = 1 } @{$trackhubs};
        last;
      }
    }

    die "Couldn't get list of track hubs in the Registry when calling method give_all_Registered_track_hubs in script: ".__FILE__." line ".__LINE__."\n"
    unless $flag_success ==1;
  }

  #registry_logout($server, $registry_user_name, $auth_token);

  return \%track_hub_names;

}

sub get_Registry_hub_last_update {

  my $self = shift;
  my $name = shift;  # track hub name, ie study_id

  my $registry_user_name= $self->{username};
  my $registry_pwd = $self->{pwd};

  my $auth_token = $self->{auth_token};

  my $ua = LWP::UserAgent->new;  
  my $request = GET("$server/api/trackhub/$name");
  $request->headers->header(user       => $registry_user_name);
  $request->headers->header(auth_token => $auth_token);
  my $response = $ua->request($request);
  my $hub;

  if ($response->is_success) {
    $hub = from_json($response->content);
  } else {  

    print "\tCouldn't get Registered track hubs with the first attempt when calling method get_Registry_hub_last_update in script ".__FILE__."\n";
    my $flag_success=0;

    for(my $i=1; $i<=10; $i++) {

      print "\t".$i .") Retrying attempt: Retrying after 5s...\n";
      sleep 5;
      $response = $ua->request($request);
      if($response->is_success){
        $hub = from_json($response->content);
        $flag_success =1 ;
        last;
      }
    }

    die "Couldn't get list of track hubs in the Registry when calling method get_Registry_hub_last_update in script: ".__FILE__." line ".__LINE__."\n"
    unless $flag_success==1;
  }

  die "Couldn't find hub $name in the Registry to get the last update date when calling method get_Registry_hub_last_update in script: ".__FILE__." line ".__LINE__."\n" 
  unless $hub;

  my $last_update = -1;

  foreach my $trackdb (@{$hub->{trackdbs}}) {

    $request = GET($trackdb->{uri});
    $request->headers->header(user       => $registry_user_name);
    $request->headers->header(auth_token => $auth_token);
    $response = $ua->request($request);
    my $doc;
    if ($response->is_success) {
      $doc = from_json($response->content);
    } else {  
      die "\tCouldn't get trackdb at", $trackdb->{uri}." from study $name in the Registry when trying to get the last update date \n";
    }

    if (exists $doc->{updated}) {
      $last_update = $doc->{updated}
      if $last_update < $doc->{updated};
    } else {
      exists $doc->{created} or die "Trackdb does not have creation date in the Registry when trying to get the last update date of study $name\n";
      $last_update = $doc->{created}
      if $last_update < $doc->{created};
    }
  }

  die "Couldn't get date as expected: $last_update\n" unless $last_update =~ /^[1-9]\d+?$/;

  #registry_logout($server, $registry_user_name, $auth_token);

  return $last_update;
}

sub give_all_bioreps_of_study_from_Registry {

  my $self = shift;
  my $name = shift;  # track hub name, ie study_id

  my $registry_user_name= $self->{username};
  my $registry_pwd = $self->{pwd};
  
  my $auth_token = $self->{auth_token};

  my $ua = LWP::UserAgent->new;
  my $request = GET("$server/api/trackhub/$name");
  $request->headers->header(user       => $registry_user_name);
  $request->headers->header(auth_token => $auth_token);
  my $response = $ua->request($request);
  my $hub;

  if ($response->is_success) {

    $hub = from_json($response->content);

  } else {  

    print "\tCouldn't get Registered track hub $name with the first attempt when calling method give_all_runs_of_study_from_Registry in script ".__FILE__." reason " .$response->code ." , ". $response->content."\n";
    my $flag_success=0;

    for(my $i=1; $i<=10; $i++) {

      print "\t".$i .") Retrying attempt: Retrying after 5s...\n";
      sleep 5;
      $response = $ua->request($request);
      if($response->is_success){
        $hub = from_json($response->content);
        $flag_success =1 ;
        last;
      }
    }

    die "Couldn't get the track hub $name in the Registry when calling method give_all_runs_of_study_from_Registry in script: ".__FILE__." line ".__LINE__."\n"
    unless $flag_success==1;
  }

  die "Couldn't find hub $name in the Registry to get its runs when calling method give_all_runs_of_study_from_Registry in script: ".__FILE__." line ".__LINE__."\n" 
  unless $hub;

  my %runs ;

  foreach my $trackdb (@{$hub->{trackdbs}}) {

    $request = GET($trackdb->{uri});
    $request->headers->header(user       => $registry_user_name);
    $request->headers->header(auth_token => $auth_token);

    # my $request = registry_get_request();
    $response = $ua->request($request);
    my $doc;

    if ($response->is_success) {

      $doc = from_json($response->content);


      foreach my $sample (keys %{$doc->{configuration}}) {
	map { $runs{$_}++ } keys %{$doc->{configuration}{$sample}{members}}; 
      }
    } else {  
      die "Couldn't get trackdb at ", $trackdb->{uri} , " from study $name in the Registry when trying to get all its runs, reason: " .$response->code ." , ". $response->content."\n";
    }
  }

  #registry_logout($server, $registry_user_name, $auth_token);

  return \%runs;

}

sub registry_get_request {

  my $self = shift;
  my ($server, $endpoint, $user, $token) = @_;

  my $request = GET("$server$endpoint");
  $request->headers->header(user       => $user);
  $request->headers->header(auth_token => $token);
  
  return $request;
}

sub registry_logout {

  my $self = shift;
  my ($server, $user, $auth_token) = @_;
  defined $server and defined $user and defined $auth_token
    or die "Some required parameters are missing when trying to log out from the Track Hub Registry\n";
  
  my $ua = LWP::UserAgent->new;
  my $request = GET("$server/api/logout");
  $request->headers->header(user => $user);
  $request->headers->header(auth_token => $auth_token);
  my $response = $ua->request($request);

  if (!$response->is_success) {
    die "Couldn't log out from the registry\n";
  } 
  return;
}


1;