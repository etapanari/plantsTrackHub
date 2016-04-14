# example run:

# perl pipeline_create_register_track_hubs.pl -THR_username etapanari -THR_password testing -server_dir_full_path /nfs/ensemblgenomes/ftp/pub/misc_data/Track_Hubs -server_url ftp://ftp.ensemblgenomes.org/pub/misc_data/Track_Hubs  1> output_wh_23Feb 2>errors_wh_23Feb
# perl pipeline_create_register_track_hubs.pl -THR_username etapanari -THR_password testing -server_dir_full_path /nfs/ensemblgenomes/ftp/pub/misc_data/Track_Hubs -server_url ftp://ftp.ensemblgenomes.org/pub/misc_data/Track_Hubs -do_track_hubs_from_scratch 1> output_fs_wh_16Feb 2>errors_fs_wh_16Feb

# third Registry account for testing: username: tapanari2 , password : testing2

use strict ;
use warnings;

use Getopt::Long;
use DateTime;   
use Time::HiRes;
use Time::Piece;
use Registry;
use TrackHubCreation;
use Helper;
use Data::Dumper;
use ENA;

use ArrayExpress;
use AEStudy;

my ($registry_user_name,$registry_pwd);
my $server_dir_full_path ; # ie. ftp://ftp.ensemblgenomes.org/pub/misc_data/.TrackHubs
my $server_url ;  # ie. /nfs/ensemblgenomes/ftp/pub/misc_data/.TrackHubs;
my $from_scratch;

my $start_time = time();

GetOptions(
  "THR_username=s" => \$registry_user_name ,
  "THR_password=s" => \$registry_pwd,
  "server_dir_full_path=s" => \$server_dir_full_path,
  "server_url=s" => \$server_url,  
  "do_track_hubs_from_scratch"  => \$from_scratch  # flag
);

my $start_run = time();

{ # main method

 print_calling_params_logging($registry_user_name , $registry_pwd , $server_dir_full_path , $server_url, $from_scratch);

  my $registry_obj = Registry->new($registry_user_name, $registry_pwd);

  if (! -d $server_dir_full_path) {  # if the directory that the user defined to write the files of the track hubs doesnt exist, I try to make it

    print "\nThis directory: $server_dir_full_path does not exist, I will make it now.\n";

    Helper::run_system_command("mkdir $server_dir_full_path")
      or die "I cannot make dir $server_dir_full_path in script: ".__FILE__." line: ".__LINE__."\n";
  }

  my ($studies_not_yet_in_ena_aref, $skipped_studies_due_to_registry_issues_aref, $skipped_studies_due_to_missing_samples_in_AE_API_aref) = ([] , [] , []);

  my $plant_names_AE_response_href = ArrayExpress::get_plant_names_AE_API();

  if($plant_names_AE_response_href == 0){

    die "Could not get plant names with processed runs from AE API callin script ".__FILE__." line: ".__LINE__."\n";
  }

  my $study_ids_href_AE = get_list_of_all_AE_plant_studies_currently(); #  gets all Array Express current plant study ids

  my $organism_assmblAccession_EG_href = EG::get_species_name_assembly_id_hash(); #$hash{"brachypodium_distachyon"} = "GCA_000005505.1"         also:  $hash{"oryza_rufipogon"} = "0000"
  
  if ($from_scratch){

    ($studies_not_yet_in_ena_aref,$skipped_studies_due_to_registry_issues_aref,$skipped_studies_due_to_missing_samples_in_AE_API_aref) = run_pipeline_from_scratch_with_logging($registry_obj, $study_ids_href_AE , $server_dir_full_path, $organism_assmblAccession_EG_href, $plant_names_AE_response_href ,$studies_not_yet_in_ena_aref, $skipped_studies_due_to_registry_issues_aref, $skipped_studies_due_to_missing_samples_in_AE_API_aref,); 

  }
  else {  # incremental update

    print_registered_TH_in_THR_stats_before_update_pipeline_is_run($registry_obj,$plant_names_AE_response_href);
    ($studies_not_yet_in_ena_aref,$skipped_studies_due_to_registry_issues_aref,$skipped_studies_due_to_missing_samples_in_AE_API_aref) = run_pipeline_with_incremental_update_with_logging($study_ids_href_AE,$registry_obj,$server_dir_full_path,$plant_names_AE_response_href ,$organism_assmblAccession_EG_href , $studies_not_yet_in_ena_aref, $skipped_studies_due_to_registry_issues_aref, $skipped_studies_due_to_missing_samples_in_AE_API_aref);
  }

  print_run_duration_so_far($start_time);

  ## after the pipeline finishes running, I print some log info:

  my ($study_id_biorep_ids_AE_currently_href , $plant_study_id_AE_currently_number_of_bioreps_href) = give_hashes_with_AE_current_stats($study_ids_href_AE,$plant_names_AE_response_href);

  print_current_AE_studies_stats($study_id_biorep_ids_AE_currently_href ,$plant_study_id_AE_currently_number_of_bioreps_href , $server_dir_full_path);

  print_registered_TH_in_THR_stats_after_pipeline_is_run($registry_obj,$studies_not_yet_in_ena_aref, $skipped_studies_due_to_registry_issues_aref ,$plant_names_AE_response_href,$skipped_studies_due_to_missing_samples_in_AE_API_aref);
  print_run_duration_so_far($start_time);
  
  my $date_string_end = localtime();
  print "\n Finished running the pipeline on:\n";
  print "Local date,time: $date_string_end\n";

}


