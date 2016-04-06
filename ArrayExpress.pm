package ArrayExpress;

use strict ;
use warnings;

use JsonResponse;

my $array_express_url =  "http://plantain:3000/json/70";   # Robert's server where he stores his REST URLs

sub get_plant_names_AE_API {  # returns reference to a hash

  my $url = $array_express_url . "/getOrganisms/plants" ; # gives all distinct plant names with processed runs by ENA

  my %plant_names;

#response:
#[{"ORGANISM":"aegilops_tauschii","REFERENCE_ORGANISM":"aegilops_tauschii"},{"ORGANISM":"amborella_trichopoda","REFERENCE_ORGANISM":"amborella_trichopoda"},
#{"ORGANISM":"arabidopsis_kamchatica","REFERENCE_ORGANISM":"arabidopsis_lyrata"},{"ORGANISM":"arabidopsis_lyrata","REFERENCE_ORGANISM":"arabidopsis_lyrata"},
#{"ORGANISM":"arabidopsis_lyrata_subsp._lyrata","REFERENCE_ORGANISM":"arabidopsis_lyrata"},{"ORGANISM":"arabidopsis_thaliana","REFERENCE_ORGANISM":"arabidopsis_thaliana"},

  my $json_response = JsonResponse::get_Json_response($url); 
  
  if(!$json_response){ # if response is 0

    return 0;

  }else{

    my @plant_names_json = @{$json_response}; # json response is a ref to an array that has hash refs

    foreach my $hash_ref (@plant_names_json){
      $plant_names{ $hash_ref->{"REFERENCE_ORGANISM"} }=1;  # this hash has all possible names of plants that Robert is using in his REST calls ; I get them from here: http://plantain:3000/json/70/getOrganisms/plants        
    }

    return \%plant_names;
  }
}


sub get_runs_json_for_study { # returns json string or 0 if url not valid
  
  my $study_id = shift;
  my $url = $array_express_url . "/getRunsByStudy/$study_id";  # get an error here , $study_id is empty

  return JsonResponse::get_Json_response( $url);

}

sub get_completed_study_ids_for_plants{ # I want this method to return only studies with status "Complete"

  my $plant_names_href_EG = shift;

  my $url;
  my %study_ids;
  my $get_runs_by_organism_endpoint="http://plantain:3000/json/70/getRunsByOrganism/"; # gets all the bioreps by organism to date that AE has processed so far

  foreach my $plant_name (keys %{$plant_names_href_EG}){

    $url = $get_runs_by_organism_endpoint . $plant_name;
    my $json_response = JsonResponse::get_Json_response( $url);

    if(!$json_response){ # if response is 0

      die "Json response unsuccessful for plant $plant_name\n";

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

sub get_study_ids_for_plant{

  my $plant_name = shift;
  my $url= $array_express_url."/getRunsByOrganism/" . $plant_name;
  
  my %study_ids;
#response:
#[{"STUDY_ID":"DRP000315","SAMPLE_IDS":"SAMD00009892","BIOREP_ID":"DRR000749","RUN_IDS":"DRR000749","ORGANISM":"oryza_sativa_japonica_group","REFERENCE_ORGANISM":"oryza_sativa","STATUS":"Complete","ASSEMBLY_USED":"IRGSP-1.0","ENA_LAST_UPDATED":"Fri Jun 19 2015 17:39:45","LAST_PROCESSED_DATE":"Mon Sep 07 2015 00:39:36","FTP_LOCATION":"ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/DRR000/DRR000749/DRR000749.cram","MAPPING_QUALITY":70},
  my $json_response = JsonResponse::get_Json_response($url); 
  
  if(!$json_response){ # if response is 0

    return 0;

  }else{

    my @plant_names_json = @{$json_response}; # json response is a ref to an array that has hash refs

    foreach my $hash_ref (@plant_names_json){
      if($hash_ref->{"STATUS"} eq "Complete"){
        $study_ids{ $hash_ref->{"STUDY_ID"} }=1;  # this hash has all possible names of plants that Robert is using in his REST calls ; I get them from here: http://plantain:3000/json/70/getOrganisms/plants        
      }
    }

    return \%study_ids;

  }
}

1;