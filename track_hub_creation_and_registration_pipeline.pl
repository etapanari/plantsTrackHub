# before I run I set up my PERL5LIB doing 2 things:  ********************************************************
# PERL5LIB=/nfs/panda/ensemblgenomes/development/tapanari/eg-ena/modules
# source /nfs/panda/ensemblgenomes/apis/ensembl/81/setup.sh

# or simply:
#PERL5LIB=/nfs/production/panda/ensemblgenomes/apis/ensembl/81/ensembl-variation/modules:/nfs/production/panda/ensemblgenomes/apis/ensembl/81/ensembl-rest/lib:/nfs/production/panda/ensemblgenomes/apis/ensembl/81/ensembl-production/modules:/nfs/production/panda/ensemblgenomes/apis/ensembl/81/ensembl-pipeline/modules:/nfs/production/panda/ensemblgenomes/apis/ensembl/81/ensembl-hive/modules:/nfs/production/panda/ensemblgenomes/development/tapanari/ensemblgenomes-api/modules:/nfs/production/panda/ensemblgenomes/apis/ensembl/81/ensembl-funcgen/modules:/nfs/production/panda/ensemblgenomes/apis/ensembl/81/ensembl-compara/modules:/nfs/production/panda/ensemblgenomes/apis/ensembl/81/ensembl-analysis/modules:/nfs/production/panda/ensemblgenomes/apis/ensembl/81/ensembl/modules:/nfs/production/panda/ensemblgenomes/apis/bioperl/run-stable:/nfs/production/panda/ensemblgenomes/apis/bioperl/stable:/nfs/panda/ensemblgenomes/development/tapanari/eg-ena/modules

# example run:
# perl track_hub_creation_and_registration_pipeline.pl -username tapanari -password testing -local_ftp_dir_path /homes/tapanari/public_html/data/test2  -http_url http://www.ebi.ac.uk/~tapanari/data/test2 > output
            # or                                                                                    #/nfs/ensemblgenomes/ftp/pub/misc_data/TrackHubs            #ftp://ftp.ensemblgenomes.org/pub/misc_data/TrackHubs 1> output 2>errors
  use strict ;
  use warnings;

  use HTTP::Tiny;
  use Getopt::Long;
  use JSON;
  use DateTime;   
  use Date::Manip;
  use LWP::UserAgent;

  my $registry_user_name ;
  my $registry_pwd ;
  my $ftp_local_path ; #you put here the path to your local dir where the files of the track hub are stored "/homes/tapanari/public_html/data/test"; # from /homes/tapanari/public_html there is a link to the /nfs/panda/ensemblgenomes/data/tapanari
  my $http_url ;  # you put here your username's URL   ie: "http://www.ebi.ac.uk/~tapanari/data/test";

  my $from_scratch; 

  my $ua = LWP::UserAgent->new;

  GetOptions(
     "username=s" => \$registry_user_name ,
     "password=s" => \$registry_pwd,
     "local_ftp_dir_path=s" => \$ftp_local_path,
     "http_url=s" => \$http_url,   #string
     "do_track_hubs_from_scratch"  => \$from_scratch# flag
  );
   
  my $server =  "http://plantain:3000/eg";  # Robert's server where he stores his REST URLs
  my $http = HTTP::Tiny->new();

  my $date_string = localtime();
  print "* Started running the pipeline on:\n";
  print "Local date,time: $date_string\n";


  print "\n* Ran this pipeline:\n\n";
  print "perl track_hub_creation_and_registration_pipeline.pl  -username $registry_user_name -password $registry_pwd -local_ftp_dir_path $ftp_local_path -http_url $http_url";
  if($from_scratch){
      print " -do_track_hubs_from_scratch\n";
  } else{
    print "\n";
  }


  print "\n* I am using this ftp server to eventually build my track hubs:\n\n $http_url\n\n";
  print "* I am using this Registry account:\n\n user:$registry_user_name \n password:$registry_pwd\n\n ";