##METHODS##

sub print_registered_TH_in_THR_stats_before_update_pipeline_is_run{

  my $registry_obj = shift;
  my $plant_names_AE_response_href  = shift ;

  my $all_track_hubs_in_registry_after_update_href = $registry_obj->give_all_Registered_track_hub_names();
  my %distinct_bioreps;

  foreach my $hub_name (keys %{$all_track_hubs_in_registry_after_update_href}){
  
    my $study_obj = AEStudy->new($hub_name,$plant_names_AE_response_href);
    my %bioreps_hash = %{$study_obj->get_biorep_ids};
    map { $distinct_bioreps{$_}++ } keys %bioreps_hash;
  }

  print "There are in total ". scalar (keys %{$all_track_hubs_in_registry_after_update_href});
  print " track hubs with total ".scalar (keys %distinct_bioreps)." bioreps registered in the Track Hub Registry\n\n";

}


sub run_pipeline_with_incremental_update_with_logging{

  my $study_ids_href_AE = shift;
  my $registry_obj = shift;
  my $server_dir_full_path = shift;
  my $plant_names_AE_response_href = shift;
  my $organism_assmblAccession_EG_href = shift;

  my $studies_not_yet_in_ena_aref = shift;
  my $skipped_studies_due_to_registry_issues_aref = shift;
  my $skipped_studies_due_to_missing_samples_in_AE_API_aref = shift;

  my $registered_track_hubs_href = $registry_obj->give_all_Registered_track_hub_names; # track hubs that are already registered

  remove_obsolete_studies($study_ids_href_AE, $registry_obj, $registered_track_hubs_href, $server_dir_full_path); # if there are any obsolete track hubs, they are removed from the THR and the server

  my ($new_study_ids_aref, $common_study_ids_aref) = get_new_and_common_study_ids($study_ids_href_AE,$registered_track_hubs_href);

  my $study_counter = 0;

  print "\n************* Updates of studies (new/changed) from last time the pipeline was run:\n\n";

  if(scalar (@$new_study_ids_aref) == 0){
    print "No new studies are found between current AE API studies and registered studies in the THR\n";
  }else{
    print "\nNew studies (".scalar (@$new_study_ids_aref) ." studies) from last time the pipeline was run:\n\n";
  }

  ($studies_not_yet_in_ena_aref,$skipped_studies_due_to_registry_issues_aref,$skipped_studies_due_to_missing_samples_in_AE_API_aref)= create_new_studies_in_incremental_update($new_study_ids_aref,$server_dir_full_path ,$plant_names_AE_response_href,$registry_obj,$organism_assmblAccession_EG_href , $studies_not_yet_in_ena_aref, $skipped_studies_due_to_registry_issues_aref, $skipped_studies_due_to_missing_samples_in_AE_API_aref); 

  ($studies_not_yet_in_ena_aref,$skipped_studies_due_to_registry_issues_aref,$skipped_studies_due_to_missing_samples_in_AE_API_aref)= update_common_studies($common_study_ids_aref,$registry_obj,$plant_names_AE_response_href,$server_dir_full_path ,$organism_assmblAccession_EG_href,$studies_not_yet_in_ena_aref,$skipped_studies_due_to_registry_issues_aref,$skipped_studies_due_to_missing_samples_in_AE_API_aref);

  return ($studies_not_yet_in_ena_aref,$skipped_studies_due_to_registry_issues_aref,$skipped_studies_due_to_missing_samples_in_AE_API_aref); 
}


