
# input : STUDY_ID local_directory_path server_url
# output : a trackhub (bunch of directories and files) on your server

# how to call it:
# perl create_track_hub_using_ena_warehouse_metadata.pl -study_id SRP036860 -local_ftp_dir_path /nfs/ensemblgenomes/ftp/pub/misc_data/.TrackHubs -http_url ftp://ftp.ensemblgenomes.org/pub/misc_data/.TrackHubs
# perl create_track_hub_using_ena_warehouse_metadata.pl -study_id SRP036860 -local_ftp_dir_path /nfs/ensemblgenomes/ftp/pub/misc_data/.TrackHubs/ena_warehouse_meta -http_url ftp://ftp.ensemblgenomes.org/pub/misc_data/.TrackHubs/ena_warehouse_meta

use strict ;
use warnings;
use HTTP::Tiny;
use JSON;
use Getopt::Long;
use utf8;
use Bio::EnsEMBL::ENA::SRA::BaseSraAdaptor qw(get_adaptor);
use POSIX qw(strftime); # to get GMT time stamp
use ArrayExpress;
use TransformDate;

my $study_id ;
my $ftp_dir_full_path ;   #you put here the path to your local dir where the files of the track hub are stored "/homes/tapanari/public_html/data/test"; # from /homes/tapanari/public_html there is a link to the /nfs/panda/ensemblgenomes/data/tapanari
my $url_root ;  # you put here your username's URL   ie: "http://www.ebi.ac.uk/~tapanari/data/test";


GetOptions(
  "study_id=s" => \$study_id ,
  "local_ftp_dir_path=s" => \$ftp_dir_full_path,
  "http_url=s" => \$url_root
);

my $server_array_express =  "http://plantain:3000/eg"; # Robert's server where he stores his REST URLs

my $http = HTTP::Tiny->new();

my %robert_plant_names = %{ArrayExpress->getPlantNamesArrayExpressAPI()}; 

my $get_runs_from_study_url= $server_array_express . "/getLibrariesByStudyId/$study_id"; # i get all the runs of the study
    
my @runs_response=@{getJsonResponse($get_runs_from_study_url)};  

my %assembly_names; #  it stores all distinct assembly names for a given study
my %run_id_location; # it stores as key the run id and value the location in the ftp server of arrayexpress
my %run_assembly; #  it stores as key the run id and value the assembly name 
my %run_robert_species_name;
my %sample_robert_species_name;
my %study_sample_run_ids;

# a line of this call:  http://plantain:3000/eg/getLibrariesByStudyId/SRP033494
#[{"STUDY_ID":"SRP033494","SAMPLE_ID":"SAMN02434874","RUN_ID":"SRR1042754","ORGANISM":"arabidopsis_thaliana","STATUS":"Complete","ASSEMBLY_USED":"TAIR10","ENA_LAST_UPDATED":"Fri Jun 19 2015 18:11:03",
#"LAST_PROCESSED_DATE":"Tue Jun 16 2015 15:07:34","FTP_LOCATION":"ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/SRR104/004/SRR1042754/SRR1042754.cram"},

foreach my $hash_ref (@runs_response){

  my %hash = %{$hash_ref};

  if($hash{"STATUS"} eq "Complete" and $robert_plant_names{$hash {"ORGANISM"}}) { # i want to use only the "complete" runs and *plants* only, a study could have 2 species ie a plant and a non-plant

    $assembly_names{$hash{"ASSEMBLY_USED"}} = 1; # I store the assembly name ie the "TAIR10"
    $run_id_location{$hash{"RUN_ID"}}= $hash{"FTP_LOCATION"};   # HERE I WOULD HAVE TO CALL MY METHOD TO GET THE FTP LOCATION FROM ENA
    $run_assembly { $hash{"RUN_ID"} } = $hash{"ASSEMBLY_USED"};
    $run_robert_species_name {$hash{"RUN_ID"}} = $hash {"ORGANISM"};
    $sample_robert_species_name {$hash{"SAMPLE_ID"}} = $hash {"ORGANISM"};
    $study_sample_run_ids{$hash{"STUDY_ID"}} {$hash{"SAMPLE_ID"}} {$hash{"RUN_ID"}} = 1;

  }
}

