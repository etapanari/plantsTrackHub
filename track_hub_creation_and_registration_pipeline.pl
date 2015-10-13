
# it needs before run:
# # source /nfs/panda/ensemblgenomes/apis/ensembl/81/setup.sh
# in this script I am getting from array express REST API all studies to date and create my track hubs, or make stats

# example run:
# perl get_all_studies.pl -username tapanari -password testing -local_ftp_dir_path /homes/tapanari/public_html/data/test2  -http_url http://www.ebi.ac.uk/~tapanari/data/test2

  use strict ;
  use warnings;
  use Data::Dumper;

  use HTTP::Tiny;
  use JSON;
  use Getopt::Long;

  my $registry_user_name ;
  my $registry_pwd ;
  my $ftp_dir_full_path ; #you put here the path to your local dir where the files of the track hub are stored "/homes/tapanari/public_html/data/test"; # from /homes/tapanari/public_html there is a link to the /nfs/panda/ensemblgenomes/data/tapanari
  my $http_url ;  # you put here your username's URL   ie: "http://www.ebi.ac.uk/~tapanari/data/test";


  GetOptions(
     "username=s" => \$registry_user_name ,
     "password=s" => \$registry_pwd,
     "local_ftp_dir_path=s" => \$ftp_dir_full_path,
     "http_url=s" => \$http_url
  );
   
  my $server =  "http://plantain:3000/eg"; #or could be $ARGV[2]; # Robert's server where he stores his REST URLs

  my $http = HTTP::Tiny->new();


  use DateTime;

  my $dt = DateTime->today;

  my $date_wrong_order = $dt->date;  # it is in format 2015-10-01
  # i want 01-10-2015

  my @words = split(/-/, $date_wrong_order);
  my $current_date = $words[2] . "-". $words[1]. "-". $words[0];  # ie 01-10-2015 (1st October)


  my $date_string = localtime();
  print "* Started running the pipeline on:\n";
  print "Local date,time: $date_string\n";


  print "\n* Ran this pipeline:\n\n";
  print "perl get_all_studies.pl -username $registry_user_name -password $registry_pwd -local_ftp_dir_path $ftp_dir_full_path  -http_url $http_url\n";

  print "\n* I am using this ftp server to eventually build my track hubs:\n\n $http_url\n\n";
  print "* I am using this Registry account:\n\n user:$registry_user_name \n password: $registry_pwd\n\n ";

  print "\n ******** deleting all track hubs registered in the Registry under my account\n\n";  
  my $delete_script_output = `perl delete_registered_trackhubs.pl -username $registry_user_name -password $registry_pwd` ; 
  print $delete_script_output;

  if (! -e $ftp_dir_full_path ){  # if the directory does not exist, make it

   print "directory \'$ftp_dir_full_path\' does not exist, I will make it now..\n\n";

    `mkdir $ftp_dir_full_path`; 

     if($? !=0){
 
          die "I could not create directory \'$ftp_dir_full_path\'\n";

     }else{
          print "Successfully created directory \'$ftp_dir_full_path\'\n";
     }

  }

  print "\n ******** deleting everything in directory $ftp_dir_full_path\n\n";


  my $ls_output = `ls $ftp_dir_full_path`  ;

  if($? !=0){
 
      die "I cannot see contents of $ftp_dir_full_path (ls failed)\n";

  }

  if(!$ls_output){  # check if there are files inside the directory

     print "Directory $ftp_dir_full_path is empty - No need for deletion\n";

   } else{ # directory is not empty

      `rm -r $ftp_dir_full_path/*`;  # removing the track hub files in the ftp server

      if($? !=0){
 
          print STDERR "ERROR in: track_hub_creation_and_registration_pipeline.pl failed to remove contents of dir $ftp_dir_full_path\n";

      }else{

          print "Successfully deleted all content of $ftp_dir_full_path\n";
      }

   }
 

sub getJsonResponse { # it returns the json response given the endpoint as param, it returns an array reference that contains hash references . If response not successful it returns 0

  my $url = shift; 

  my $response = $http->get($url); 

  if($response->{success} ==1) { # if the response is successful then I get 1

    my $content=$response->{content};      # print $response->{content}."\n"; # it prints whatever is the content of the URL, ie the jason response
    my $json = decode_json($content);      # it returns an array reference 

    return $json;

  }else{

      my ($status, $reason) = ($response->{status}, $response->{reason}); #LWP perl library for dealing with http
      print STDERR "Failed for $url! Status code: ${status}. Reason: ${reason}\n";  # if response is successful I get status "200" reason "OK"
      return 0;
  }
}

  my $rest_call_plants = "http://rest.ensemblgenomes.org/info/genomes/division/EnsemblPlants?content-type=application/json"; # to get all ensembl plants names currently

  my @array_response_plants_assemblies = @{getJsonResponse($rest_call_plants)};  

  my %assName_assAccession;
  my %ens_plant_names;

