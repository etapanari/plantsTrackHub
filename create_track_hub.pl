
# input : STUDY_ID local_directory_path server_url
# output : a trackhub (bunch of directories and files) on your server

# how to call it:
# perl create_track_hub.pl -study_id SRP036860 -local_ftp_dir_path /homes/tapanari/public_html/data/test -http_url http://www.ebi.ac.uk/~tapanari/data/test

  use strict ;
  use warnings;
  use Data::Dumper;

  use HTTP::Tiny;
  use Time::HiRes;
  use JSON;
  use Getopt::Long;

  use Bio::EnsEMBL::ENA::SRA::BaseSraAdaptor qw(get_adaptor);

  my $study_id ;
  my $ftp_dir_full_path ;   #you put here the path to your local dir where the files of the track hub are stored "/homes/tapanari/public_html/data/test"; # from /homes/tapanari/public_html there is a link to the /nfs/panda/ensemblgenomes/data/tapanari
  my $url_root ;  # you put here your username's URL   ie: "http://www.ebi.ac.uk/~tapanari/data/test";
   

  GetOptions(
     "study_id=s" => \$study_id ,
     "local_ftp_dir_path=s" => \$ftp_dir_full_path,
     "http_url=s" => \$url_root
  );

  my $server =  "http://plantain:3000/eg"; #or could be $ARGV[3]; # Robert's server where he stores his REST URLs

  my $http = HTTP::Tiny->new();


sub getJsonResponse { # it returns the json response given the endpoint as param, it returns an array reference that contains hash references . If response not successful it returns 0

  my $url = shift; # example: "http://plantain:3000/eg/getLibrariesByStudyId/SRP033494";

  my $response = $http->get($url);

  if($response->{success} ==1) { # if the response is successful then I get 1

    my $content=$response->{content};      #print $response->{content}."\n"; # it prints whatever is the content of the URL, ie the jason response
    my $json = decode_json($content); # it returns an array reference 

    return $json;

  }else{

      my ($status, $reason) = ($response->{status}, $response->{reason}); #LWP perl library for dealing with http
      print "create_track_hub_pipeline.pl gave ERROR: ";
      print STDERR "Failed for $url! Status code: ${status}. Reason: ${reason}\n";  # if response is successful I get status "200" reason "OK"
      return 0;
  }

}


    my $get_plant_roberts_plant_names_endpoint = "/getOrganisms/plants" ;
    my $get_plant_names_url= $server . $get_plant_roberts_plant_names_endpoint; # i get all organism names that robert uses for plants to date

    my %robert_plant_names;

#response:
#[{"ORGANISM":"arabidopsis_thaliana"},{"ORGANISM":"brassica_rapa"},{"ORGANISM":"hordeum_vulgare"},{"ORGANISM":"hordeum_vulgare_subsp._vulgare"},
#{"ORGANISM":"medicago_truncatula"},{"ORGANISM":"oryza_sativa"},{"ORGANISM":"oryza_sativa_japonica_group"},{"ORGANISM":"physcomitrella_patens"},
#{"ORGANISM":"populus_trichocarpa"},{"ORGANISM":"sorghum_bicolor"},{"ORGANISM":"triticum_aestivum"},{"ORGANISM":"vitis_vinifera"},{"ORGANISM":"zea_mays"}]

     my @plant_names_response = @{getJsonResponse($get_plant_names_url)};  # i call here the method that I made above

     foreach my $hash_ref (@plant_names_response){

         my %hash = %{$hash_ref};

         $robert_plant_names{ $hash{"ORGANISM"} }=1;  # this hash has all possible names of plants that Robert is using in his REST calls ; I get them from here: http://plantain:3000/eg/getOrganisms/plants
        
     }



    my $get_runs_from_study_url= $server . "/getLibrariesByStudyId/$study_id"; # i get all the runs of the study
   
    my @runs_response=@{getJsonResponse($get_runs_from_study_url)};  # i call here the method that I made above

    my %assembly_names; #  it stores all distinct assembly names for a given study
    my %run_id_location; # it stores as key the run id and value the location in the ftp server of arrayexpress
    my %run_assembly; #  it stores as key the run id and value the assembly name 
    my %run_robert_species_name;