my $ens_genomes_plants_rest_call = "http://rest.ensemblgenomes.org/info/genomes/division/EnsemblPlants?content-type=application/json"; # to get all ensembl plants names currently

my @array_response_plants_assemblies = @{getJsonResponse($ens_genomes_plants_rest_call)};  

# response:
#[{"base_count":"479985347","is_reference":null,"division":"EnsemblPlants","has_peptide_compara":"1","dbname":"physcomitrella_patens_core_28_81_11","genebuild":"2011-03-JGI","assembly_level":"scaffold","serotype":null,
#"has_pan_compara":"1","has_variations":"0","name":"Physcomitrella patens","has_other_alignments":"1","species":"physcomitrella_patens","assembly_name":"ASM242v1","taxonomy_id":"3218","species_id":"1",
#"assembly_id":"GCA_000002425.1","strain":"ssp. patens str. Gransden 2004","has_genome_alignments":"1","species_taxonomy_id":"3218"},

my %assName_assAccession ;
my %assAccession_assName;

foreach my $hash_ref (@array_response_plants_assemblies){

  my %hash = %{$hash_ref};

  if(! $hash{"assembly_id"}){  # some species don't have assembly id, ie assembly accession; it is basically wheat (triticum_aestivum), oryza_longistaminata and oryza_rufipogon that don't have assembly accession

    $assName_assAccession  {$hash{"assembly_name"}} =  "missing assembly accession";
    next;
  }

  $assName_assAccession  {$hash{"assembly_name"} } = $hash{"assembly_id"};
  $assAccession_assName  {$hash{"assembly_id"} } = $hash{"assembly_name"};

}


## Making the assembly directory #############
my $ls_output = `ls $ftp_dir_full_path`  ;

if($? !=0){ # if ls is successful, it returns 0
 
  die "I cannot see contents of $ftp_dir_full_path(ls failed) in script: ".__FILE__." line: ".__LINE__."\n";

}

if($ls_output=~/$study_id/){ # if the study id folder exists, i remove it and then re-do it

  `rm -r $ftp_dir_full_path/$study_id` ;

  if($? !=0){ # if rm is successful, it returns 0
 
  die "I cannot rm $ftp_dir_full_path/$study_id  in script: ".__FILE__." line: ".__LINE__."\n";

  }
}

`mkdir $ftp_dir_full_path/$study_id`;

my $mkdir_flag=0; # if these flags are all 1 at the end of the script, it means that the track hub was created successfully

if($? !=0){ # if mkdir is successful, it returns 0
 
  die "I cannot make dir $ftp_dir_full_path/$study_id in script: ".__FILE__." line: ".__LINE__."\n";

}else{
 
  $mkdir_flag=1;

}

my $mkdir_flag2=0;

foreach my $assembly_name (keys %assembly_names){ # For every assembly I make a directory for the study -track hub

  $assembly_name = getRightAssemblyName($assembly_name);

  `mkdir $ftp_dir_full_path/$study_id/$assembly_name`;

  if($? !=0){ # if mkdir is successful, it returns 0
 
    die "I cannot make dir $ftp_dir_full_path/$study_id/$assembly_name in script: ".__FILE__." line: ".__LINE__."\n";

    }else{
      $mkdir_flag2=1;
    }
}


#hub.txt content:

#hub SRP036643
#shortLabel ENA STUDY:SRP036643
#longLabel DNA methylation variation in Arabidopsis has a genetic basis and appears to be involved in local adaptation, <a href="http://www.ebi.ac.uk/ena/data/view/SRP036643">SRP036643</a>
#genomesFile genomes.txt
#email tapanari@ebi.ac.uk

my $touch_flag=0;

my $hub_txt_file="$ftp_dir_full_path/$study_id/hub.txt";

`touch $hub_txt_file`;