sub update_common_studies{

  my $common_study_ids_aref = shift;
  my $registry_obj = shift;
  my $plant_names_AE_response_href = shift;
  my $server_dir_full_path = shift;
  my $organism_assmblAccession_EG_href = shift;

  my $studies_not_yet_in_ena_aref = shift ;
  my $skipped_studies_due_to_registry_issues_aref = shift;
  my $skipped_studies_due_to_missing_samples_in_AE_API_aref = shift;

  my %common_studies_to_be_updated = %{get_study_ids_to_be_updated($common_study_ids_aref, $registry_obj,$plant_names_AE_response_href)}; #hash looks like: $common_study_ids_to_be_updated {$common_study_id}=\@holder_of_reason_of_update;

  if(scalar (keys %common_studies_to_be_updated) == 0){
    print "\n\nNo common studies between current AE API and registered studies in the THR are found to need updating\n";
  }else{
    print "\nStudies to be updated (".scalar (keys %common_studies_to_be_updated)." studies) from last time the pipeline was run:\n";
  }
  print "\n\n";

  my $study_counter = 0;

  foreach my $study_id (keys %common_studies_to_be_updated){

    my $study_obj = AEStudy->new($study_id,$plant_names_AE_response_href);

    my $sample_ids_href = $study_obj->get_sample_ids();
    if(!$sample_ids_href){  # there are cases where the AE API returns a study with the the sample_ids field to be null , I want to skip these studies
      push (@$skipped_studies_due_to_missing_samples_in_AE_API_aref, $study_obj->id);
      next;
    }

    $study_counter++;

    my @info_array = @{$common_studies_to_be_updated{$study_id}};

    my $old_study_counter = $study_counter;
    my $unsuccessfull_study_href;

    # first I remove it from the server, to re-make it
    my $ls_output = `ls $server_dir_full_path`  ;

    if($ls_output =~/$study_id/){ # i check if the directory was created

      my $method_return= Helper::run_system_command("rm -r $server_dir_full_path/$study_id");
      if (!$method_return){ # returns 1 if successfully deleted or 0 if not, !($method_return is like $method_return=0)
        print STDERR "I cannot rm dir $server_dir_full_path/$study_id in script: ".__FILE__." line: ".__LINE__."\n";
      }
    }
    
    my $date_registry_last = localtime($registry_obj->get_Registry_hub_last_update($study_id))->strftime('%F %T');
    ($unsuccessfull_study_href,$study_counter) = make_and_register_track_hub($study_obj,$registry_obj,$old_study_counter, $server_dir_full_path,$organism_assmblAccession_EG_href ,$plant_names_AE_response_href); 
#######
    print "\t..Because: ";
    if($info_array[0] eq "diff_time_only"){

      #my $date_registry_last = localtime($registry_obj->get_Registry_hub_last_update($study_id))->strftime('%F %T');
      my $date_cram_created = localtime($study_obj->get_AE_last_processed_unix_date)->strftime('%F %T');

      print " Last registered date: ".$date_registry_last  . ", Max last processed date of CRAMS from study: ".$date_cram_created."\n";

    }elsif($info_array[0] eq "diff_bioreps_diff_time"){

      #my $date_registry_last = localtime($registry_obj->get_Registry_hub_last_update($study_id))->strftime('%F %T');
      my $date_cram_created = localtime($study_obj->get_AE_last_processed_unix_date)->strftime('%F %T');

      print " Last registered date: ".$date_registry_last  . ", Max last processed date of CRAMS from study: ".$date_cram_created . " and also different number/ids of runs: "." Last Registered number of runs: ".$info_array[1].", Runs in Array Express currently: ".$info_array[2]."\n";

    }elsif($info_array[0] eq "diff_bioreps_only") {

      print " Different number/ids of runs: Last Registered number of runs: ".$info_array[1].", Runs in Array Express currently: ".$info_array[2]."\n";

    }else{

      print "Don't know why this study is being updated\n" and print STDERR "Something went wrong with common study between the THR and AE $study_id that I decided to update; don't know why needs updating\n";
    }
######

    if ($unsuccessfull_study_href->{"not yet in ENA"}){  # hash is like this: $unsuccessful_study{"not yet in ENA"}{$study_id}= 1;

      foreach my $study_id (keys %{$unsuccessfull_study_href->{"not yet in ENA"}}){
        push(@$studies_not_yet_in_ena_aref,$study_id);
      }
    }
    if ($unsuccessfull_study_href->{"Registry issue"}){  # hash is like this:  $unsuccessful_study{"Registry issue"}{$study_id}= 1;

      foreach my $study_id (keys %{$unsuccessfull_study_href->{"Registry issue"}}){
        push(@$skipped_studies_due_to_registry_issues_aref,$study_id);
      }
    }
  }
  return ($studies_not_yet_in_ena_aref,$skipped_studies_due_to_registry_issues_aref,$skipped_studies_due_to_missing_samples_in_AE_API_aref); 

}

sub create_new_studies_in_incremental_update{

  my $new_study_ids_aref = shift;
  my $server_dir_full_path = shift;
  my $plant_names_AE_response_href = shift;
  my $registry_obj = shift;
  my $organism_assmblAccession_EG_href = shift;

  my $studies_not_yet_in_ena_aref = shift ;
  my $skipped_studies_due_to_registry_issues_aref =shift;
  my $skipped_studies_due_to_missing_samples_in_AE_API_aref = shift;

  my $study_counter = 0;


  foreach my $study_id (@$new_study_ids_aref) {

    my $ls_output = `ls $server_dir_full_path`  ;
    if($ls_output =~/$study_id/){ # i check if the directory was created

      my $method_return= Helper::run_system_command("rm -r $server_dir_full_path/$study_id");
      if (!$method_return){ # returns 1 if successfully deleted or 0 if not, !($method_return is like $method_return=0)
        print STDERR "I cannot rm dir $server_dir_full_path/$study_id in script: ".__FILE__." line: ".__LINE__."\n";
        print STDERR "This study $study_id will be skipped";
        next;
      }
    }
    my $study_obj = AEStudy->new($study_id,$plant_names_AE_response_href);

    my $sample_ids_href = $study_obj->get_sample_ids();
    if(!$sample_ids_href){  # there are cases where the AE API returns a study with the the sample_ids field to be null , I want to skip these studies
      push (@$skipped_studies_due_to_missing_samples_in_AE_API_aref, $study_obj->id);
      next;
    }

    $study_counter++;

    my $old_study_counter = $study_counter;

    my $unsuccessfull_study_href;
    ($unsuccessfull_study_href,$study_counter) = make_and_register_track_hub($study_obj,$registry_obj,$old_study_counter, $server_dir_full_path,$organism_assmblAccession_EG_href, $plant_names_AE_response_href ); 

    if ($unsuccessfull_study_href->{"not yet in ENA"}){  # hash is like this: $unsuccessful_study{"not yet in ENA"}{$study_id}= 1;

      foreach my $study_id (keys %{$unsuccessfull_study_href->{"not yet in ENA"}}){
        push(@$studies_not_yet_in_ena_aref,$study_id);
      }
    }
    if ($unsuccessfull_study_href->{"Registry issue"}){  # hash is like this:  $unsuccessful_study{"Registry issue"}{$study_id}= 1;

      foreach my $study_id (keys %{$unsuccessfull_study_href->{"Registry issue"}}){
        push(@$skipped_studies_due_to_registry_issues_aref,$study_id);
      }
    }
  }  
  return ($studies_not_yet_in_ena_aref,$skipped_studies_due_to_registry_issues_aref,$skipped_studies_due_to_missing_samples_in_AE_API_aref); 

}

