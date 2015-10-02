
# it needs before run:
# # source /nfs/panda/ensemblgenomes/apis/ensembl/81/setup.sh
# in this script I am getting from array express REST API all studies to date and create my track hubs, or make stats

# example run:
# perl get_all_studies.pl /homes/tapanari/public_html/data/test  http://www.ebi.ac.uk/~tapanari/data/test

  use strict ;
  use warnings;
  use Data::Dumper;
  use Bio::EnsEMBL::Registry;

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

  my $endpoint = shift; # example endpoint: "getLibrariesByStudyId/SRP033494";
  my $url = $server.$endpoint;

  my $response = $http->get($url); 

  if($response->{success} ==1) { # if the response is successful then I get 1

    my $content=$response->{content};      # print $response->{content}."\n"; # it prints whatever is the content of the URL, ie the jason response
    my $json = decode_json($content);      # it returns an array reference 

    return $json;

  }else{

      my ($status, $reason) = ($response->{status}, $response->{reason}); #LWP perl library for dealing with http
      print "Failed for $endpoint! Status code: ${status}. Reason: ${reason}\n";  # if response is successful I get status "200" reason "OK"
      return 0;
  }
}

sub getJsonResponse2 { # it returns the json response given the endpoint as param, it returns an array reference that contains hash references . If response not successful it returns 0

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
# ftp://ftp.ensemblgenomes.org/pub/current/plants/species_EnsemblPlants.txt -> this is where all plant species are stored in the current release

# first 2 lines of the above file:
#name	species	division	taxonomy_id	assembly	assembly_accession	genebuild	variation	pan_compara	peptide_compara	genome_alignments	other_alignments	core_db	species_id
#Aegilops tauschii	aegilops_tauschii	EnsemblPlants	37682	ASM34733v1	GCA_000347335.1	2014-05-BGI	N	N	Y	Y	Y	aegilops_tauschii_core_28_81_1	1	 

   if (-e "species_EnsemblPlants.txt") { # if the file exists , remove it and get it again to make sure that you have the latest set of plants

     `rm "species_EnsemblPlants.txt"` ;

   }

   `wget ftp://ftp.ensemblgenomes.org/pub/current/plants/species_EnsemblPlants.txt`;

     my %all_ens_plants;

   open(IN, "species_EnsemblPlants.txt") or die "Can't open species_EnsemblPlants.txt\n";

        while(<IN>){

           chomp;
           next if($_=~/^#/); # i skip the comments 
           my @words = split(/\t/, $_);
           $all_ens_plants {$words[1]} = 1;

        }

   close(IN);

    
    my $get_runs_by_organism_endpoint="/getLibrariesByOrganism/"; # i get all the runs by organism to date

    my %plants_done;
    my %runs; # it stores all distinct run ids
    my %studies; # it stores all distinct study ids
    my %study_assembly_name; # stores as key the study id and as value the ensembl assembly name ie for oryza_sativa it would be IRGSP-1.0

# a line of this call:  http://plantain:3000/eg/getLibrariesByOrganism/oryza_sativa
#[{"STUDY_ID":"DRP000315","SAMPLE_ID":"SAMD00009891","RUN_ID":"DRR000756","ORGANISM":"oryza_sativa_japonica_group","STATUS":"Complete","ASSEMBLY_USED":"IRGSP-1.0","ENA_LAST_UPDATED":"Fri Jun 19 2015 17:39:45",
#"LAST_PROCESSED_DATE":"Sat Sep 05 2015 22:40:36","FTP_LOCATION":"ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/DRR000/DRR000756/DRR000756.cram"},

 foreach my $ens_plant (keys %all_ens_plants) {

     my $url = $get_runs_by_organism_endpoint . $ens_plant;

     my @array_response = @{getJsonResponse($url)};  # i call here the method that I made above

     foreach my $hash_ref (@array_response){

         my %hash = %{$hash_ref};

         next unless($hash{"STATUS"} eq "Complete"); 

         $plants_done{ $hash{"ORGANISM"} }++; 
         $runs {$hash{"RUN_ID"}} = 1;
         $studies {$hash {"STUDY_ID"}} = 1 ;

         #print $hash {"STUDY_ID"} . "\t" . $hash {"RUN_ID"} . "\t". $hash {"ORGANISM"} ."\n";
         
         $study_assembly_name { $hash {"STUDY_ID"} } {$hash {"ASSEMBLY_USED"} }= $hash {"ORGANISM"};
        
     }
}

#    foreach my $key (keys %study_assembly_name) {
# 
#        foreach my $key2   (keys %{$study_assembly_name{$key}}){
# 
#                 print $key ."\t". $key2 ."\n";
# 
#        }
# 
#   }


    my $registry = 'Bio::EnsEMBL::Registry';

    $registry->load_registry_from_db(
     -host       => 'mysql-eg-staging-1.ebi.ac.uk',
     -port       =>  4160,
     -user       => 'ensro',
     -db_version => '81',
    );




    foreach my $study_id (keys %study_assembly_name){ 

         `perl create_track_hub_pipeline.pl $study_id $ftp_dir_full_path $http_url` ; # here I create for every study a track hub *********************

          my $hub_txt_url = $http_url . "/" . $study_id . "/hub.txt" ;

          foreach my $assembly (keys %{$study_assembly_name{$study_id}}){
           
             my $species_name = $study_assembly_name{$study_id} {$assembly};

             #my $meta_container = $registry->get_adaptor( $species_name, 'Core', 'MetaContainer' );
             #my $assembly_accession = $meta_container->single_value_by_key('assembly.accession');       

              my $assembly_url =  "http://rest.ensemblgenomes.org/info/genomes/division/EnsemblPlants?content-type=application/json" ;
# reply:
#[{"base_count":"479985347","is_reference":null,"division":"EnsemblPlants","has_peptide_compara":"1","dbname":"physcomitrella_patens_core_28_81_11","genebuild":"2011-03-JGI","assembly_level":"scaffold",
#"serotype":null,"has_pan_compara":"1","has_variations":"0","name":"Physcomitrella patens","has_other_alignments":"1","species":"physcomitrella_patens","assembly_name":"ASM242v1","taxonomy_id":"3218","species_id":"1",
#"assembly_id":"GCA_000002425.1","strain":"ssp. patens str. Gransden 2004","has_genome_alignments":"1","species_taxonomy_id":"3218"},
 
             my @array_rest=@{getJsonResponse2($assembly_url)}; 
             my $assembly_accession;
  
          foreach my $hash_ref (@array_rest){

                my %hash = %{$hash_ref};

                if($hash{"species"} eq $species_name ){

                   $assembly_accession = $hash {"assembly_id"}; 
                }
             }
             #print "$species_name\t$study_id\t$assembly\t$assembly_accession\n";
              next unless ($assembly_accession) ;
             `perl trackHubRegistry.pl ensemblplants $hub_txt_url $assembly $assembly_accession` ;  # here I register every track hub in the Registry*********************
              print "track hub $study_id registerd successfully\n";
          }
    } #************************************************************************************



    print "\nThere are " . scalar (keys %runs) ." plant runs completed to date ( $current_date )\n";
    print "\nThere are " .scalar (keys %studies) ." plant studies completed to date ( $current_date )\n";

    print "\n****** Plants done to date: ******\n\n";

    foreach my $plant (keys %plants_done){

            print $plant." =>\t". $plants_done{$plant}." runs \n";

    }
    print "\n";

    print "In total there are " . scalar (keys %plants_done) . " plants done to date.\n\n";

