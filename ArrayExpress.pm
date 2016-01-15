package ArrayExpress;

use strict ;
use warnings;
use HTTP::Tiny;
use JSON;
use JsonResponse;

my $array_express_url =  "http://plantain:3000/eg"; 
my $http = HTTP::Tiny->new();


sub get_plant_names_AE_API {  # returns reference to a hash

  my $get_plant_names_url= $array_express_url . "/getOrganisms/plants" ; # i get all organism names that robert uses for plants to date

  my %plant_names;

#response:
#[{"ORGANISM":"arabidopsis_thaliana"},{"ORGANISM":"brassica_rapa"},{"ORGANISM":"hordeum_vulgare"},{"ORGANISM":"hordeum_vulgare_subsp._vulgare"},
#{"ORGANISM":"medicago_truncatula"},{"ORGANISM":"oryza_sativa"},{"ORGANISM":"oryza_sativa_japonica_group"},{"ORGANISM":"physcomitrella_patens"},
#{"ORGANISM":"populus_trichocarpa"},{"ORGANISM":"sorghum_bicolor"},{"ORGANISM":"triticum_aestivum"},{"ORGANISM":"vitis_vinifera"},{"ORGANISM":"zea_mays"}]

  my @plant_names_response = @{JsonResponse::getJsonResponse($get_plant_names_url)}; 

  foreach my $hash_ref (@plant_names_response){

    my %hash = %{$hash_ref};

    $plant_names{ $hash{"ORGANISM"} }=1;  # this hash has all possible names of plants that Robert is using in his REST calls ; I get them from here: http://plantain:3000/eg/getOrganisms/plants
        
  }

  return \%plant_names;

}


1