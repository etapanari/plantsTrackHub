

# in this script I am getting from array express REST API all studies to date and create my track hubs, or make stats

  use strict ;
  use warnings;
  use Data::Dumper;

  use HTTP::Tiny;
  use JSON;

  #Robert's example REST API call response
  #http://plantain:3000/eg/getLibrariesByStudyId/SRP033494

  my $study_id = $ARGV[0];
  my $ftp_dir_full_path = $ARGV[1];   #you put here the path to your local dir where the files of the track hub are stored "/homes/tapanari/public_html/data/test"; # from /homes/tapanari/public_html there is a link to the /nfs/panda/ensemblgenomes/data/tapanari
  my $url_root = $ARGV[2];  # you put here your username's URL   ie: "http://www.ebi.ac.uk/~tapanari/data/test";
   
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

# first lines of the above file:
#name	species	division	taxonomy_id	assembly	assembly_accession	genebuild	variation	pan_compara	peptide_compara	genome_alignments	other_alignments	core_db	species_id
#Aegilops tauschii	aegilops_tauschii	EnsemblPlants	37682	ASM34733v1	GCA_000347335.1	2014-05-BGI	N	N	Y	Y	Y	aegilops_tauschii_core_28_81_1	1	
#Amborella trichopoda	amborella_trichopoda	EnsemblPlants	13333	AMTR1.0	GCA_000471905.1	2013-10-AGD	N	Y	Y	Y	N	amborella_trichopoda_core_28_81_1	1	
#Arabidopsis lyrata	arabidopsis_lyrata	EnsemblPlants	81972	v.1.0	GCA_000004255.1	2008-12-JGI	N	N	Y	Y	Y	arabidopsis_lyrata_core_28_81_10	1	
#Arabidopsis thaliana	arabidopsis_thaliana	EnsemblPlants	3702	TAIR10	GCA_000001735.1	2010-09-TAIR	Y	Y	Y	Y	Y	arabidopsis_thaliana_core_28_81_10	1	

     my %all_ens_plants;
     my %plants_done;

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

    my %runs; # it stores all distinct assembly names for a given study
    my %studies; # it stores as key the run id and value the location in the ftp server of arrayexpress

# a line of this call:  http://plantain:3000/eg/getCompletedLibrariesByDate/28-09-2015
#[{"STUDY_ID":"ERP006662","SAMPLE_ID":"SAMEA3305372","RUN_ID":"ERR962465","ORGANISM":"homo_sapiens","STATUS":"Complete","ASSEMBLY_USED":"GRCh38","ENA_LAST_UPDATED":"Tue Jul 14 2015 09:08:31",
#"LAST_PROCESSED_DATE":"Wed Sep 30 2015 00:46:30","FTP_LOCATION":"ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/ERR962/ERR962465/ERR962465.cram"},

 foreach my $ens_plant (keys %all_ens_plants) {

     my $url = $get_runs_by_organism_endpoint . $ens_plant;

     my @array_response = @{getJsonResponse($url)};  # i call here the method that I made above

     foreach my $hash_ref (@array_response){

         my %hash = %{$hash_ref};

         next unless($hash{"STATUS"} eq "Complete"); 

         $plants_done{ $hash{"ORGANISM"} }= 1; 
         $runs {$hash{"RUN_ID"}} = 1;
         $studies {$hash {"STUDY_ID"}} = 1 ;
         
     }
}

    print "\nthere are " . scalar (keys %runs) ." plant runs completed to date ( $current_date )\n";
    print "\nthere are " .scalar (keys %studies) ." plant studies completed to date ( $current_date )\n";
    #print scalar @array_response. "\n";
    print "\nplants done to date:\n\n";

    foreach my $plant (keys %plants_done){

            print $plant."\n";

    }
    print "\n";

    print "in total there are " . scalar (keys %plants_done) . " plants done to date\n\n";