sub remove_obsolete_studies {

  my $study_ids_href_AE = shift;  # current study ids from AE
  my $registry_obj = shift;
  my $registered_track_hubs_href = shift;
  my $server_dir_full_path= shift;

  my @track_hubs_for_deletion;

  foreach my $study_id_registered(keys %{$registered_track_hubs_href}){

    if(!$study_ids_href_AE->{$study_id_registered}){ # if the registered TH (study id) is not any more in AE REST response, then I will delete it
      push (@track_hubs_for_deletion , $study_id_registered);
    }
  }
  
  if(scalar @track_hubs_for_deletion > 0){

    print "\n************* Starting to delete obsolete track hubs from the trackHub Registry and the server:\n\n";

    foreach my $track_hub_id (@track_hubs_for_deletion){

      $registry_obj->delete_track_hub($track_hub_id) ; # it's an obsolete study- it needs deletion

      my $method_return= Helper::run_system_command("rm -r $server_dir_full_path/$track_hub_id");
      if (!$method_return){ # returns 1 if successfully deleted or 0 if not, !($method_return is like $method_return=0)
        print STDERR "Could not remove obsolete track hub $track_hub_id in location $server_dir_full_path\n";
      }
    }
  }else{

    print "\n************* There are not any obsolete track hubs to be removed since the last time the pipeline was run.\n\n";
  }
}

sub get_new_and_common_study_ids{ 

  my $study_ids_href_AE = shift;  # current study ids from AE
  my $registered_track_hubs_href = shift;

  my @new_study_ids;
  my @common_study_ids;

  foreach my $study_id_currently_AE (keys %{$study_ids_href_AE}){

    if($registered_track_hubs_href->{$study_id_currently_AE}){

      push(@common_study_ids ,$study_id_currently_AE) ; # it's a common study

    }else{
      push(@new_study_ids,$study_id_currently_AE) ; # it's a new study
    }
  }

  return (\@new_study_ids, \@common_study_ids);

}

sub get_study_ids_to_be_updated{ # gets a list of common study ids and decides which ones have changed, hence need updating

  my $common_study_ids_array_ref = shift;
  my $registry_obj = shift;
  my $plant_names_AE_response_href = shift;

  my %common_study_ids_to_be_updated;

  foreach my $common_study_id (@$common_study_ids_array_ref){ 

    my $study_obj = AEStudy->new($common_study_id,$plant_names_AE_response_href);

    my $AE_last_processed_unix_time = $study_obj->get_AE_last_processed_unix_date; # AE current response: the unix date of the creation the cram of the study (gives me the max date of all bioreps of the study)
    my $registry_study_created_date_unix_time = eval { $registry_obj->get_Registry_hub_last_update($common_study_id) }; # date of registration of the study

    if ($@) { # if the get_Registry_hub_last_update method fails to return the date of the track hub , then i re-do it anyways to be on the safe side

      my @table;
      $table[0]= "registry_no_response";
      $common_study_ids_to_be_updated{$common_study_id} = \@table;
      print "Couldn't get hub update: $@\ngoing to update hub anyway\n"; 

    }elsif($registry_study_created_date_unix_time) {

      # I want to check also if the bioreps of the common study are the same in the Registry and in Array Express:
      my %bioreps_in_Registry = %{$registry_obj->give_all_bioreps_of_study_from_Registry($common_study_id)};  # when last registered
      my %bioreps_in_Array_Express = %{$study_obj->get_biorep_ids()} ;   # currently 

      my @holder_of_reason_of_update; # i save the numbers because I want to print them out as log
      $holder_of_reason_of_update[1]= scalar (keys %bioreps_in_Registry); # in cell 1 of this table it's stored the number of bioreps of the common study in the Registry
      $holder_of_reason_of_update[2]= scalar (keys %bioreps_in_Array_Express);  # in cell 2 of this table it's stored the number of bioreps of the common study in current Array Express API call

      my $are_bioreps_the_same = hash_keys_are_equal(\%bioreps_in_Registry,\%bioreps_in_Array_Express); # returns 0 id they are not equal, 1 if they are
        
      if( $registry_study_created_date_unix_time < $AE_last_processed_unix_time or $are_bioreps_the_same ==0) { # if the study was registered before AE changed it OR it has now different bioreps, it needs to be updated

        if( $registry_study_created_date_unix_time < $AE_last_processed_unix_time and $are_bioreps_the_same ==1){  # study was changed by AE after it was created and registered in the THR
          $holder_of_reason_of_update[0] = "diff_time_only";
          $common_study_ids_to_be_updated {$common_study_id}=\@holder_of_reason_of_update;
        }
        if ( $registry_study_created_date_unix_time >= $AE_last_processed_unix_time and $are_bioreps_the_same ==0) { # different number of bioreps
          $holder_of_reason_of_update[0] = "diff_bioreps_only";
          $common_study_ids_to_be_updated {$common_study_id}=\@holder_of_reason_of_update;
        }
        if( $registry_study_created_date_unix_time < $AE_last_processed_unix_time and $are_bioreps_the_same ==0){ #  both 
          $holder_of_reason_of_update[0] = "diff_bioreps_diff_time";
          $common_study_ids_to_be_updated {$common_study_id}=\@holder_of_reason_of_update;
        }
      }
    } else {
      die "I have to really die here since I don't know what happened in script ".__FILE__." line ".__LINE__."\n";
    } 
  }

  return \%common_study_ids_to_be_updated;
}

