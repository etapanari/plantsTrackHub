
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
#perl trackHubRegistry.pl etapanari ensemblplants http://www.ebi.ac.uk/~tapanari/data/test/SRP036860/hub.txt SRP036860 JGI2.0,GCA_000002775.2

  my $username ;
  my $pwd ;  # i pass the pwd when calling the pipeline, in the command line  # it is ensemblplants
  my $trackHub_txt_file_url ;
  my $hub_name ;
  my $assembly_name_accession_pairs ;

 

  GetOptions(
     "username=s" => \$username,
     "password=s" => \$pwd,
     "hub_txt_file_location=s" => \$trackHub_txt_file_url,
     "hub_name=s" => \$hub_name,
     "assembly_name_accession_pairs=s" => \$assembly_name_accession_pairs
  );


  my $server = "http://193.62.54.43:3000";
 
  my $endpoint = '/api/login';
  my $url = $server.$endpoint; 
  my $request = GET($url) ;

  $request->headers->authorization_basic($username , $pwd);
  # print Dumper $request;
  my $response = $ua->request($request);

  my $auth_token = from_json($response->content)->{auth_token};
  
  $url = $server . '/api/trackhub';

  my $eg_server = "http://rest.ensemblgenomes.org";
  my $endpoint_eg_assembly_accession = "/info/assembly/populus_trichocarpa?content-type=application/json"; 

  #my $assembly_name_accession_pairs=  "ASM242v1,GCA_000002425.1,IRGSP-1.0,GCA_000005425.2";
  my @words = split(/,/, $assembly_name_accession_pairs);
  my $assemblies;
  for(my $i=0; $i<$#words; $i+=2) {
    $assemblies->{$words[$i]} = $words[$i+1];
  }

  $request = POST($url,
		  'Content-type' => 'application/json',
		                                                                         #  assemblies => { "$assembly_name" => "$assembly_accession" } }));
		  'Content' => to_json({ url => $trackHub_txt_file_url, type => 'transcriptomics', assemblies => $assemblies }));
  $request->headers->header(user => $username);
  $request->headers->header(auth_token => $auth_token);

  $response = $ua->request($request);

  my $response_code= $response->code;

  if($response_code == 201) {

    print $hub_name ." is Registered\n";

  } elsif($response_code == 503 or $response_code == 500) {

     for(my $i=0; $i<10; $i++) {
       printf "\n%s\t%d\t%s. $i retrying attempt: Retrying after 5s...", $hub_name, $response->code, from_json($response->content)->{error};
       sleep 5;
       $response = $ua->request($request);
       $response_code= $response->code;
       print "$hub_name is Registered\n" and last if $response_code == 201;
       printf STDERR "%s\t%d\t%s\n", $hub_name, $response->code, from_json($response->content)->{error} and last if $response_code < 500;
       print "\n";
     }
  } else {
    print STDERR "trackHubRegistry.pl script gave an ERROR: ";
    print STDERR "$assembly_name_accession_pairs , ";
    printf STDERR "%s\t%d\t%s\n", $hub_name, $response->code, from_json($response->content)->{error};
  } 


  