if ($from_scratch){

  print "\n ******** deleting all track hubs registered in the Registry under my account\n\n";  
  my $delete_script_output = `perl delete_registered_trackhubs.pl -username $registry_user_name -password $registry_pwd -study_id all`  ; 
  print $delete_script_output;


 print "\n ******** deleting everything in directory $ftp_local_path\n\n";

  my $ls_output = `ls $ftp_local_path`  ;

  if($? !=0){ # if ls is successful, i get 0
 
      die "I cannot see contents of $ftp_local_path(ls failed)\n";

  }

  if(!$ls_output){  # check if there are files inside the directory

     print "Directory $ftp_local_path is empty - No need for deletion\n";

   } else{ # directory is not empty

      `rm -r $ftp_local_path/*`;  # removing the track hub files in the ftp server

      if($? !=0){
 
          print STDERR "ERROR in: track_hub_creation_and_registration_pipeline.pl failed to remove contents of dir $ftp_local_path\n";

      }else{

          print "Successfully deleted all content of $ftp_local_path\n";
      }

   }
 
}


sub getJsonResponse { # it returns the json response given the url-endpoint as param, it returns an array reference that contains hash references . If response not successful it returns 0

  my $url = shift; 

  my $response = $http->get($url); 

  if($response->{success} ==1) { # if the response is successful then I get 1

    my $content=$response->{content};      # print $response->{content}."\n"; # it prints whatever is the content of the URL, ie the jason response
    my $json = decode_json($content);      # it returns an array reference 

    return $json;

  }else{

      my ($status, $reason) = ($response->{status}, $response->{reason}); 
      print STDERR "Failed for $url! Status code: ${status}. Reason: ${reason}\n";  # if response is successful I get status "200" reason "OK"
      return 0;
  }
}

  my $rest_call_plants = "http://rest.ensemblgenomes.org/info/genomes/division/EnsemblPlants?content-type=application/json"; # to get all ensembl plants names currently

  my @array_response_plants_assemblies = @{getJsonResponse($rest_call_plants)};  

  my %assName_assAccession;
  my %assAccession_assName;
  my %ens_plant_names;

# response:
#[{"base_count":"479985347","is_reference":null,"division":"EnsemblPlants","has_peptide_compara":"1","dbname":"physcomitrella_patens_core_28_81_11","genebuild":"2011-03-JGI","assembly_level":"scaffold","serotype":null,
#"has_pan_compara":"1","has_variations":"0","name":"Physcomitrella patens","has_other_alignments":"1","species":"physcomitrella_patens","assembly_name":"ASM242v1","taxonomy_id":"3218","species_id":"1",
#"assembly_id":"GCA_000002425.1","strain":"ssp. patens str. Gransden 2004","has_genome_alignments":"1","species_taxonomy_id":"3218"},


  foreach my $hash_ref (@array_response_plants_assemblies){

         my %hash = %{$hash_ref};

         $ens_plant_names {$hash {"species"}} = 1; # there are 39 Ens plant species at the moment Nov 2015

         if(! $hash{"assembly_id"}){  # some species don't have assembly id, ie assembly accession, 3 plant species don't have assembly accession: triticum_aestivum, oryza_longistaminata and oryza_rufipogon 

             $assName_assAccession  {$hash{"assembly_name"}} =  "0000";
             next;
         }

         $assName_assAccession  {$hash{"assembly_name"} } = $hash{"assembly_id"};
         $assAccession_assName  {$hash{"assembly_id"} } = $hash{"assembly_name"};

  }

    my $get_runs_by_organism_endpoint="http://plantain:3000/eg/getLibrariesByOrganism/"; # i get all the runs by organism to date that Robert has processed so far

    my %robert_plants_done;
    my %runs; # it stores all distinct run ids
    my %studies; # it stores all distinct study ids
    my %studyId_assemblyName; # stores as key the study id and as value the ensembl assembly name ie for oryza_sativa it would be IRGSP-1.0
    my %robert_plant_study;
    my %studyId_lastProcessedDates;