sub print_run_duration_so_far{

  my $start_run = shift;

  my $end_run = time();
  my $run_time = $end_run - $start_run;

  print "\nRun time was $run_time seconds (". $run_time/3600 ." hours)\n";
}

sub print_current_AE_studies_stats{

  my $study_id_biorep_ids_AE_currently_href = shift;   # stores from AE API the hash with key: study id , value: hash with keys the biorep ids of the study  hash{"SRP067728"} = \%hash{biorep_id}
  my $plant_study_id_AE_currently_number_of_bioreps_href = shift;  # it would be : hash{"oryza_sativa"}{"SRP067728"} = 20
  my $server_dir_full_path = shift;

  my $current_date = return_current_date();

  my %total_bioreps; # to get number of distinct biorep ids 

  foreach my $study_id (keys %{$study_id_biorep_ids_AE_currently_href}){
    foreach my $biorep_id (keys %{$study_id_biorep_ids_AE_currently_href->{$study_id}}){
      $total_bioreps{$biorep_id}=1;
    }
  }

  print "\n####################################################################################\n";
  print "\nArray Express REST calls give the following stats:\n";
  print "\nThere are " . scalar (keys %total_bioreps) ." plant bioreps completed to date ( $current_date )\n";
  print "\nThere are " . scalar (keys %{$study_id_biorep_ids_AE_currently_href}) ." plant studies completed to date ( $current_date )\n";

  print "\n****** Plants done to date: ******\n\n";


  my $index = 0;

  my %plant_number_of_bioreps=(); # $hash{"oryza_sativa"}  = 50 (number of bioreps)

  foreach my $plant (keys %{$plant_study_id_AE_currently_number_of_bioreps_href}){

    my $number_of_bioreps = 0;
    foreach my $study_id (keys %{$plant_study_id_AE_currently_number_of_bioreps_href->{$plant}}){

      $number_of_bioreps=$number_of_bioreps + $plant_study_id_AE_currently_number_of_bioreps_href->{$plant}{$study_id};
    }

    $plant_number_of_bioreps{$plant} = $number_of_bioreps;
  }

  foreach my $plant (keys %{$plant_study_id_AE_currently_number_of_bioreps_href}){
    $index++;
    print $index.".\t".$plant." =>\t".$plant_number_of_bioreps{$plant} ." bioreps / ". scalar keys (%{$plant_study_id_AE_currently_number_of_bioreps_href->{$plant}})." studies\n";

  }
  print "\n";

  print "In total there are " .scalar (keys %{$plant_study_id_AE_currently_number_of_bioreps_href})." Ensembl plants done to date.\n\n";
  print "####################################################################################\n\n";

  my $total_disc_space_of_track_hubs = `du -sh $server_dir_full_path`;
  
  print "\nTotal disc space occupied in $server_dir_full_path is:\n $total_disc_space_of_track_hubs\n";

  print "There are in total ". give_number_of_dirs_in_ftp($server_dir_full_path). " files in the ftp server\n\n";
}

