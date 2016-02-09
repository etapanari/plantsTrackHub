package AEStudy;

use strict;
use warnings;
use EG;
use ArrayExpress;

## this is a class of an AE study. It considers only PLANT species.

sub new {

    my $class = shift;
    my $study_id = shift;

    my $self = {
      study_id => $study_id,
    };

    my $run_tuple_of_study_ref =  make_runs_tuple_plants_of_study($study_id);
    $self->{run_tuple} = $run_tuple_of_study_ref;

    return bless $self, $class; #this is what makes a reference into an object
}

sub make_runs_tuple_plants_of_study {  

  my $study_id = shift;
  my %run_tuple; # to be returned

  my $plant_names_response = ArrayExpress::get_plant_names_AE_API();
  my %plant_names_AE;

  if ($plant_names_response ==0){

    die "Could not get plant names from AE REST call /getOrganisms/plants\n";

  }else{

    %plant_names_AE = %{$plant_names_response};  # gives all distinct plant names with processed runs by ENA
  }

  my $runs_response = ArrayExpress::get_runs_json_for_study($study_id);
  my @runs_json; # returns list of hash references

  if ($runs_response ==0){

    die "Could not get runs for study $study_id using AE REST call /getLibrariesByStudyId/$study_id \n";

  }else{

    @runs_json = @{$runs_response};
  }

# a response stanza (the response is usually more than 1 stanza, 1 study has many bioreps, each stanza is a biorep) of this call:  http://plantain:3000/eg/getLibrariesByStudyId/SRP033494
#[{"STUDY_ID":"DRP000315","SAMPLE_ID":"SAMD00009892","BIOREP_ID":"DRR000745","RUN_IDS":"DRR000745","ORGANISM":"oryza_sativa_japonica_group",
#"STATUS":"Complete","ASSEMBLY_USED":"IRGSP-1.0","ENA_LAST_UPDATED":"Fri Jun 19 2015 17:39:45",
#"LAST_PROCESSED_DATE":"Sun Sep 06 2015 02:44:34","FTP_LOCATION":"ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/DRR000/DRR000745/DRR000745.cram"},

  foreach my $run_stanza (@runs_json){
    
    if($run_stanza->{"STATUS"} eq "Complete" and $plant_names_AE{$run_stanza->{"ORGANISM"}}){

      $run_tuple{$run_stanza->{"BIOREP_ID"}}{"sample_id"}=$run_stanza->{"SAMPLE_ID"}; # ie $run{"SRR1042754"}{"sample_id"}="SRS1046581"
      $run_tuple{$run_stanza->{"BIOREP_ID"}}{"organism"}=$run_stanza->{"ORGANISM"};
      $run_tuple{$run_stanza->{"BIOREP_ID"}}{"assembly_name"}=$run_stanza->{"ASSEMBLY_USED"};  #ie "TAIR10"
      $run_tuple{$run_stanza->{"BIOREP_ID"}}{"big_data_file_server_location"}=$run_stanza->{"FTP_LOCATION"};
      $run_tuple{$run_stanza->{"BIOREP_ID"}}{"AE_processed_date"}=$run_stanza->{"LAST_PROCESSED_DATE"};
      $run_tuple{$run_stanza->{"BIOREP_ID"}}{"run_ids"}=$run_stanza->{"RUN_IDS"};
 
    }
  }
  return \%run_tuple;
  
}


sub id{

  my $self = shift;
  return $self->{study_id};
}

sub get_sample_ids{

  my $self = shift;
  my $run_tuple = $self->{run_tuple};
  my %sample_ids;

  my %biorep_ids = %{$self->get_biorep_ids};

  foreach my $biorep_id (keys %biorep_ids){

    $sample_ids{$run_tuple->{$biorep_id} {"sample_id"}} = 1;
  }

  return \%sample_ids;
}

sub get_assembly_name_from_biorep_id{

  my $self=shift;
  my $biorep_id = shift;
  my $run_tuple = $self->{run_tuple};
    
  return $run_tuple->{$biorep_id}{"assembly_name"};

}

sub get_sample_id_from_biorep_id{

  my $self = shift;
  my $biorep_id = shift;
  my $run_tuple = $self->{run_tuple};
   
  return $run_tuple->{$biorep_id}{"sample_id"};
  
}

sub get_biorep_ids{

  my $self=shift;
  my $run_tuple = $self->{run_tuple};

  my %biorep_ids;

  foreach my $biorep_id (keys %{$run_tuple}){
    $biorep_ids{$biorep_id}=1;
  }

  return \%biorep_ids;
}

sub get_biorep_ids_from_sample_id{

  my $self=shift;
  my $sample_id = shift;
  my $run_tuple = $self->{run_tuple};

  my %biorep_ids;

  foreach my $biorep_id (keys %{$run_tuple}){

    if($run_tuple->{$biorep_id}{"sample_id"} eq $sample_id){  #error

     $biorep_ids{$biorep_id} = 1;
   }

  }

  return \%biorep_ids;
}

sub get_assembly_names{

  my $self=shift;
  my $run_tuple = $self->{run_tuple};

  my %assembly_names;

  foreach my $biorep_id (keys %{$run_tuple}){
    
    my $assembly_name = $run_tuple->{$biorep_id}{"assembly_name"};
    $assembly_name = EG::get_right_assembly_name( $assembly_name);
    $assembly_names {$assembly_name} = 1;
    
  }

  return \%assembly_names;
}

sub get_big_data_file_location_from_biorep_id {

  my $self=shift;
  my $biorep_id = shift;
  my $run_tuple = $self->{run_tuple};
    
  return $run_tuple->{$biorep_id}{"big_data_file_server_location"};

}

sub get_AE_last_processed_date_from_biorep_id {

  my $self=shift;
  my $biorep_id = shift;
  my $run_tuple = $self->{run_tuple};
    
  return $run_tuple->{$biorep_id}{"AE_processed_date"};

}

sub get_run_ids_of_biorep_id{  # could be more than 1 run id : "RUN_IDS":"DRR001028,DRR001035,DRR001042,DRR001049",

  my $self=shift;
  my $biorep_id = shift;
  my $run_tuple = $self->{run_tuple};

  my $run_string = $run_tuple->{$biorep_id}{"run_ids"};
 
  my @run_ids = split(/,/,$run_string);

  return \@run_ids;
}


sub give_big_data_file_type_of_biorep_id{

  my $self=shift;
  my $biorep_id = shift;
 
  my $server_location = $self->get_big_data_file_location_from_biorep_id($biorep_id);   #ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/DRR000/DRR000745/DRR000745.cram
  # or ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/aggregated_techreps/E-MTAB-2037/E-MTAB-2037.biorep4.cram
  $server_location =~ /.+\/.+\.(.+)$/;

  return $1; # ie cram

}

1;