# a line of this call:  http://plantain:3000/eg/getLibrariesByStudyId/SRP033494
#[{"STUDY_ID":"SRP033494","SAMPLE_ID":"SAMN02434874","RUN_ID":"SRR1042754","ORGANISM":"arabidopsis_thaliana","STATUS":"Complete","ASSEMBLY_USED":"TAIR10","ENA_LAST_UPDATED":"Fri Jun 19 2015 18:11:03",
#"LAST_PROCESSED_DATE":"Tue Jun 16 2015 15:07:34","FTP_LOCATION":"ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/SRR104/004/SRR1042754/SRR1042754.cram"},

     foreach my $hash_ref (@runs_response){

         my %hash = %{$hash_ref};

         if($hash{"STATUS"} eq "Complete" and $robert_plant_names{$hash {"ORGANISM"}}) { # i want to use only the "complete" runs and *plants* only, a study could have 2 species ie a plant and a non-plant

            $assembly_names{$hash{"ASSEMBLY_USED"}} = 1; # I store the assembly name ie the "TAIR10"
            $run_id_location{$hash{"RUN_ID"}}= $hash{"FTP_LOCATION"}; 
            $run_assembly { $hash{"RUN_ID"} } = $hash{"ASSEMBLY_USED"};
            $run_robert_species_name {$hash{"RUN_ID"}} = $hash {"ORGANISM"};
         }
     }

    `mkdir $ftp_dir_full_path/$study_id`;

     foreach my $assembly_name (keys %assembly_names){ # For every assembly I make a directory for the study -track hub

        `mkdir $ftp_dir_full_path/$study_id/$assembly_name`;
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

      if (scalar @studies >1){
 
           print STDERR "ERROR in create_track_hub.pl script: I get more than 1 study object from ENA using study id $study_id\n" ;
      }

      foreach my $study (@studies){ # it should be only 1 study

	  open(my $fh, '>', $hub_txt_file) or die "Could not open file '$hub_txt_file' $!";

	  print $fh "hub ".$study->accession."\n"; 
	  print $fh "shortLabel "."RNA-seq alignment hub ".$study->accession."\n"; 
          my $long_label = "longLabel ".$study->title." ; ENA link: <a href=\"http://www.ebi.ac.uk/ena/data/view/".$study->accession."\">".$study->accession."</a>"."\n";
#           if($long_label=~/[^\x00-\xFF]/){
#              print STDERR "$study_id has non-ASCII characters in the long label of the hub.txt file in line 143\n";
# 	     print $fh "NON-ASCII? ".$long_label;
#           }else{
	  print $fh $long_label;
#          }
	  print $fh "genomesFile genomes.txt\n";
	  print $fh "email tapanari\@ebi.ac.uk\n";
      
      }

#genomes.txt content 

# genome IWGSC1.0+popseq
# trackDb IWGSC1.0+popseq/trackDb.txt


       my $genomes_txt_file="$ftp_dir_full_path/$study_id/genomes.txt";

       `touch $genomes_txt_file`; ######################################## I MAKE THE genomes.txt FILE

        open(my $fh, '>', $genomes_txt_file) or die "Could not open file '$genomes_txt_file' $!";


   foreach my $assembly_name (keys %assembly_names){ # I create a stanza for every assembly

        print $fh "genome ".$assembly_name."\n"; 
        print $fh "trackDb ".$assembly_name."/trackDb.txt"."\n\n"; 
   }

# trackDb.txt content:

#track SRR1161753
#bigDataUrl http://www.ebi.ac.uk/~tapanari/data/SRP036643/SRR1161753.bam
#shortLabel ENA:SRR1161753
#longLabel Illumina Genome Analyzer IIx sequencing; GSM1321742: s1061_16C; Arabidopsis thaliana; RNA-Seq; <a href="http://www.ebi.ac.uk/ena/data/view/SRR1161753">SRR1161753</a>
#type bam

   my %done_runs; # i have to store the run_id in this hash as there was an occassion where different samples had the same run_id and then the same run was multiple times in the trackDb.txt file (as track) which is not valid by UCSC

   foreach my $assembly_name (keys %assembly_names){ # for every assembly folder of the study (if there is more than 1 assembly for a given study), I create a trackDb.txt file

       my $trackDb_txt_file="$ftp_dir_full_path/$study_id/$assembly_name/trackDb.txt";

       `touch $trackDb_txt_file`;       ########################################  I MAKE THE trackDb.txt FILE IN EVERY ASSEMBLY FOLDER

        my $study= $studies[0]; # this is basically 1 study- I get it using the study id, I can get the first element of the array

        open(my $fh, '>', $trackDb_txt_file) or die "Could not open file '$trackDb_txt_file' $!";

         my @samples=@{ $study->samples()};  # usually 1 study has more than 1 samples

         for my $sample ( @{ $study->samples() } ) { # I print the sample attributes here


             my @attrib_array_sample; 

             if(ref($sample->{"attributes"}) eq "HASH"){ # I am doing this because I found an occassion where the $sample->{"attributes"} is a HASH and not an array, in study ERP009119 its samples that have this are ERS747134 and ERS747135
                # the hash has only 2 keys, TAG and VALUE , so these 2 samples have only 1 attribute each.

                 push(@attrib_array_sample ,$sample->{"attributes"} );
                  
             }else{

                 @attrib_array_sample= @{$sample->{"attributes"}}; # i get this: Not an ARRAY reference at create_track_hub.pl
             }

             my @experiments =@{$sample->experiments()};

             foreach my $experiment (@experiments){  # each sample can have 1,2 or more experiments ; most have 1 or 2 but some can have more than 100

                my @attrib_array_experiment= @{$experiment->{"attributes"}};
                my @runs= @{$experiment->runs()}; # each experiment can have 1, 2 or more runs ; usually there are 1 or 2 runs per experiment
              
 
                foreach my $run (@runs){

                  if($done_runs {$run->accession()}{$assembly_name}){  # i do this check because i want to print every run once in the trackDb.txt file. see line 181
                        next;
                  }else{

                    $done_runs {$run->accession()}{$assembly_name} =1;
                  }

                  next unless ($run_id_location{$run->accession()}); # if Robert's API call did not return this run id then I won't use it
                  next unless ($run_assembly{$run->accession} eq $assembly_name ); 
           
                  my $ftp_location = $run_id_location{$run->accession};
                  my $species_name = $run_robert_species_name {$run->accession};

                  print $fh "track ". $run->accession()."\n"; 
                  print $fh "bigDataUrl $ftp_location \n"; 
                  my $short_label_ENA="shortLabel ENA:".$run->accession()."\n";
#           if($short_label_ENA=~/[^\x00-\xFF]/){
#              print STDERR "$study_id has non-ASCII characters in the short label of the trackDb.txt file in line 215\n";
# 	     print $fh "NON-ASCII? ".$short_label_ENA;
#           }else{
	  print $fh $short_label_ENA;
#          }
                  my $long_label_ENA = "longLabel ".$run->title()."; ENA link: <a href=\"http://www.ebi.ac.uk/ena/data/view/".$run->accession."\">".$run->accession."</a>"."\n" ;
#           if($long_label_ENA=~/[^\x00-\xFF]/){
#              print STDERR "$study_id has non-ASCII characters in the long label of the trackDb.txt file in line 222\n";
# 	     print $fh "NON-ASCII? ".$long_label_ENA;
#           }else{
	  print $fh $long_label_ENA;
#          }
                  print $fh "type bam\n";
                  print $fh "metadata species=$species_name ";


                  foreach my $attr_sample (@attrib_array_sample){
 
                     my $value = $attr_sample->{"VALUE"};
                     my @array = split(/ /, $value);

                     if (scalar @array > 1) {
                        my $string = "sample:".$attr_sample->{"TAG"}."=\"".$attr_sample->{"VALUE"}."\" ";  ##########non - ASCII? 
#           if($string=~/[^\x00-\xFF]/){
#              print STDERR "$study_id has non-ASCII characters in the metadata of the trackDb.txt file in line 239\n";
# 	     print $fh "NON-ASCII? ".$string;
#           }else{
	  print $fh $string;
#          }
                 #print $fh $string  # i want to have "" in values that are more than 1 word , ie: sample:source_name="young leaves from Kn1-N heterozygote"
                     }else{
                        print $fh "sample:".$attr_sample->{"TAG"}."=".$attr_sample->{"VALUE"}." ";
                     }

                  }  

                  foreach my $attr_exp (@attrib_array_experiment){

                     my $value = $attr_exp->{"VALUE"};
                     my @array = split(/ /, $value);

                     if (scalar @array > 1) {
                        print $fh "experiment:".$attr_exp->{"TAG"}."=\"".$attr_exp->{"VALUE"}."\" ";
                     }else{
                        print $fh "experiment:".$attr_exp->{"TAG"}."=".$attr_exp->{"VALUE"}." ";
                     }
                  }

                  my @attrib_array_runs= @{$run->{"attributes"}};

                  foreach my $attr_run (@attrib_array_runs){

                     my $value = $attr_run->{"VALUE"};
                     my @array = split(/ /, $value);

                     if (scalar @array > 1) {
                        print $fh "run:".$attr_run->{"TAG"}."=\"".$attr_run->{"VALUE"}."\" ";
                     }else{
                        print $fh "run:".$attr_run->{"TAG"}."=".$attr_run->{"VALUE"}." ";
                     }
                  }
                  print $fh "\n\n";

              } #end of foreach run

        } # end of for each experiment 

    } # end of for each sample

 
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