# a line of this call:  http://plantain:3000/eg/getLibrariesByOrganism/oryza_sativa
#[{"STUDY_ID":"DRP000315","SAMPLE_ID":"SAMD00009891","RUN_ID":"DRR000756","ORGANISM":"oryza_sativa_japonica_group","STATUS":"Complete","ASSEMBLY_USED":"IRGSP-1.0","ENA_LAST_UPDATED":"Fri Jun 19 2015 17:39:45",
#"LAST_PROCESSED_DATE":"Sat Sep 05 2015 22:40:36","FTP_LOCATION":"ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/DRR000/DRR000756/DRR000756.cram"},

 foreach my $ens_plant (keys %ens_plant_names) { # i loop through the ensembl plant names to get from Robert all the done studies/runs

     my $url = $get_runs_by_organism_endpoint . $ens_plant;

     my @get_runs_by_organism_response = @{getJsonResponse($url)};  # i call here the method that I made above

     foreach my $hash_ref (@get_runs_by_organism_response){

         my %hash = %{$hash_ref};

         next unless($hash{"STATUS"} eq "Complete"); 

         $robert_plants_done{ $hash{"ORGANISM"} }++; 
         $robert_plant_study {$hash{"ORGANISM"} }  {$hash{"STUDY_ID"}} = 1;
         $runs {$hash{"RUN_ID"}} = 1;
         $studies {$hash {"STUDY_ID"}} = 1 ;
        
         $studyId_assemblyName { $hash {"STUDY_ID"} } { $hash {"ASSEMBLY_USED"} } = 1; # i can have more than one assembly for each study

         $studyId_lastProcessedDates { $hash {"STUDY_ID"} } { $hash {"LAST_PROCESSED_DATE"} } =1 ;  # i get different last processed dates from different the runs of the study
        
     }
}

 my %studyId_date;
 
 
 foreach my $study_id (keys %studyId_lastProcessedDates ){  #each study has more than 1 processed date, as there are usually multiple runs in each study with different processed date each. I want to get the most current date

    my $max_date=0;
    foreach my $date (keys %{$studyId_lastProcessedDates {$study_id}}){

       my $unix_time = UnixDate( ParseDate($date), "%s" );

       if($unix_time > $max_date){
           $max_date = $unix_time ;
       }
    }

    $studyId_date {$study_id} = $max_date ;

 }

  my $line_counter = 0;
  my %studies_last_run_of_pipeline;
  my %obsolete_studies;
  my %common_studies;
  my %common_updated_studies;
  my %new_studies;

  if($from_scratch) {

  print "\n ******** starting to make directories and files for the track hubs in the ftp server: $http_url\n\n";

    foreach my $study_id (keys %studyId_assemblyName){ 

         $line_counter ++;
         print "$line_counter.\tcreating track hub for study $study_id\n";
        `perl create_track_hub.pl -study_id $study_id -local_ftp_dir_path $ftp_local_path -http_url $http_url` ; # here I create for every study a track hub *********************
   }

   my $date_string2 = localtime();
   print " \n Finished creating the files,directories of the track hubs on the server on:\n";
   print "Local date,time: $date_string2\n";

   print "\n***********************************\n\n";

}else{ # incremental update
  
   opendir my($dh),  $ftp_local_path or die "Couldn't open dir ' $ftp_local_path': $!"; # i am getting all the content in the ftp local path - each name of the directory is a study id
   my @files = readdir $dh;
   closedir $dh;

   foreach my $file (@files){

      next if ($file =~/^\./); # because i get also these 2 results from the readdir : .  and ..
      $studies_last_run_of_pipeline{$file} = 1;

   }
   
   foreach my $study_id (keys %studies){ # current studies from Robert that are completed

       if(!$studies_last_run_of_pipeline{$study_id}){ # if study is not in the server, then it's a new study I have to make a track hub for
            $new_studies{$study_id} = 1;
       }else{
            $common_studies {$study_id} = 1 ;
       }

   }
   
   foreach my $study_id (keys %studies_last_run_of_pipeline){ # studies in the ftp server from last time I ran the pipeline

       if(!$studies{$study_id}){ # if study is in the server but not in the current list of Robert it means that this study is removed from ENA
            $obsolete_studies{$study_id} = 1;
       }
   }

   if(scalar (keys %obsolete_studies) >0){
      print "**********starting to delete obsolete track hubs from the trackHub Registry and the server:\n\n";
   }else{
      print "\nThere are not any obsolete track hubs to be removed since the last time the pipeline was ran.\n";
   }

   foreach my $study_to_remove (keys %obsolete_studies){

        `rm -r $ftp_local_path/$study_to_remove` ;  # removal from the server
         if($? ==0){ # if rm is successful, i get 0
 
           print "$study_to_remove successfully deleted from the server\n";

         }else{
           print "$study_to_remove could not be deleted from the server\n";
         }
        `perl delete_registered_trackhubs.pl -study_id $study_to_remove  -username $registry_user_name  -password $registry_pwd -study_id  $study_to_remove`; #removal from the registry
 
   }

   foreach my $common_study (keys %common_studies){  # from the common studies, I want to see which ones were updated from Robert , after I last ran the pipeline. I will update only those ones.
 
         my $roberts_last_processed_unix_time = $studyId_date {$common_study};

         my $ftp_location_of_study = $http_url ."/$common_study/"; # i want to find the date I last ran the pipeline, I want to get the date from the created date of the files in the ftp server of the track hubs
         my $index = $ua->get($ftp_location_of_study); 
         my $string = $index->decoded_content;
         #-rw-r--r--    1 ftp      ftp           343 Nov 03 16:41 hub.txt

         $string =~/.+ (\w+ \d{2} \d+:\d+) hub.txt/;

         my $date=$1 ; #Nov 03 16:41

         my $study_created_date_unix_time = UnixDate( ParseDate($date), "%s" );

         if( $study_created_date_unix_time < $roberts_last_processed_unix_time ) {

              $common_updated_studies {$common_study}=1;
         }
   }

   
}

    my %studies_to_be_re_made = (%common_updated_studies , %new_studies);

    if(scalar keys %studies_to_be_re_made !=0){


       print "\n ******** starting to make directories and files for the track hubs in the ftp server that are new/updated: $http_url\n\n";
       $line_counter = 0;

       foreach my $study_id (keys %studies_to_be_re_made){ 

         $line_counter ++;
         print "$line_counter.\tcreating track hub for study $study_id";
         if ($new_studies{$study_id}){
           print " (new study)";
         }
         print "\n";
                
        `rm -r $ftp_local_path/$study_id`; # i first remove it from the server to re-do it
        `perl create_track_hub.pl -study_id $study_id -local_ftp_dir_path $ftp_local_path -http_url $http_url` ; # here I create for every study a track hub *********************
       }

       my $date_string2 = localtime();
       print " \n Finished creating the files,directories of the track hubs on the server on:\n";
       print "Local date,time: $date_string2\n";

        print "\n***********************************\n\n";
    }else{
            if(!$from_scratch){
               print "\nThere are no updated or new tracks to be made from the last time the pipeline was ran.\n";
            }
    }

    my $line_counter2 = 0;

    my %studies_to_register;

    if(!$from_scratch){
 
        %studies_to_register= %studies_to_be_re_made ;

    }else{

        %studies_to_register = %studyId_assemblyName ;
    }

    foreach my $study_id (keys %studies_to_register){ 

          my $hub_txt_url = $http_url . "/" . $study_id . "/hub.txt" ;
           
          my @assembly_names_with_accessions;
      
          foreach my $assembly_name ( keys % {$studyId_assemblyName{$study_id}}) {   # from Robert's data , get runs by organism REST call                           
         
               $assembly_name = getRightAssemblyName($assembly_name); # as Robert gets the assembly.default that due to our bug could be the assembly.accession rather than the assembly.name

               if(!$assName_assAccession{$assembly_name}){ # from ensemblgenomes data

                   print STDERR "ERROR: study $study_id will not be Registered as there is no assembly name \'$assembly_name\' (Robert's call) of study $study_id in my hash from ensemblgenomes REST call: $rest_call_plants \n\n";
                   next;  # this is for potato (solanum_tuberosum that has an invalid assembly.default name)
               }
               push ( @assembly_names_with_accessions, $assembly_name) ; # this array has only the assembly names that have assembly accessions

          }

          my @array_string_pairs;

          foreach my $assembly_name ( @assembly_names_with_accessions ){

               my $string =  $assembly_name.",".$assName_assAccession{$assembly_name} ;
               push (@array_string_pairs , $string);

          }

          my $assemblyNames_assemblyAccesions_string;

          if (scalar @array_string_pairs >=1 ){

             $assemblyNames_assemblyAccesions_string=$array_string_pairs[0];

          } else{

          
              $assemblyNames_assemblyAccesions_string="empty";
          }

          if (scalar @array_string_pairs > 1){

              $assemblyNames_assemblyAccesions_string=$array_string_pairs[0].",";

              for(my $index=1; $index< scalar @array_string_pairs; $index++){

               $assemblyNames_assemblyAccesions_string=$assemblyNames_assemblyAccesions_string.$array_string_pairs[$index];

               if ($index < scalar @array_string_pairs -1){

                  $assemblyNames_assemblyAccesions_string = $assemblyNames_assemblyAccesions_string .",";
               }
               
             }
          }
 
          #next if ($assemblyNames_assemblyAccesions_string eq "empty"); # i can't put it in the registry if there is no assembly accession

          my $output = `perl register_track_hub.pl -username $registry_user_name -password $registry_pwd -hub_txt_file_location $hub_txt_url -assembly_name_accession_pairs $assemblyNames_assemblyAccesions_string` ;  # here I register every track hub in the Registry*********************
          if($output =~ /is Registered/){

                 $line_counter2 ++;
                 print $line_counter2.". ";
          }

          print $output;

    } #************************************************************************************


    my $dt = DateTime->today;

    my $date_wrong_order = $dt->date;  # it is in format 2015-10-01
    # i want 01-10-2015

    my @words = split(/-/, $date_wrong_order);
    my $current_date = $words[2] . "-". $words[1]. "-". $words[0];  # ie 01-10-2015 (1st October)

    print "\n\nRobert's REST calls give the following stats:\n";
    print "\nThere are " . scalar (keys %runs) ." plant runs completed to date ( $current_date )\n";
    print "\nThere are " .scalar (keys %studies) ." plant studies completed to date ( $current_date )\n";

    print "\n****** Plants done to date: ******\n\n";

    my $counter_ens_plants = 0 ; 
    my $index = 0;

    foreach my $plant (keys %robert_plants_done){

            if($ens_plant_names {$plant}){
               $counter_ens_plants++;
               print " * " ;
            }
            $index++;
            print $index.". ".$plant." =>\t". $robert_plants_done{$plant}." runs / ". scalar ( keys ( %{$robert_plant_study{$plant}} ) )." studies\n";

    }
    print "\n";


  print "In total there are " .$counter_ens_plants . " Ensembl plants done to date.\n\n";


  my $date_string_end = localtime();
  print " Finished running the pipeline on:\n";
  print "Local date,time: $date_string_end\n";


  my $total_disc_space_of_track_hubs = `du -sh $ftp_local_path`;
  
  print "\ntotal disc space occupied in $ftp_local_path is:\n $total_disc_space_of_track_hubs\n";


### methods used 

sub getRightAssemblyName { # this method returns the right assembly name in the cases where Robert takes the assembly accession instead of the assembly name due to our bug

   my $assembly_string = shift;
   my $assembly_name;


   if (!$assName_assAccession{$assembly_string}){

        if(!$assAccession_assName{$assembly_string}) {  # solanum_tuberosum has a wrong assembly.default it's neither the assembly.name nor the assembly.accession BUT : "assembly_name":"SolTub_3.0" and "assembly_id":"GCA_000226075.1"

           $assembly_name = $assembly_string;
 
        }else{
           $assembly_name = $assAccession_assName{$assembly_string};
        }
   }else{
        $assembly_name = $assembly_string;
   }

   if($assembly_string eq "3.0"){ # this is an exception for solanum_tuberosum
      $assembly_name = "SolTub_3.0";
   }
   return $assembly_name;

}