sub print_registered_TH_in_THR_stats_after_pipeline_is_run{

  my $registry_obj = shift;
  my $studies_not_yet_in_ena_aref = shift;

  my $skipped_studies_due_to_registry_issues_aref = shift;
  my $plant_names_AE_response_href  = shift ;
  my $skipped_studies_due_to_missing_samples_in_AE_API_aref = shift;

  my $all_track_hubs_in_registry_after_update_href = $registry_obj->give_all_Registered_track_hub_names();
  my %distinct_bioreps;

  foreach my $hub_name (keys %{$all_track_hubs_in_registry_after_update_href}){
  
    my $study_obj = AEStudy->new($hub_name,$plant_names_AE_response_href );
    my %bioreps_hash = %{$study_obj->get_biorep_ids};
    map { $distinct_bioreps{$_}++ } keys %bioreps_hash;
  }

  print "There are in total ". scalar (keys %{$all_track_hubs_in_registry_after_update_href});
  print " track hubs with total ".scalar (keys %distinct_bioreps)." bioreps registered in the Track Hub Registry\n\n";


  if (scalar @$studies_not_yet_in_ena_aref > 0){
    print "These studies were ready by Array Express but not yet in ENA , so no trak hubs were able to be created out of those, since the metadata needed for the track hubs are taken from ENA: ".scalar @$studies_not_yet_in_ena_aref." in total\n\n";
    my $count_unready_studies=0;
    foreach my $study_id (@$studies_not_yet_in_ena_aref){
      $count_unready_studies++;
      my $study_obj = AEStudy->new($study_id,$plant_names_AE_response_href);
      my %bioreps_hash = %{$study_obj->get_biorep_ids};
      print $count_unready_studies.".".$study_id." (".scalar (keys %bioreps_hash)." bioreps)\n";
    }
  }


  if (scalar @$skipped_studies_due_to_registry_issues_aref > 0){
    print "\nThese studies were not able to be registered in the Track Hub Registry , hence skipped (removed from the ftp server too): ".scalar @$skipped_studies_due_to_registry_issues_aref ." in total\n\n";
    my $count_skipped_studies=0;
    foreach my $study_id (@$skipped_studies_due_to_registry_issues_aref){
      $count_skipped_studies++;
      my $study_obj = AEStudy->new($study_id,$plant_names_AE_response_href);
      my %bioreps_hash = %{$study_obj->get_biorep_ids};
      print $count_skipped_studies.".".$study_id." (".scalar (keys %bioreps_hash)." bioreps)\n";
    }
  }


  if (scalar @$skipped_studies_due_to_missing_samples_in_AE_API_aref> 0){
    print "\nThese studies were found not to have any sample ids in AE API , hence skipped (removed from the ftp server too): ".scalar @$skipped_studies_due_to_missing_samples_in_AE_API_aref ." in total\n\n";
    my $count_skipped_studies=0;
    foreach my $study_id (@$skipped_studies_due_to_missing_samples_in_AE_API_aref){
      $count_skipped_studies++;
      my $study_obj = AEStudy->new($study_id,$plant_names_AE_response_href);
      my %bioreps_hash = %{$study_obj->get_biorep_ids};
      print $count_skipped_studies.".".$study_id." (".scalar (keys %bioreps_hash)." bioreps)\n";
    }
  }
}

sub delete_registered_th_and_remove_th_from_server{  # called only when option is run pipeline from scratch

  my $registry_obj = shift ;
  my $server_dir_full_path = shift;

  my $number_of_registered_th_initially = print_registry_registered_number_of_th($registry_obj);

  print " ******** Deleting all track hubs registered in the Registry under my account\n\n";  
 
  if($number_of_registered_th_initially ==0){

    print "there were no track hubs registered \n";

  }else{

    print $registry_obj->delete_track_hub("all") ; # method that deletes all registered track hubs under this THR account
  }

  print "\n ******** Deleting everything in directory $server_dir_full_path\n\n";

  my ($successfully_ran_method,$ls_output) = Helper::run_system_command_with_output("ls $server_dir_full_path");

  if($successfully_ran_method ==0) { 

    die "I cannot see contents of $server_dir_full_path(ls failed) in script: ".__FILE__." line: ".__LINE__."\n";
  }

  if($successfully_ran_method ==1 and (!($ls_output))){  # if dir is empty 

    print "Directory $server_dir_full_path is empty - No need for deletion\n";
  }

  if($successfully_ran_method ==1 and ($ls_output)){ # directory is not empty, I will delete all its contents

    Helper::run_system_command("rm -r $server_dir_full_path/*")   # removing the track hub files in the server/dir
      or die "ERROR: failed to remove contents of dir $server_dir_full_path in script: ".__FILE__." line: ".__LINE__."\n";

    print "Successfully deleted all content of $server_dir_full_path\n";    

  }
  $| = 1; 
}

