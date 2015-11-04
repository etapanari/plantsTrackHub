
# in this cript I connect to the trackHub Registry db and I delete the given study_id under the given track hub Registry account

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
#perl delete_registered_trackhubs.pl -username tapanari -password testing -study_id SRP002106

  my $username ;  # it is etapanari / tapanari
  my $pwd ; # i pass the pwd when calling the pipeline, in the command line  # it is ensemblplants/ testing
  my $study_id;


  GetOptions(
     "username=s" => \$username ,
     "password=s" => \$pwd,
     "study_id=s" => \$study_id
  );


  my $server = "http://193.62.54.43:3000";
 
  my $endpoint = '/api/login';
  my $url = $server.$endpoint; 
  my $request = GET($url) ;

  $request->headers->authorization_basic($username, $pwd);
  my $response = $ua->request($request);
  my $auth_token = from_json($response->content)->{auth_token};
  
  $url = $server . '/api/trackhub/';
  $request = GET($url);
  $request->headers->header(user => $username);
  $request->headers->header(auth_token => $auth_token);
  $response = $ua->request($request);

  my $response_code= $response->code;
  my $counter_of_deleted=0;


  if($response_code == 200) {

    foreach my $trackhub (@{from_json($response->content)}) {

      if($study_id ne "all"){
         next unless $trackhub->{name} eq $study_id;
      }
      printf "Got hub %s\n", $trackhub->{name};

      foreach my $trackdb (@{$trackhub->{trackdbs}}) {

        printf STDERR "TrackDb %s does not have an URI. Skipping...\n", $trackdb->{assembly} and next unless $trackdb->{uri};
        printf "\tDeleting %s trackdb...", $trackdb->{assembly};
        $request = DELETE($trackdb->{uri});
        $request->headers->header(user => $username);
        $request->headers->header(auth_token => $auth_token);
        $response = $ua->request($request);
        $counter_of_deleted++ if $response->code == 200;
        print "Done (deleted $counter_of_deleted track hubs so far)\n" and next if $response->code == 200;
        printf STDERR "Couldn't delete %s: %d\n", $trackdb->{assembly}, $response->code;
      }
    }
    
  } else {
    print STDERR "delete_registered_trackhubs.pl ERROR : Couldn't get list of trackhubs: %d", $response->{code};
  }