package ArrayExpress;

use strict ;
use warnings;

use JsonResponse;

my $array_express_url =  "http://plantain:3000/eg";   # Robert's server where he stores his REST URLs

sub get_plant_names_AE_API {  # returns reference to a hash

  my $url = $array_express_url . "/getOrganisms/plants" ; # gives all distinct plant names with processed runs by ENA

  my %plant_names;

#response:
#[{"ORGANISM":"arabidopsis_thaliana"},{"ORGANISM":"brassica_rapa"},{"ORGANISM":"hordeum_vulgare"},{"ORGANISM":"hordeum_vulgare_subsp._vulgare"},
#{"ORGANISM":"medicago_truncatula"},{"ORGANISM":"oryza_sativa"},{"ORGANISM":"oryza_sativa_japonica_group"},{"ORGANISM":"physcomitrella_patens"},
#{"ORGANISM":"populus_trichocarpa"},{"ORGANISM":"sorghum_bicolor"},{"ORGANISM":"triticum_aestivum"},{"ORGANISM":"vitis_vinifera"},{"ORGANISM":"zea_mays"}]

  my $json_response = JsonResponse::get_Json_response($url); 
  
  if(!$json_response){ # if response is 0

    return 0;

  }else{

    my @plant_names_json = @{$json_response};

    foreach my $hash_ref (@plant_names_json){

      my %hash = %{$hash_ref};

      $plant_names{ $hash{"ORGANISM"} }=1;  # this hash has all possible names of plants that Robert is using in his REST calls ; I get them from here: http://plantain:3000/eg/getOrganisms/plants
        
    }

    return \%plant_names;
  }
}


sub get_runs_json_for_study { # returns json string or 0 if url not valid
  
  my $study_id = shift;
  my $url = $array_express_url . "/getLibrariesByStudyId/$study_id";

  return JsonResponse::get_Json_response( $url);

}

1;