if($? !=0){ # if touch is successful, it returns 0
 
  die "I cannot touch file $ftp_dir_full_path/$study_id/hub.txt in script: ".__FILE__." line: ".__LINE__."\n";

}else{
  $touch_flag=1;
}

my $study_adaptor = eval { get_adaptor('Study'); }; # I am using Dan Stain's ENA API

my @studies = eval { @{$study_adaptor->get_by_accession($study_id)} }; # i am expecting to return 1 study object

if ($@) {
  print "..ERROR - this will be deleted (check in the STDERR)\n" and die "ENA doesn't still have the submission of study $study_id , hence I cannot yet create a track hub for this study \n";
}

if (scalar @studies ==0){

  print "..ERROR\n" and die;
}

if (scalar @studies >1){
 
  print STDERR "ERROR in ".__FILE__." line ".__LINE__." : I get more than 1 study object from ENA using study id $study_id\n" ;
}

my $study =$studies[0]; # it should be only 1 study

open(my $fh, '>', $hub_txt_file) or die "Could not open file '$hub_txt_file' $!";

print $fh "hub ";
eval { $study->accession }; 

if ($@) {
  die "Died - I cannot get study accession from call study->accession from Dan's module for study $study_id\n";
}else{

  print $fh $study->accession."\n";
  print $fh "shortLabel "."RNA-seq alignment hub ".$study->accession."\n"; 
}


eval {$study->title};

if ($@) {
  die "I cannot get study title from call strudy->title from Dan's module for study $study_id\n";
}else{

  my $long_label = "longLabel ".$study->title." ; ENA link: <a href=\"http://www.ebi.ac.uk/ena/data/view/".$study->accession."\">".$study->accession."</a>"."\n";

  utf8::encode($long_label) ; # i do this as from ENA there are some funny data like library names in the long label of the study and perl thinks it's non-ASCii character, while they are not.
  print $fh $long_label;
  print $fh "genomesFile genomes.txt\n";
  print $fh "email tapanari\@ebi.ac.uk\n";

}

#genomes.txt content 

# genome IWGSC1.0+popseq
# trackDb IWGSC1.0+popseq/trackDb.txt
my $touch_flag2=0;

my $genomes_txt_file="$ftp_dir_full_path/$study_id/genomes.txt";

`touch $genomes_txt_file`; ######################################## I MAKE THE genomes.txt FILE

if($? !=0){ # if touch is successful, it returns 0
 
  die "I cannot touch file $ftp_dir_full_path/$study_id/genomes.txt in script: ".__FILE__." line: ".__LINE__."\n";

}else{

  $touch_flag2=1;
}

open(my $fh2, '>', $genomes_txt_file) or die "Could not open file '$genomes_txt_file' $!";


foreach my $assembly_name (keys %assembly_names){ # I create a stanza for every assembly

  $assembly_name = getRightAssemblyName($assembly_name);
  print $fh2 "genome ".$assembly_name."\n"; 
  print $fh2 "trackDb ".$assembly_name."/trackDb.txt"."\n\n"; 
}


# trackDb.txt content:

#track SRR1161753
#bigDataUrl http://www.ebi.ac.uk/~tapanari/data/SRP036643/SRR1161753.bam
#shortLabel ENA:SRR1161753
#longLabel Illumina Genome Analyzer IIx sequencing; GSM1321742: s1061_16C; Arabidopsis thaliana; RNA-Seq; <a href="http://www.ebi.ac.uk/ena/data/view/SRR1161753">SRR1161753</a>
#type bam

my $touch_flag3=0;
my %done_runs; # i have to store the run_id in this hash as there was an occassion where different samples had the same run_id and then the same run was multiple times as track in the trackDb.txt file (as track) which is not valid by UCSC
my $metadata_found_flag=1;
    
my $meta_keys = get_all_sample_keys();

my $meta_counter = 0;

