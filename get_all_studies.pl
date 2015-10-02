

# in this script I am getting from array express REST API all studies to date and create my track hubs, or make stats

  use strict ;
  use warnings;
  use Data::Dumper;

  use HTTP::Tiny;
  use JSON;

  #my $study_id = $ARGV[0];
  #my $ftp_dir_full_path = $ARGV[1];   #you put here the path to your local dir where the files of the track hub are stored "/homes/tapanari/public_html/data/test"; # from /homes/tapanari/public_html there is a link to the /nfs/panda/ensemblgenomes/data/tapanari
  #my $url_root = $ARGV[2];  # you put here your username's URL   ie: "http://www.ebi.ac.uk/~tapanari/data/test";
   
  my $server =  "http://plantain:3000/eg"; #or could be $ARGV[3]; # Robert's server where he stores his REST URLs

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


# ftp://ftp.ensemblgenomes.org/pub/current/plants/species_EnsemblPlants.txt -> this is where all plant species are stored in the current release

# first 2 lines of the above file:
#name	species	division	taxonomy_id	assembly	assembly_accession	genebuild	variation	pan_compara	peptide_compara	genome_alignments	other_alignments	core_db	species_id
#Aegilops tauschii	aegilops_tauschii	EnsemblPlants	37682	ASM34733v1	GCA_000347335.1	2014-05-BGI	N	N	Y	Y	Y	aegilops_tauschii_core_28_81_1	1	

     my %all_ens_plants;
     my %plants_done;
 

   if (-e "species_EnsemblPlants.txt") { # if the file exists , rm and get it again to make sure that you have the latest set of plants

     `rm "species_EnsemblPlants.txt"` ;

   }

   `wget ftp://ftp.ensemblgenomes.org/pub/current/plants/species_EnsemblPlants.txt`;

   open(IN, "species_EnsemblPlants.txt") or die "Can't open species_EnsemblPlants.txt\n";

        while(<IN>){

           chomp;
           next if($_=~/^#/); # i skip the comments 
           my @words = split(/\t/, $_);
           $all_ens_plants {$words[1]} = 1;

        }

   close(IN);

    
    my $get_runs_by_organism_endpoint="/getLibrariesByOrganism/"; # i get all the runs by organism to date

    my %runs; # it stores all distinct run ids
    my %studies; # it stores all distinct study ids

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
     }
}

    print "\nThere are " . scalar (keys %runs) ." plant runs completed to date ( $current_date )\n";
    print "\nThere are " .scalar (keys %studies) ." plant studies completed to date ( $current_date )\n";

    print "\n****** Plants done to date: ******\n\n";

    foreach my $plant (keys %plants_done){

            print $plant." =>\t". $plants_done{$plant}." runs \n";

    }
    print "\n";

    print "In total there are " . scalar (keys %plants_done) . " plants done to date.\n\n";