sub run_pipeline_from_scratch_with_logging{

  my $registry_obj = shift ;
  my $study_ids_href_AE = shift; # all the study ids that currently the AE API returns for plants.
  my $server_dir_full_path = shift;
  my $organism_assmblAccession_EG_href = shift;
  my $plant_names_AE_response_href = shift;

  my $studies_not_yet_in_ena_aref =shift;
  my $skipped_studies_due_to_registry_issues_aref=shift;
  my $skipped_studies_due_to_missing_samples_in_AE_API_aref = shift;

  delete_registered_th_and_remove_th_from_server($registry_obj,$server_dir_full_path);
 
  print "\n ******** Starting to make directories and files for the track hubs in the ftp server: $server_url\n\n";

  my $study_counter = 0;

  foreach my $study_id (keys %{$study_ids_href_AE}){

    my $study_obj = AEStudy->new($study_id,$plant_names_AE_response_href);

    my $sample_ids_href = $study_obj->get_sample_ids();
    if(!$sample_ids_href){  # there are cases where the AE API returns a study with the the sample_ids field to be null , I want to skip these studies
      push (@$skipped_studies_due_to_missing_samples_in_AE_API_aref, $study_obj->id);
      next;
    }

    $study_counter++;
    my $old_study_counter = $study_counter;

    my $unsuccessfull_study_href;
    ($unsuccessfull_study_href, $study_counter)= make_and_register_track_hub($study_obj ,$registry_obj ,$old_study_counter, $server_dir_full_path,$organism_assmblAccession_EG_href, $plant_names_AE_response_href);
    # method make_and_register_track_hub returns the $study_counter reduced by 1 if the TH creation and registration is unsuccessful

    if ($unsuccessfull_study_href->{"not yet in ENA"}){
      foreach my $study_id (keys %{$unsuccessfull_study_href->{"not yet in ENA"}}){  # it would be like       $unsuccessful_study{"not yet in ENA"}{$study_id}=1;
        push(@$studies_not_yet_in_ena_aref,$study_id); 
      }
    }
    if ($unsuccessfull_study_href->{"Registry issue"}){
      foreach my $study_id (keys %{$unsuccessfull_study_href->{"Registry issue"}}){  # it would be like       $unsuccessful_study{"Registry issue"}{$study_id}=1;
        push(@$skipped_studies_due_to_registry_issues_aref,$study_id);
      }
    }
  }

  my $date_string2 = localtime();
  print " \n Finished creating the files,directories of the THs on the server and registering all THs in the THR on:\n";
  print "Local date,time: $date_string2\n";

  print "\n***********************************\n";
  $| = 1; 
  return ($studies_not_yet_in_ena_aref,$skipped_studies_due_to_registry_issues_aref,$skipped_studies_due_to_missing_samples_in_AE_API_aref); 
}

sub give_hashes_with_AE_current_stats{

  my $study_ids_href_AE = shift; # all the study ids that currently the AE API returns for plants.
  my $plant_names_AE_response_href  = shift;

  my %study_id_biorep_ids_AE_currently;  # stores from AE API the hash with key: study id , value: hash with keys the biorep ids of the study
  my %plant_study_id_AE_currently_number_of_bioreps;   # it would be : hash{"oryza_sativa"}{"SRP067728"} = 20
 
  foreach my $study_id (keys %{$study_ids_href_AE}){

    my $study_obj = AEStudy->new($study_id,$plant_names_AE_response_href );

    my %biorep_ids = %{$study_obj->get_biorep_ids};

    $study_id_biorep_ids_AE_currently{$study_id}=\%biorep_ids;

    my $species_of_study_href = $study_obj->get_organism_names_assembly_names(); # hash-> key: organism_name , value: assembly_name , a study can have more than 1 species

    foreach my $species_name (keys %{$species_of_study_href}){

      $plant_study_id_AE_currently_number_of_bioreps{$species_name}{$study_id}=scalar (keys %{$study_obj->get_biorep_ids_by_organism($species_name)}); 
      
    }
  }
  
  return (\%study_id_biorep_ids_AE_currently , \%plant_study_id_AE_currently_number_of_bioreps);
}

sub return_current_date{

  my $dt = DateTime->today;

  my $date_wrong_order = $dt->date;  # it is in format 2015-10-01
  # i want 01-10-2015

  my @words = split(/-/, $date_wrong_order);
  my $current_date = $words[2] . "-". $words[1]. "-". $words[0];  # ie 01-10-2015 (1st October)

  return $current_date;
}

sub give_number_of_dirs_in_ftp {

  my $ftp_location = shift;
  
  my @files = `ls $ftp_location` ;
  
  return  scalar @files;
}

sub hash_keys_are_equal{
   
  my ($hash1, $hash2) = @_;
  my $areEqual=1;

  if(scalar(keys %{$hash1}) == scalar (keys %{$hash2})){

    foreach my $key1(keys %{$hash1}) {
      if(!$hash2->{$key1}) {

        $areEqual=0;
      }
    }
  }else{
    $areEqual = 0;
  }

  return $areEqual;
}

sub print_calling_params_logging{
  
  my ($registry_user_name , $registry_pwd , $server_dir_full_path ,$server_url,$from_scratch) = @_;
  my $date_string = localtime();

  print "* Started running the pipeline on:\n";
  print "Local date,time: $date_string\n";

  print "\n* Ran this pipeline:\n\n";
  print "perl pipeline_create_register_track_hubs.pl -THR_username $registry_user_name -THR_password $registry_pwd -server_dir_full_path $server_dir_full_path -server_url $server_url";
  if($from_scratch){
    print " -do_track_hubs_from_scratch";
  }

  print "\n";
  print "\n* I am using this server to eventually build my track hubs:\n\n $server_url\n\n";
  print "* I am using this Registry account:\n\n user:$registry_user_name \n password:$registry_pwd\n\n";

  $| = 1;  # it flashes the output

}