foreach my $assembly_name (keys %assembly_names){ # for every assembly folder of the study (if there is more than 1 assembly for a given study), I create a trackDb.txt file

  $assembly_name = getRightAssemblyName($assembly_name);

  my $trackDb_txt_file="$ftp_dir_full_path/$study_id/$assembly_name/trackDb.txt";

  `touch $trackDb_txt_file`;       ########################################  I MAKE THE trackDb.txt FILE IN EVERY ASSEMBLY FOLDER

  if($? !=0){ # if touch is successful, it returns 0
 
    die "I cannot touch file $ftp_dir_full_path/$study_id/$assembly_name/trackDb.txt in script: ".__FILE__." line: ".__LINE__."\n";

  }else{
    $touch_flag3=1;
  }

  open(my $fh, '>', $trackDb_txt_file) or die "Error in ".__FILE__." line ".__LINE__." Could not open file '$trackDb_txt_file' $!";

  foreach my $sample_id ( keys %{ $study_sample_run_ids{$study_id}} ) { 

## print sample super track ##
    print $fh "track ".$sample_id."\n";
    print $fh "superTrack on show\n";
    print $fh "shortLabel ENA_sample:".$sample_id."\n";
    my $longLabel_sample;
    if(give_title_from_ena($sample_id) and give_title_from_ena($sample_id) !~/^ *$/) {  # there are cases where the sample doesnt have title ie : SRP023101 and SRP026160 don't have sample title
      $longLabel_sample = "longLabel ".give_title_from_ena($sample_id)."; ENA link: <a href=\"http://www.ebi.ac.uk/ena/data/view/".$sample_id."\">".$sample_id."</a>";
    }else{
      $longLabel_sample = "longLabel "."ENA link: <a href=\"http://www.ebi.ac.uk/ena/data/view/".$sample_id."\">".$sample_id."</a>";
      print STDERR "\nCould not get sample title from ENA API for sample $sample_id\n";
    }
    utf8::encode($longLabel_sample);  
    print $fh $longLabel_sample."\n" ;
    my $date_string = strftime "%a %b %e %H:%M:%S %Y %Z", gmtime;

    print $fh "metadata hub_created_date=".printlabel($date_string)." ";

    if (get_metadata_response_from_ena_warehouse_rest_call (create_url_for_call_sample_metadata($sample_id,$meta_keys)) ==0){

      $meta_counter++;
      print STDERR "$meta_counter. No metadata values found for sample $sample_id of study $study_id\n";
      $metadata_found_flag=0;

    }else{  # if there is metadata
      my %metadata_pairs = %{get_metadata_response_from_ena_warehouse_rest_call (create_url_for_call_sample_metadata($sample_id,$meta_keys))};

      foreach my $meta_key (keys %metadata_pairs) {  # printing the sample metadata 
        utf8::encode($meta_key) ;
        my $meta_value = $metadata_pairs{$meta_key} ;
        utf8::encode($meta_value) ;
        if($meta_key =~/date/ and $meta_value =~/[(a-z)|(A-Z)]/){ # if the date of the metadata has the months in this format jun-Jun-June then I have to convert it to 06 as the Registry complains
          $meta_value = TransformDate->change_date($meta_value);
        }
        print $fh printlabel_key($meta_key)."=".printlabel($meta_value)." ";
      }

    }

    print $fh "\n\n";

## end of the sample super track
## now printing the runs of the sample

    foreach my $run_id (keys %{ $study_sample_run_ids{$study_id} {$sample_id}}){

      if($done_runs {$run_id}{$assembly_name}){  # i do this check because i want to print every run once in the trackDb.txt file. see line 224 for comments
        next;
      }else{

        $done_runs {$run_id}{$assembly_name} =1;
      }

      my $roberts_api_asssembly_name =  $run_assembly{$run_id} ;
      my $proper_name_current_run = getRightAssemblyName ($roberts_api_asssembly_name);
      next unless ($proper_name_current_run eq $assembly_name ); 
           
      my $ftp_location = $run_id_location{$run_id};
      my $species_name = $run_robert_species_name {$run_id};

      print $fh "	track ". $run_id."\n"; 
      print $fh "	parent ". $sample_id."\n"; 
      print $fh "	bigDataUrl $ftp_location \n"; 
      my $short_label_ENA="	shortLabel ENA_run:".$run_id."\n";
      print $fh $short_label_ENA;

      my $long_label_ENA;
      my $ena_title = give_title_from_ena($run_id);
      if(!$ena_title){
        print STDERR "run id $run_id was not found to have a title in ENA\n";
        $long_label_ENA = "	longLabel ENA link: <a href=\"http://www.ebi.ac.uk/ena/data/view/".$run_id."\">".$run_id."</a>\n" ;
      }else{
        $long_label_ENA = "	longLabel ".$ena_title."; ENA link: <a href=\"http://www.ebi.ac.uk/ena/data/view/".$run_id."\">".$run_id."</a>"."\n" ;
      }

      utf8::encode($long_label_ENA) ;
      print $fh $long_label_ENA;

      print $fh "	type bam\n";
      print $fh "\n";

    } #end of foreach run

  } # end of for each sample

}



