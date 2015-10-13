
# in this cript I connect to the trackHub Registry db and I register (upload) a track hub

  use strict ;
  use warnings;
  use Data::Dumper;

  use HTTP::Tiny;
  use Time::HiRes;
  use JSON;
  use MIME::Base64;
  use HTTP::Request::Common qw/GET DELETE/;
  use LWP::UserAgent;
  use Getopt::Long;

  my $ua = LWP::UserAgent->new;

# example call:
#perl trackHubRegistry.pl -username etapanari -password ensemblplants 

  my $username ;
  my $pwd ; # i pass the pwd when calling the pipeline, in the command line  # it is ensemblplants/ testing


  GetOptions(
     "username=s" => \$username ,
     "password=s" => \$pwd
  );


  my $server = "http://193.62.54.43:3000";
 
  my $endpoint = '/api/login';
  my $url = $server.$endpoint; 
  my $request = GET($url) ;

  $request->headers->authorization_basic($username, $pwd);
  # print Dumper $request;
  my $response = $ua->request($request);
  my $auth_token = from_json($response->content)->{auth_token};
  
  $url = $server . '/api/trackhub';
  $request = GET($url);
  $request->headers->header(user => $username);
  $request->headers->header(auth_token => $auth_token);
  $response = $ua->request($request);

  my $response_code= $response->code;
  my $counter_of_deleted=0;

  if($response_code == 200) {
    foreach my $trackhub (@{from_json($response->content)}) {

      printf "Got hub %s\n", $trackhub->{name};

      foreach my $trackdb (@{$trackhub->{trackdbs}}) {

        printf "TrackDb %s does not have an URI. Skipping...\n", $trackdb->{assembly} and next unless $trackdb->{uri};
        printf "\tDeleting %s trackdb...", $trackdb->{assembly};
        $request = DELETE($trackdb->{uri});
        $request->headers->header(user => $username);
        $request->headers->header(auth_token => $auth_token);
        $response = $ua->request($request);
        $counter_of_deleted++ if $response->code == 200;
        print "Done (deleted $counter_of_deleted track hubs so far)\n" and next if $response->code == 200;
        printf "Couldn't delete %s: %d\n", $trackdb->{assembly}, $response->code;
      }
    }
    
  } else {
    print STDERR "delete_registered_trackhubs.pl ERRPR : Couldn't get list of trackhubs: %d", $response->{code};
  }