sub print_registry_registered_number_of_th{

  my $registry_obj = shift;
  my %studies_last_run_of_pipeline = %{$registry_obj->give_all_Registered_track_hub_names()};
  my %distinct_bioreps_before_running_pipeline;

  foreach my $hub_name (keys %studies_last_run_of_pipeline){
  
    map { $distinct_bioreps_before_running_pipeline{$_}++ } keys %{$registry_obj->give_all_bioreps_of_study_from_Registry($hub_name)}; 
  }

  print "\n* Before starting running the updates, there were in total ". scalar (keys %studies_last_run_of_pipeline). " track hubs with total ".scalar (keys %distinct_bioreps_before_running_pipeline)." bioreps registered in the Track Hub Registry under this account.\n\n";

  $| = 1;  # it flashes the output

  return scalar (keys %studies_last_run_of_pipeline);
}

sub get_list_of_all_AE_plant_studies_currently{

  my $plant_names_href_EG = EG::get_plant_names;
  
  my $study_ids_href = ArrayExpress::get_completed_study_ids_for_plants($plant_names_href_EG);

  return $study_ids_href;
}

sub make_and_register_track_hub{

  my $study_obj = shift;
  my $registry_obj = shift;
  my $line_counter = shift;
  my $server_dir_full_path = shift;
  my $organism_assmblAccession_EG_href = shift;
  my $plant_names_AE_response_href = shift;

  my $return_string;
 
  my $study_id = $study_obj->id;
  print "$line_counter.\tcreating track hub for study $study_id\t"; 

  my $track_hub_creator_obj = TrackHubCreation->new($study_id,$server_dir_full_path);
  my $script_output = $track_hub_creator_obj->make_track_hub($plant_names_AE_response_href);

  print $script_output;

  my %unsuccessful_study;
  my $date_registry_last;

  if($script_output !~ /..Done/){  # if for some reason the track hub didn't manage to be made in the server, it shouldn't be registered in the Registry, for example Robert gives me a study id as completed that is not yet in ENA

    print STDERR "Track hub of $study_id could not be made in the server - Folder $study_id will be deleted\n\n" ;
    print "\t..Skipping registration part\n";

    Helper::run_system_command("rm -r $server_dir_full_path/$study_id")      
      or die "ERROR: failed to remove dir $server_dir_full_path/$study_id in script: ".__FILE__." line: ".__LINE__."\n";

    $line_counter --;
    $unsuccessful_study{"not yet in ENA"} {$study_id}= 1;

  }else{  # if the study is successfully created in the ftp server, I go ahead and register it

    my $output = register_track_hub_in_TH_registry($registry_obj,$study_obj,$organism_assmblAccession_EG_href );  

    $return_string = $output;

    if($output !~ /is Registered/){# if something went wrong with the registration, i will not make a track hub out of this study
      Helper::run_system_command("rm -r $server_dir_full_path/$study_id")
        or die "ERROR: failed to remove dir $server_dir_full_path/$study_id in script: ".__FILE__." line: ".__LINE__."\n";

      $line_counter --;
      $return_string = $return_string . "\t..Something went wrong with the Registration process -- this study will be skipped..\n";
      $unsuccessful_study{"Registry issue"}{$study_id}= 1;
    }

    print $return_string;
      
  }

  return (\%unsuccessful_study,$line_counter);
}

sub get_assembly_names_assembly_ids_string_for_study{

  my $study_obj = shift;
  my $organism_assmblAccession_EG_href = shift; #$hash{"brachypodium_distachyon"} = "GCA_000005505.1"  


  my $assemblyNames_assemblyAccesions_string="not found";
  my @assembly_name_assembly_id_pairs;

  my %study_organism_names_AE_assembly_name = %{$study_obj->get_organism_names_assembly_names}; # from AE API: $hash{"selaginella_moellendorffii"}= "TAIR10"

  foreach my $organism_name_AE (keys %study_organism_names_AE_assembly_name) { # the organism name AE is the reference species name, so the same as the EG names

    if($organism_assmblAccession_EG_href->{$organism_name_AE}){

      my $string = $study_organism_names_AE_assembly_name{$organism_name_AE} ."," . $organism_assmblAccession_EG_href->{$organism_name_AE};
      push(@assembly_name_assembly_id_pairs , $string);

    }else{
      die "Could not find AE organism name $organism_name_AE in EG REST response\n";
    }
    $assemblyNames_assemblyAccesions_string= join(",",@assembly_name_assembly_id_pairs);  
  }

  return $assemblyNames_assemblyAccesions_string;
}

sub register_track_hub_in_TH_registry{

  my $registry_obj = shift;
  my $study_obj = shift;
  my $organism_assmblAccession_EG_href = shift ;

  my $study_id = $study_obj->id; 
 
  my $hub_txt_url = $server_url . "/" . $study_id . "/hub.txt" ;

  my $assemblyNames_assemblyAccesions_string = get_assembly_names_assembly_ids_string_for_study($study_obj,$organism_assmblAccession_EG_href);
  my $output = $registry_obj->register_track_hub($study_id,$hub_txt_url,$assemblyNames_assemblyAccesions_string);
  return $output;
  
}