if ($mkdir_flag2==1 and $mkdir_flag==1 and $touch_flag==1 and $touch_flag2==1 and $touch_flag3==1){
  if ($metadata_found_flag == 0) {
    print "..Done - but no metadata found for at least 1 sample (check STDERR)\n";
  }else{
    print "..Done\n";
  }
}else{

  print "..Error\n";

}

## METHODS ##

sub getJsonResponse { # it returns the json response given the endpoint as param, it returns an array reference that contains hash references . If response not successful it returns 0

  my $url = shift; # example: "http://plantain:3000/eg/getLibrariesByStudyId/SRP033494";

  my $response = $http->get($url);

  if($response->{success} ==1) { # if the response is successful then I get 1

    my $content=$response->{content};     
    my $json = decode_json($content); # it returns an array reference 

    return $json;

  }else{

    my ($status, $reason) = ($response->{status}, $response->{reason}); #LWP perl library for dealing with http
    print STDERR "ERROR in: ".__FILE__." line: ".__LINE__ ." Failed for $url! Status code: ${status}. Reason: ${reason}\n";  # if response is successful I get status "200", reason "OK"
    return 0;
  }

}


sub printlabel {   # I want the value of the key-value pair of the metadata to have quotes in the whole string if the value is more than 1 word.

  my $string = shift ;
  my @array = split (/ /,$string) ;

  if (scalar @array > 1) {

       
    $string = "\"".$string."\"";  

  }
  return $string;
 
}


sub printlabel_key {  # i want they key of the key-value pair of the metadata to have "_" instead of space if they are more than 1 word

  my $string = shift ;
  my @array = split (/ /,$string) ;

  if (scalar @array > 1) {
    $string =~ s/ /_/g;

  }
  return $string;
 
}


