package ArrayExpress;

use strict ;
use warnings;

use JsonResponse;

my $array_express_url =  "http://plantain:3000/json/70";   # Robert's server where he stores his REST URLs

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
      $plant_names{ $hash_ref->{"ORGANISM"} }=1;  # this hash has all possible names of plants that Robert is using in his REST calls ; I get them from here: http://plantain:3000/json/70/getOrganisms/plants        
    }

    return \%plant_names;
  }
}


sub get_runs_json_for_study { # returns json string or 0 if url not valid
  
  my $study_id = shift;
  my $url = $array_express_url . "/getRunsByStudyId/$study_id";

  return JsonResponse::get_Json_response( $url);

}

sub get_completed_study_ids_for_plants{ # I want this method to return only studies with status "Complete"

  my $plant_names_href = shift;

  my $url;
  my %study_ids;
  my $get_runs_by_organism_endpoint="http://plantain:3000/json/70/getRunsByOrganism/"; # gets all the bioreps by organism to date that AE has processed so far

  foreach my $plant_name (keys %{$plant_names_href}){

    $url = $get_runs_by_organism_endpoint . $plant_name;
    my $json_response = JsonResponse::get_Json_response( $url);

    if(!$json_response){ # if response is 0

      return 0 and die "Json response unsuccessful for plant $plant_name\n";

    }else{
      my @biorep_stanza_json = @{$json_response};

      foreach my $hash_ref (@biorep_stanza_json){
        if($hash_ref->{"STATUS"} eq "Complete" ){
          $study_ids{ $hash_ref->{"STUDY_ID"} }=1; 
        } 
      }
    }
  }

  
  return \%study_ids;
}

1;