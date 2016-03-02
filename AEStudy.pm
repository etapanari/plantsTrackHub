package AEStudy;

use strict;
use warnings;
use Date::Manip;
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

    die "Could not get plant names from AE REST call /getOrganisms/plants in AEStudy module\n";

  }else{

    %plant_names_AE = %{$plant_names_response};  # gives all distinct plant names with processed runs by ENA
  }

  my $runs_response = ArrayExpress::get_runs_json_for_study($study_id);
  my @runs_json; # returns list of hash references

  if ($runs_response ==0){

    die "Could not get runs for study $study_id using AE REST call /getRunsByStudy/$study_id in AEStudy module\n";

  }else{

    @runs_json = @{$runs_response};
  }

# a response stanza (the response is usually more than 1 stanza, 1 study has many bioreps, each stanza is a biorep) of this call:  http://plantain:3000/json/70/getRunsByStudy/SRP033494
#[{"STUDY_ID":"SRP033494","SAMPLE_IDS":"SAMN02434874","BIOREP_ID":"SRR1042754","RUN_IDS":"SRR1042754","ORGANISM":"arabidopsis_thaliana","REFERENCE_ORGANISM":"arabidopsis_thaliana","STATUS":"Complete",
#"ASSEMBLY_USED":"TAIR10","ENA_LAST_UPDATED":"Fri Jun 19 2015 18:11:03","LAST_PROCESSED_DATE":"Sun Nov 15 2015 00:31:20",
#"FTP_LOCATION":"ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/SRR104/004/SRR1042754/SRR1042754.cram"},

# or with merges of CRAMs

#[{"STUDY_ID":"SRP021098","SAMPLE_IDS":"SAMN02799120","BIOREP_ID":"E-MTAB-4045.biorep54","RUN_IDS":"SRR1298603,SRR1298604","ORGANISM":"glycine_max","REFERENCE_ORGANISM":"glycine_max",
#"STATUS":"Complete","ASSEMBLY_USED":"V1.0","ENA_LAST_UPDATED":"Fri Jun 19 2015 18:53:48","LAST_PROCESSED_DATE":"Mon Jan 25 2016 16:46:04",
#"FTP_LOCATION":"ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/aggregated_techreps/E-MTAB-4045/E-MTAB-4045.biorep54.cram","MAPPING_QUALITY":77},

  foreach my $run_stanza (@runs_json){
    
    if($run_stanza->{"STATUS"} eq "Complete" and $plant_names_AE{$run_stanza->{"ORGANISM"}}){

      $run_tuple{$run_stanza->{"BIOREP_ID"}}{"sample_ids"}=$run_stanza->{"SAMPLE_IDS"}; # ie $run{"SRR1042754"}{"sample_ids"}="SAMN02434874,SAMN02434875"
      $run_tuple{$run_stanza->{"BIOREP_ID"}}{"organism"}=$run_stanza->{"REFERENCE_ORGANISM"};
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

sub get_biorep_ids_by_organism{

  my $self = shift;
  my $organism_name = shift;
  my $run_tuple = $self->{run_tuple};
  my %biorep_ids;

  foreach my $biorep_id (keys %{$run_tuple}){
    
    if ($run_tuple->{$biorep_id}{"organism"} eq $organism_name){
      $biorep_ids {$biorep_id} = 1; 
    }    
  }

  return \%biorep_ids;
}

sub get_organism_names_assembly_names{

  my $self = shift;
  my $run_tuple = $self->{run_tuple};
  my %organism_names;
  my $organism_name;

  foreach my $biorep_id (keys %{$run_tuple}){
    
    $organism_name = $run_tuple->{$biorep_id}{"organism"};
    $organism_names {$organism_name} = $run_tuple->{$biorep_id}{"assembly_name"}; 
    
  }

  return \%organism_names;

}

sub get_sample_ids{

  my $self = shift;
  my $run_tuple = $self->{run_tuple};
  my %sample_ids;

  my %biorep_ids = %{$self->get_biorep_ids};

  foreach my $biorep_id (keys %biorep_ids){
   
    my $sample_ids_string = $run_tuple->{$biorep_id} {"sample_ids"};
    my @sample_ids_from_string = split (/,/ , $sample_ids_string);

    foreach my $sample_id (@sample_ids_from_string){
      $sample_ids{$sample_id} = 1;
    }
  }

  return \%sample_ids;
}

sub get_assembly_name_from_biorep_id{

  my $self=shift;
  my $biorep_id = shift;
  my $run_tuple = $self->{run_tuple};
    
  my $assembly_name= $run_tuple->{$biorep_id}{"assembly_name"};
  $assembly_name = EG::get_right_assembly_name( $assembly_name);
  return $assembly_name;
}

sub get_sample_ids_from_biorep_id{

  my $self = shift;
  my $biorep_id = shift;
  my $run_tuple = $self->{run_tuple};
   
  my @sample_ids= split (/,/,$run_tuple->{$biorep_id}{"sample_ids"});
  
  return \@sample_ids;
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

    my @sample_ids= split (/,/,$run_tuple->{$biorep_id}{"sample_ids"});  # could be "SAMPLE_IDS":"SAMN02666905,SAMN02666906"

    foreach my $sample_id_from_string (@sample_ids){

      if($sample_id_from_string eq $sample_id){  

       $biorep_ids{$biorep_id} = 1;
     }
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

sub get_AE_last_processed_unix_date{  # of the study : i get all its bioreps and then find the max date of all bioreps # tried with this study: http://plantain:3000/json/70/getRunsByStudy/SRP067728

  my $self= shift;
  my %biorep_ids = %{$self->get_biorep_ids};
  my $max_date=0;

  foreach my $biorep_id (keys %biorep_ids){  
  #each study has more than 1 processed date, as there are usually multiple bioreps in each study with different processed date each. I want to get the most current date

    my $date=$self->get_AE_last_processed_date_from_biorep_id($biorep_id);
    my $unix_time = UnixDate( ParseDate($date), "%s" );

    if($unix_time > $max_date){
      $max_date = $unix_time ;
    }
  }

  return $max_date;

}

1;