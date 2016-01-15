
# in this cript I connect to the trackHub Registry db and I register (upload) a track hub
# i have 2 accounts : 1. user :etapanari , pwd : ensemblplants 2. user:tapanari , pwd : testing
use strict ;
use warnings;
use Data::Dumper;

use HTTP::Tiny;
use Time::HiRes;
use JSON;
use MIME::Base64;
use HTTP::Request::Common;
use LWP::UserAgent;
use Getopt::Long;


my $ua = LWP::UserAgent->new;

# example call:
#  perl register_track_hub.pl -username tapanari -password testing -hub_txt_file_location ftp://ftp.ensemblgenomes.org/pub/misc_data/.TrackHubs/SRP050323/hub.txt -assembly_name_accession_pairs IWGSC1.0+popseq,0000

my $username ;
my $pwd ;  # i pass the pwd when calling the pipeline, in the command line  # it is ensemblplants
my $trackHub_txt_file_url ;
my $assembly_name_accession_pairs ;

 
GetOptions(
  "username=s" => \$username,
  "password=s" => \$pwd,
  "hub_txt_file_location=s" => \$trackHub_txt_file_url,
  "assembly_name_accession_pairs=s" => \$assembly_name_accession_pairs
);

my $server = "http://193.62.54.43:5000";
$trackHub_txt_file_url =~ /.+\/(\w+)\/hub\.txt/ ;
my $hub_name = $1;


my $auth_token = eval { registry_login($server, $username, $pwd) };
if ($@) {
  print STDERR "Couldn't login, cannot register track hub $hub_name: $@\n";
  die;
}
my $url = $server . '/api/trackhub';

  #my $assembly_name_accession_pairs=  "ASM242v1,GCA_000002425.1,IRGSP-1.0,GCA_000005425.2";
my @words = split(/,/, $assembly_name_accession_pairs);
my $assemblies;
for(my $i=0; $i<$#words; $i+=2) {
  $assemblies->{$words[$i]} = $words[$i+1];
}

$| = 1;  # it flashes the output

my $request = 
  POST($url,'Content-type' => 'application/json',
	 #  assemblies => { "$assembly_name" => "$assembly_accession" } }));
    'Content' => to_json({ url => $trackHub_txt_file_url, type => 'transcriptomics', assemblies => $assemblies }));
$request->headers->header(user => $username);
$request->headers->header(auth_token => $auth_token);
my $response = $ua->request($request);

my $response_code= $response->code;

if($response_code == 201) {

  print "	..$hub_name is Registered\n";

}elsif($response_code == 503 or $response_code == 500 or $response_code == 400){ #and $response->content=~/server response timed out/)) {

  print "Couldn't register track hub with the first attempt: " .$hub_name."\t".$assembly_name_accession_pairs."\t".$response->code."\t" .$response->content."\n";

  my $flag_success=0;

  for(my $i=1; $i<=10; $i++) {

    print $i .".Retrying attempt: Retrying after 5s...\n";
    sleep 5;
    $response = $ua->request($request);
    $response_code= $response->code;
    if($response_code == 201){
      $flag_success =1 ;
      print "	..$hub_name is Registered\n";
      last;
    }

  }

  if($flag_success ==0){
     
    print STDERR $hub_name."\t".$assembly_name_accession_pairs."\t".$response->code."\t". $response->content."\n\n";
  }

  } else {
    print STDERR "\nERROR: register_track_hub.pl ";
    print STDERR "$assembly_name_accession_pairs , ";
    print STDERR  $hub_name."\t".$response->code."\t". $response->content."\n";
    print STDERR "\n";
  } 


sub registry_login {

  my ($server, $user, $pass) = @_;
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