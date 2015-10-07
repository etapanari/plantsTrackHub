
# it needs before run:
# # source /nfs/panda/ensemblgenomes/apis/ensembl/81/setup.sh
# in this script I am getting from array express REST API all studies to date and create my track hubs, or make stats

# example run:
# perl get_all_studies.pl /homes/tapanari/public_html/data/test  http://www.ebi.ac.uk/~tapanari/data/test

  use strict ;
  use warnings;
  use Data::Dumper;

  use HTTP::Tiny;
  use JSON;

  my $ftp_dir_full_path = $ARGV[0];   #you put here the path to your local dir where the files of the track hub are stored "/homes/tapanari/public_html/data/test"; # from /homes/tapanari/public_html there is a link to the /nfs/panda/ensemblgenomes/data/tapanari
  my $http_url = $ARGV[1];  # you put here your username's URL   ie: "http://www.ebi.ac.uk/~tapanari/data/test";
   
  my $server =  "http://plantain:3000/eg"; #or could be $ARGV[2]; # Robert's server where he stores his REST URLs

  my $http = HTTP::Tiny->new();


  use DateTime;

  my $dt = DateTime->today;

  my $date_wrong_order = $dt->date;  # it is in format 2015-10-01
  # i want 01-10-2015

  my @words = split(/-/, $date_wrong_order);
  my $current_date = $words[2] . "-". $words[1]. "-". $words[0];  # now it is 01-10-2015 (1st October)


sub getJsonResponse { # it returns the json response given the endpoint as param, it returns an array reference that contains hash references . If response not successful it returns 0

  my $url = shift; 

  my $response = $http->get($url); 

  if($response->{success} ==1) { # if the response is successful then I get 1

    my $content=$response->{content};      # print $response->{content}."\n"; # it prints whatever is the content of the URL, ie the jason response
    my $json = decode_json($content);      # it returns an array reference 

    return $json;

  }else{

      my ($status, $reason) = ($response->{status}, $response->{reason}); #LWP perl library for dealing with http
      print "Failed for $url! Status code: ${status}. Reason: ${reason}\n";  # if response is successful I get status "200" reason "OK"
      return 0;
  }
}

  my $rest_call_plants="http://rest.ensemblgenomes.org/info/genomes/division/EnsemblPlants?content-type=application/json";

  my @array_response_plants_assemblies = @{getJsonResponse($rest_call_plants)};  # i call here the method that I made above

  my %assName_assAccession;
  my %ens_plant_names;

# response:
#[{"base_count":"479985347","is_reference":null,"division":"EnsemblPlants","has_peptide_compara":"1","dbname":"physcomitrella_patens_core_28_81_11","genebuild":"2011-03-JGI","assembly_level":"scaffold","serotype":null,
#"has_pan_compara":"1","has_variations":"0","name":"Physcomitrella patens","has_other_alignments":"1","species":"physcomitrella_patens","assembly_name":"ASM242v1","taxonomy_id":"3218","species_id":"1",
#"assembly_id":"GCA_000002425.1","strain":"ssp. patens str. Gransden 2004","has_genome_alignments":"1","species_taxonomy_id":"3218"},


  foreach my $hash_ref (@array_response_plants_assemblies){

         my %hash = %{$hash_ref};

         if(! $hash{"assembly_id"}){  # some species don't have assembly id, ie accession

             $assName_assAccession  {$hash{"assembly_name"}} =  "missing assembly accession";
             $ens_plant_names {$hash {"species"}} = 1;
             next;
         }

         $assName_assAccession  {$hash{"assembly_name"} } = $hash{"assembly_id"};
         $ens_plant_names {$hash {"species"}} = 1;

  }

#   foreach my $asse_name (keys %assName_assAccession) {
# 
#        foreach my $plant (keys %{$assName_assAccession{$asse_name}}){
# 
#              print $plant . "\t". $asse_name . "\t". $assName_assAccession{$asse_name}{$plant}."\n";
#        }
#   }
# 
# 
#   __END__

    my $get_runs_by_organism_endpoint="http://plantain:3000/eg/getLibrariesByOrganism/"; # i get all the runs by organism to date

    my %plants_done;
    my %runs; # it stores all distinct run ids
    my %studies; # it stores all distinct study ids
    my %studyId_assemblyName; # stores as key the study id and as value the ensembl assembly name ie for oryza_sativa it would be IRGSP-1.0
    my %plant_study;

# a line of this call:  http://plantain:3000/eg/getLibrariesByOrganism/oryza_sativa
#[{"STUDY_ID":"DRP000315","SAMPLE_ID":"SAMD00009891","RUN_ID":"DRR000756","ORGANISM":"oryza_sativa_japonica_group","STATUS":"Complete","ASSEMBLY_USED":"IRGSP-1.0","ENA_LAST_UPDATED":"Fri Jun 19 2015 17:39:45",
#"LAST_PROCESSED_DATE":"Sat Sep 05 2015 22:40:36","FTP_LOCATION":"ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/DRR000/DRR000756/DRR000756.cram"},

 foreach my $ens_plant (keys %ens_plant_names) {

     my $url = $get_runs_by_organism_endpoint . $ens_plant;

     my @array_response = @{getJsonResponse($url)};  # i call here the method that I made above

     foreach my $hash_ref (@array_response){

         my %hash = %{$hash_ref};

         next unless($hash{"STATUS"} eq "Complete"); 

         $plants_done{ $hash{"ORGANISM"} }++; 
         $plant_study {$hash{"ORGANISM"} }  {$hash{"STUDY_ID"}} = 1;
         $runs {$hash{"RUN_ID"}} = 1;
         $studies {$hash {"STUDY_ID"}} = 1 ;
        
         $studyId_assemblyName { $hash {"STUDY_ID"} } { $hash {"ASSEMBLY_USED"} } = 1; # i can have more than one assembly for each study
        
     }
}

    foreach my $study_id (keys %studyId_assemblyName){ 

 
          print "creating track hub for study $study_id\n";
         `perl create_track_hub_pipeline.pl $study_id $ftp_dir_full_path $http_url` ; # here I create for every study a track hub *********************

          my $hub_txt_url = $http_url . "/" . $study_id . "/hub.txt" ;
           
          my @assembly_names;
      
          foreach my $assembly_name ( keys % {$studyId_assemblyName{$study_id}}) {   # from Robert's data                            
         
               if(!$assName_assAccession{$assembly_name}){ # from ensemblgenomes data
                   print "there is no such assembly name as $assembly_name in my hash from ensemblgenomes REST call: $rest_call_plants \n";
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

          #print $study_id."\t".$assemblyNames_assemblyAccesions_string."\n";
          my $output = `perl trackHubRegistry.pl testing $hub_txt_url $study_id $assemblyNames_assemblyAccesions_string` ;  # here I register every track hub in the Registry*********************
          print $output ;

    } #************************************************************************************

    print "\nThere are " . scalar (keys %runs) ." plant runs completed to date ( $current_date )\n";
    print "\nThere are " .scalar (keys %studies) ." plant studies completed to date ( $current_date )\n";

    print "\n****** Plants done to date: ******\n\n";

    foreach my $plant (keys %plants_done){

            print $plant." =>\t". $plants_done{$plant}." runs of ". scalar ( keys ( %{$plant_study{$plant}} ) )." studies\n";

    }
    print "\n";

     print "In total there are " . scalar (keys %plants_done) . " plants done to date.\n\n";