# response:
#[{"base_count":"479985347","is_reference":null,"division":"EnsemblPlants","has_peptide_compara":"1","dbname":"physcomitrella_patens_core_28_81_11","genebuild":"2011-03-JGI","assembly_level":"scaffold","serotype":null,
#"has_pan_compara":"1","has_variations":"0","name":"Physcomitrella patens","has_other_alignments":"1","species":"physcomitrella_patens","assembly_name":"ASM242v1","taxonomy_id":"3218","species_id":"1",
#"assembly_id":"GCA_000002425.1","strain":"ssp. patens str. Gransden 2004","has_genome_alignments":"1","species_taxonomy_id":"3218"},


  foreach my $hash_ref (@array_response_plants_assemblies){

         my %hash = %{$hash_ref};

         if(! $hash{"assembly_id"}){  # some species don't have assembly id, ie assembly accession

             $assName_assAccession  {$hash{"assembly_name"}} =  "missing assembly accession";
             $ens_plant_names {$hash {"species"}} = 1;
             next;
         }

         $assName_assAccession  {$hash{"assembly_name"} } = $hash{"assembly_id"};
         $ens_plant_names {$hash {"species"}} = 1;

  }

    my $get_runs_by_organism_endpoint="http://plantain:3000/eg/getLibrariesByOrganism/"; # i get all the runs by organism to date

    my %robert_plants_done;
    my %runs; # it stores all distinct run ids
    my %studies; # it stores all distinct study ids
    my %studyId_assemblyName; # stores as key the study id and as value the ensembl assembly name ie for oryza_sativa it would be IRGSP-1.0
    my %robert_plant_study;

# a line of this call:  http://plantain:3000/eg/getLibrariesByOrganism/oryza_sativa
#[{"STUDY_ID":"DRP000315","SAMPLE_ID":"SAMD00009891","RUN_ID":"DRR000756","ORGANISM":"oryza_sativa_japonica_group","STATUS":"Complete","ASSEMBLY_USED":"IRGSP-1.0","ENA_LAST_UPDATED":"Fri Jun 19 2015 17:39:45",
#"LAST_PROCESSED_DATE":"Sat Sep 05 2015 22:40:36","FTP_LOCATION":"ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/DRR000/DRR000756/DRR000756.cram"},

 foreach my $ens_plant (keys %ens_plant_names) {

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
        
     }
}

    my $line_counter = 0;

  print "\n ******** starting to make directories and files for the track hubs in the ftp server: $http_url\n\n";

    foreach my $study_id (keys %studyId_assemblyName){ 

          $line_counter ++;
          print "$line_counter.\tcreating track hub for study $study_id\n";
         `perl create_track_hub.pl -study_id $study_id -local_ftp_dir_path $ftp_dir_full_path -http_url $http_url` ; # here I create for every study a track hub *********************
   }

   my $date_string2 = localtime();
   print " \nJust finished creating the files and directories of the track hubs in the server on:\n";
   print "Local date and time: $date_string2\n";

    print "\n***********************************\n\n";

    my $line_counter2 = 0;

    foreach my $study_id (keys %studyId_assemblyName){ 

          my $hub_txt_url = $http_url . "/" . $study_id . "/hub.txt" ;
           
          my @assembly_names;
      
          foreach my $assembly_name ( keys % {$studyId_assemblyName{$study_id}}) {   # from Robert's data , get runs by organism REST call                           
         
               if(!$assName_assAccession{$assembly_name}){ # from ensemblgenomes data
                   print STDERR " ERROR : there is no assembly name \'$assembly_name\' in my hash from ensemblgenomes REST call: $rest_call_plants \n";
                   next;
               }
               next if($assName_assAccession{$assembly_name} eq "missing assembly accession"); # i dont need the assembly names if there is no assembly accession as I cannot load the track hub in the Registry without assembly accession
               push ( @assembly_names, $assembly_name) ; # this array has only the assembly names that have assembly accessions

          }
          my $assemblyNames_assemblyAccesions_string="empty" ;
          my $counter=0;

          foreach my $assembly_name ( @assembly_names ){

               $counter ++;

               my $string =  $assembly_name.",".$assName_assAccession{$assembly_name} ;

               if (scalar @assembly_names ==1 ){

                     $assemblyNames_assemblyAccesions_string = $string ;

               }else{

                    if($counter == 1){

                       $assemblyNames_assemblyAccesions_string = $string ;

                    }else{

                       $assemblyNames_assemblyAccesions_string = $assemblyNames_assemblyAccesions_string ."," . $string;

                   }
               }

          }



          next if ($assemblyNames_assemblyAccesions_string eq "empty"); # i can't put it in the registry if there is no assembly accession

          my $output = `perl register_track_hub.pl -username $registry_user_name -password $registry_pwd -hub_txt_file_location $hub_txt_url -hub_name $study_id -assembly_name_accession_pairs $assemblyNames_assemblyAccesions_string` ;  # here I register every track hub in the Registry*********************
          if($output =~ /is Registered/){

                 $line_counter2 ++;
                 print $line_counter2.". ";
          }

          print $output;

    } #************************************************************************************

    print "\n\nRobert's REST calls give the following stats:\n";
    print "\nThere are " . scalar (keys %runs) ." plant runs completed to date ( $current_date )\n";
    print "\nThere are " .scalar (keys %studies) ." plant studies completed to date ( $current_date )\n";

    print "\n****** Plants done to date: ******\n\n";

    my $counter_ens_plants = 0 ; 
    my $index = 0;

    foreach my $plant (keys %robert_plants_done){

            if($ens_plant_names {$plant}){
               $counter_ens_plants++;
            }
            $index++;
            print $index.". ".$plant." =>\t". $robert_plants_done{$plant}." runs / ". scalar ( keys ( %{$robert_plant_study{$plant}} ) )." studies\n";

    }
    print "\n";


     print "In total there are " .$counter_ens_plants . " Ensembl plants done to date.\n\n";


  my $date_string_end = localtime();
  print " Finished running the pipeline on:\n";
  print "Local date,time: $date_string_end\n";


  my $total_disc_space_of_track_hubs = `du -sh $ftp_dir_full_path`;
  
  print "\ntotal disc space occupied in $ftp_dir_full_path is:\n $total_disc_space_of_track_hubs\n";