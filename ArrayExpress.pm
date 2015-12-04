package ArrayExpress;


use strict ;
use warnings;
use HTTP::Tiny;
use JSON;

my $server_array_express =  "http://plantain:3000/eg"; 
my $http = HTTP::Tiny->new();

sub getPlantNamesArrayExpressAPI {  # returns reference to a hash

  my $get_plant_names_url= $server_array_express . "/getOrganisms/plants" ; # i get all organism names that robert uses for plants to date

  my %robert_plant_names;

#response:
#[{"ORGANISM":"arabidopsis_thaliana"},{"ORGANISM":"brassica_rapa"},{"ORGANISM":"hordeum_vulgare"},{"ORGANISM":"hordeum_vulgare_subsp._vulgare"},
#{"ORGANISM":"medicago_truncatula"},{"ORGANISM":"oryza_sativa"},{"ORGANISM":"oryza_sativa_japonica_group"},{"ORGANISM":"physcomitrella_patens"},
#{"ORGANISM":"populus_trichocarpa"},{"ORGANISM":"sorghum_bicolor"},{"ORGANISM":"triticum_aestivum"},{"ORGANISM":"vitis_vinifera"},{"ORGANISM":"zea_mays"}]

  my @plant_names_response = @{getJsonResponse($get_plant_names_url)};  # i call here the method that I made above

  foreach my $hash_ref (@plant_names_response){

    my %hash = %{$hash_ref};

    $robert_plant_names{ $hash{"ORGANISM"} }=1;  # this hash has all possible names of plants that Robert is using in his REST calls ; I get them from here: http://plantain:3000/eg/getOrganisms/plants
        
  }

  return \%robert_plant_names;

}

sub getJsonResponse { # it returns the json response given the endpoint as param, it returns an array reference that contains hash references . If response not successful it returns 0

  my $url = shift; # example: "http://plantain:3000/eg/getLibrariesByStudyId/SRP033494";

  my $response = $http->get($url);

  if($response->{success} ==1) { # if the response is successful then I get 1

    my $content=$response->{content};     
    my $json = decode_json($content); # it returns an array reference 

    return $json;

  }else{

    my ($status, $reason) = ($response->{status}, $response->{reason}); #LWP perl library for dealing with http
    print STDERR "ERROR in: ".__FILE__." line: ".__LINE__ ."Failed for $url! Status code: ${status}. Reason: ${reason}\n";  # if response is successful I get status "200", reason "OK"
    return 0;
  }

}