sub getRightAssemblyName { # this method returns the right assembly name in the cases where Robert takes the assembly accession instead of the assembly name due to our bug

  my $assembly_string = shift;
  my $assembly_name;


  if (!$assName_assAccession{$assembly_string}){

    if(!$assAccession_assName{$assembly_string}) {  # solanum_tuberosum has a wrong assembly.default it's neither the assembly.name nor the assembly.accession BUT : "assembly_name":"SolTub_3.0" and "assembly_id":"GCA_000226075.1"

      $assembly_name = $assembly_string
 
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

sub get_all_sample_keys{

  my @array_keys;

  my $url ="http://www.ebi.ac.uk/ena/data/warehouse/usage?request=fields&result=sample";
  my $ua = LWP::UserAgent->new;
  my $response = $ua->get($url); 
  my $response_string = $response->decoded_content;
  my @keys = split(/\n/, $response_string);

  foreach my $key (@keys){
    push (@array_keys ,$key);
  }

  return \@array_keys;

}

sub create_url_for_call_sample_metadata { # i am calling this method for a sample id

  my $sample_id = shift;
  my $table_ref= shift;
  my @key_values = @{$table_ref};
  my $url = "http://www.ebi.ac.uk/ena/data/warehouse/search?query=\%22accession=$sample_id\%22&result=sample&display=report&fields=";
  my $counter = 0;
  foreach my $key_value (@key_values){

    $counter++;
    $url = $url .$key_value;
    if ($counter < scalar @key_values){
      $url = $url .",";
    }
 
  }

  return $url;

}

# sub get_metadata_response_from_ena_warehouse_rest_call {  # returns a hash ref if successful, or 0 if not successful -- this is very slow!!!
# 
#   my $url =  shift;
#   my %metadata_key_value_pairs;
#   my $ua = LWP::UserAgent->new;
#   my $response = $ua->get($url); 
# 
#   my $response_string = $response->decoded_content;
#   my @lines = split(/\n/, $response_string);
#   my $metadata_keys_line =  $lines[0];
#   my $metadata_values_line =  $lines[1];
# 
#   if(!$metadata_values_line){
#     print STDERR "\nmetadata values are empty for url: $url\n\n";
#     return 0;
#   }
#   
#   if($metadata_keys_line =~ /^ *$/){
#     print STDERR "metadata keys are empty for url: $url\n\n";
#     return 0;
#   }
#   
#   my @metadata_keys = split(/\t/, $metadata_keys_line);
#   my @metadata_values = split(/\t/, $metadata_values_line); # here i get error
# 
#   my $index = 0;
# 
#   foreach my $metadata_key (@metadata_keys){
#     if(!$metadata_values [$index] or $metadata_values [$index] =~/^ *$/) {
#       $index++;
#       next;
# 
#     }else{
#       $metadata_key_value_pairs{$metadata_key} = $metadata_values [$index];
#     }
#     $index++;
# 
#   }
#   return \%metadata_key_value_pairs ;
# 
# }

sub get_metadata_response_from_ena_warehouse_rest_call {  # returns a hash ref if successful, or 0 if not successful -- this is very slow!!!

  my $url =  shift;
  my %metadata_key_value_pairs;
  my $ua = LWP::UserAgent->new;
  my $response = $ua->get($url); 

  my $response_code= $response->code;
  my $response_string = $response->decoded_content;

  if($response_code != 200 or $response_string =~ /^ *$/){ 

    print "Couldn't get metadata for $url with the first attempt, retrying..\n" ;

    my $flag_success=0;

    for(my $i=1; $i<=10; $i++) {

      print $i .".Retrying attempt: Retrying after 5s...\n";
      sleep 5;
      $response = $ua->get($url);
      $response_code= $response->code;
      if($response_code == 200){
        $flag_success =1 ;
        print "Got metadata after all!\n";
        last;
      }

    }

    if($flag_success ==0 or $response_string =~ /^ *$/){
     
      print STDERR "Didn't find metadata for url $url"."\t".$response->code."\n\n";
      return 0;
    }

  }

  my @lines = split(/\n/, $response_string);
  my $metadata_keys_line =  $lines[0];
  my $metadata_values_line =  $lines[1];

  if(!$metadata_values_line){
    print STDERR "\n response code: ".$response_code." Metadata values are empty for url: $url\n\n";
    return 0;
  }
  
  if($metadata_keys_line =~ /^ *$/){
    print STDERR "\n response code: ".$response_code." Metadata keys are empty for url: $url\n\n";
    return 0;
  }
  
  my @metadata_keys = split(/\t/, $metadata_keys_line);
  my @metadata_values = split(/\t/, $metadata_values_line); # here i get error

  my $index = 0;

  foreach my $metadata_key (@metadata_keys){
    if(!$metadata_values [$index] or $metadata_values [$index] =~/^ *$/) {
      $index++;
      next;

    }else{
      $metadata_key_value_pairs{$metadata_key} = $metadata_values [$index];
    }
    $index++;

  }
  return \%metadata_key_value_pairs ;

}

sub give_title_from_ena {

  my $id = shift ; # i can put a sample or a run id
  my $title ;

  my $url ="http://www.ebi.ac.uk/ena/data/view/$id&display=xml";
  my $ua = LWP::UserAgent->new;
  my $response = $ua->get($url); 
  my $response_string = $response->decoded_content;
  if ($response_string =~ /<TITLE>(.+)<\/TITLE>/ ) {  # end tag is : </TITLE>
    $title = $1;
  }

  return $title;
}
