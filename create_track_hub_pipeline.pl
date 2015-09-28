# input : STUDY_ID and server location
# output : a trackhub here: http://www.ebi.ac.uk/~tapanari/

# how to call it:
# perl create_track_hub_pipeline.pl SRP036860 /homes/tapanari/public_html/data/test http://www.ebi.ac.uk/~tapanari/data/test

  use strict ;
  use warnings;
  use Data::Dumper;

  use HTTP::Tiny;
  use Time::HiRes;
  use JSON;

  use Bio::EnsEMBL::ENA::SRA::BaseSraAdaptor qw(get_adaptor);


  #Robert's example REST API call response
  #http://plantain:3000/eg/getLibrariesByStudyId/SRP033494

  my $study_id = $ARGV[0];
  my $ftp_dir_full_path = $ARGV[1];   #you put here the path in your home directory to the public html where the files will be stored in your server"/homes/tapanari/public_html/data/test"; # from /homes/tapanari/public_html there is a link to the /nfs/panda/ensemblgenomes/data/tapanari
  my $url_root = $ARGV[2];  # you put here your username's URL   ie: "http://www.ebi.ac.uk/~tapanari/data/test";
   
  my $server =  "http://plantain:3000/eg/"; #or could be $ARGV[3]; # Robert's server where he stores his REST URLs

  my $http = HTTP::Tiny->new();


sub getJsonResponse { # it returns the json response given the endpoint as param, it returns an array reference that contains hash references . If response not successful it returns 0

  my $endpoint = shift; # example endpoint: "getLibrariesByStudyId/SRP033494";
  my $url = $server.$endpoint;

  my $response = $http->get($url);

  if($response->{success} ==1) { # if the response is successful then I get 1

    my $content=$response->{content};      #print $response->{content}."\n"; # it prints whatever is the content of the URL, ie the jason response
    my $json = decode_json($content); # it returns an array reference 

    return $json;

  }else{

      my ($status, $reason) = ($response->{status}, $response->{reason}); #LWP perl library for dealing with http
      print "Failed for $endpoint! Status code: ${status}. Reason: ${reason}\n";  # if response is successful I get status "200" reason "OK"
      return 0;
  }

}

    my $get_runs_from_study_url="getLibrariesByStudyId/$study_id"; # i get all the runs of the study
   
    my @array_response=@{getJsonResponse($get_runs_from_study_url)};  # i call here the method that I made above

    my %assembly_names; #  it stores all distinct assembly names for a given study
    my %run_id_location; # it stores as key the run id and value the location in the ftp server of arrayexpress

# a line of this call:  http://plantain:3000/eg/getLibrariesByStudyId/SRP033494
#[{"STUDY_ID":"SRP033494","SAMPLE_ID":"SAMN02434874","RUN_ID":"SRR1042754","ORGANISM":"arabidopsis_thaliana","STATUS":"Complete","ASSEMBLY_USED":"TAIR10","ENA_LAST_UPDATED":"Fri Jun 19 2015 18:11:03",
#"LAST_PROCESSED_DATE":"Tue Jun 16 2015 15:07:34","FTP_LOCATION":"ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/SRR104/004/SRR1042754/SRR1042754.cram"},

     foreach my $hash_ref (@array_response){

         my %hash = %{$hash_ref};

         if($hash{"STATUS"} eq "Complete") { # i want to use only the "complete" runs

            $assembly_names{$hash{"ASSEMBLY_USED"}} = 1; # I store the value of the $hash{"ASSEMBLY_USED"} ie the "TAIR10" as a key in my hash %assembly_names
            $run_id_location{$hash{"RUN_ID"}}= $hash{"FTP_LOCATION"}; 
         }
     }

    `mkdir $ftp_dir_full_path/$study_id`;

     foreach my $assembly_name (keys %assembly_names){ # For every assembly I make a directory for the study -track hub

        `mkdir $ftp_dir_full_path/$study_id/$assembly_name`;
     }

# create links to the cram files

    foreach my $run_id (keys %run_id_location){

        my $target_file_name=$ftp_dir_full_path."/".$study_id."/".$run_id.".cram";

        `ln -s  $run_id_location{$run_id} $target_file_name`;

    }

#hub.txt content:

#hub SRP036643
#shortLabel ENA STUDY:SRP036643
#longLabel DNA methylation variation in Arabidopsis has a genetic basis and appears to be involved in local adaptation, <a href="http://www.ebi.ac.uk/ena/data/view/SRP036643">SRP036643</a>
#genomesFile genomes.txt
#email tapanari@ebi.ac.uk


      my $hub_txt_file="$ftp_dir_full_path/$study_id/hub.txt";

      `touch $hub_txt_file`;

      my $study_adaptor = get_adaptor('Study'); # I am using Dan Stain's ENA API

      my @studies =@{$study_adaptor->get_by_accession($study_id)}; # i am expecting to return 1 study object

      foreach my $study (@studies){

	  open(my $fh, '>', $hub_txt_file) or die "Could not open file '$hub_txt_file' $!";

	  print $fh "hub ".$study->accession."\n"; 
	  print $fh "shortLabel ENA STUDY: ".$study->accession."\n"; 
	  print $fh "longLabel ".$study->title." ; <a href=\"www.ebi.ac.uk/ena/data/view/".$study->accession."\">".$study->accession."</a>"."\n";
	  print $fh "genomesFile genomes.txt\n";
	  print $fh "email tapanari\@ebi.ac.uk\n";
      
      }

#genomes.txt content (for an assembly hub - for a track hub you only need genome and trackDb lines):

# genome IWGSC1.0+popseq
# trackDb IWGSC1.0+popseq/trackDb.txt


       my $genomes_txt_file="$ftp_dir_full_path/$study_id/genomes.txt";

       `touch $genomes_txt_file`; ######################################## I MAKE THE genomes.txt FILE

        open(my $fh, '>', $genomes_txt_file) or die "Could not open file '$genomes_txt_file' $!";


   foreach my $assembly_name (keys %assembly_names){

        print $fh "genome ".$assembly_name."\n"; 
        print $fh "trackDb ".$assembly_name."/trackDb.txt"."\n\n"; 
   }

# trackDb.txt content:

#track SRR1161753
#bigDataUrl http://www.ebi.ac.uk/~tapanari/data/SRP036643/SRR1161753.bam
#shortLabel ENA:SRR1161753
#longLabel Illumina Genome Analyzer IIx sequencing; GSM1321742: s1061_16C; Arabidopsis thaliana; RNA-Seq; <a href="http://www.ebi.ac.uk/ena/data/view/SRR1161753">SRR1161753</a>
#type bam


   foreach my $assembly_name (keys %assembly_names){

       my $trackDb_txt_file="$ftp_dir_full_path/$study_id/$assembly_name/trackDb.txt";

       `touch $trackDb_txt_file`;       ########################################  I MAKE THE trackDb.txt FILE IN EVERY ASSEMBLY FOLDER

       foreach my $study (@studies){

         open(my $fh, '>', $trackDb_txt_file) or die "Could not open file '$trackDb_txt_file' $!";

         for my $run (@{$study->runs()}) { # i get all runs from the study using Dan's ENA API


           next unless ($run_id_location{$run->accession()}); # if Robert's API call did not return this run id then I won't use it
           
           print $fh "track ". $run->accession()."\n"; 

           my $ftp_location = $run_id_location{$run->accession};

           print $fh "bigDataUrl $ftp_location \n"; 
           print $fh "shortLabel ENA:".$run->accession()."\n"; 
           print $fh "longLabel ".$run->title()."; <a href=\"www.ebi.ac.uk/ena/data/view/".$run->accession."\">".$run->accession."</a>"."\n" ;
           print $fh "type bam\n\n";

         }     
      }
 
# groups.txt content:

#name map
#label Mapping
#priority 2
#defaultIsClosed 0

       my $groups_txt_file="$ftp_dir_full_path/$study_id/$assembly_name/groups.txt";

       `touch $groups_txt_file`;   ########################################  I MAKE THE groups.txt FILE IN EVERY ASSEMBLY FOLDER

        open(my $fh2, '>', $groups_txt_file) or die "Could not open file '$groups_txt_file' $!";

        print $fh2 "name map\n";
        print $fh2 "label Mapping\n"; 
        print $fh2 "priority 2\n"; 
        print $fh2 "defaultIsClosed 0\n"; 

 }