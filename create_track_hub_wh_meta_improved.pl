
#perl create_track_hub_wh_meta_improved.pl -study_id DRP000315 -local_server_dir_path /homes/tapanari 

use strict ;
use warnings;

use Getopt::Long;
use POSIX qw(strftime); # to get GMT time stamp
use TransformDate;
use ENA;
use EG;
use AEStudy;

use constant {

  SUCCESSFULLY_EXECUTED => 1,
  UNSUCCESSFULLY_EXECUTED => 0
};

my ($study_id, $server_dir_full_path); 

GetOptions(
  "study_id=s" => \$study_id,
  "local_server_dir_path=s" => \$server_dir_full_path
);


{ # main method

  my $study_obj = AEStudy->new($study_id);

  make_study_dir($server_dir_full_path, $study_obj);

  make_assemblies_dir($server_dir_full_path, $study_obj) ;  
  
  make_hubtxt_file($server_dir_full_path , $study_obj);

  make_genomestxt_file($server_dir_full_path , $study_obj);  

  my %assembly_names = %{$study_obj->get_assembly_names};  # is it good practice to loop here or inside the method?

  foreach my $assembly_name (keys %assembly_names){

    make_trackDbtxt_file($server_dir_full_path, $study_obj, $assembly_name);

  }
}

##METHODS##

sub run_system_command {

  my $command = shift;

  `$command`;

  if($? !=0){ # if exit code of the system command is successful returns 0

    return UNSUCCESSFULLY_EXECUTED; 

  }else{
 
    return SUCCESSFULLY_EXECUTED;
  }
  
}

sub make_study_dir{

  my ($server_dir_full_path,$study_obj) = @_;
  my $study_id = $study_obj->id;

  if (run_system_command("mkdir $server_dir_full_path/$study_id") == UNSUCCESSFULLY_EXECUTED){
    die "I cannot make dir $server_dir_full_path/$study_id in script: ".__FILE__." line: ".__LINE__."\n";
  }
}

sub make_assemblies_dir{

  my ($server_dir_full_path,$study_obj) = @_;
  my $study_id = $study_obj->id;

  foreach my $assembly_name (keys %{$study_obj->get_assembly_names}){ # For every assembly I make a directory for the study -track hub

    if (run_system_command("mkdir $server_dir_full_path/$study_id/$assembly_name") == UNSUCCESSFULLY_EXECUTED){
      die "I cannot make directories of assemblies in $server_dir_full_path/$study_id in script: ".__FILE__." line: ".__LINE__."\n";
    }
  }
}

sub make_hubtxt_file{

  my ($server_dir_full_path,$study_obj) = @_;

  my $study_id = $study_obj->id;
  my $hub_txt_file= "$server_dir_full_path/$study_id/hub.txt";

  if (run_system_command("touch $hub_txt_file") == UNSUCCESSFULLY_EXECUTED){
    die "Could not create hub.txt file in the $server_dir_full_path location\n";
  }

  open(my $fh, '>', $hub_txt_file) or die "Could not open file '$hub_txt_file' $! in ".__FILE__." line: ".__LINE__."\n";

  print $fh "hub $study_id\n";

  print $fh "shortLabel "."RNA-seq alignment hub ".$study_id."\n"; 
  
  my $ena_study_title= ENA::get_ENA_study_title($study_id);
  my $long_label;

  if (!$ena_study_title) {
    print STDERR "I cannot get study title for $study_id from ENA\n";
    $long_label = $long_label = "longLabel ENA link: <a href=\"http://www.ebi.ac.uk/ena/data/view/".$study_id."\">".$study_id."</a>"."\n";
  }else
  {

    $long_label = "longLabel $ena_study_title ; ENA link: <a href=\"http://www.ebi.ac.uk/ena/data/view/".$study_id."\">".$study_id."</a>"."\n";

    utf8::encode($long_label) ; # i do this as from ENA there are some funny data like library names in the long label of the study and perl thinks it's non-ASCii character, while they are not.
    print $fh $long_label;
    print $fh "genomesFile genomes.txt\n";
    print $fh "email tapanari\@ebi.ac.uk\n";

  }
}

sub make_genomestxt_file{
  
  my ($server_dir_full_path,$study_obj) = @_;
  
  my $assembly_names = $study_obj->get_assembly_names;
  my $study_id = $study_obj->id;

  my $genomes_txt_file = "$server_dir_full_path/$study_id/genomes.txt";

  if (run_system_command("touch $genomes_txt_file")== UNSUCCESSFULLY_EXECUTED){

    die "Could not create genomes.txt file in the $server_dir_full_path location\n";
  }

  open(my $fh2, '>', $genomes_txt_file) or die "Could not open file '$genomes_txt_file' $!\n";

  foreach my $assembly_name (keys %{$assembly_names}) {

    print $fh2 "genome ".$assembly_name."\n"; 
    print $fh2 "trackDb ".$assembly_name."/trackDb.txt"."\n\n"; 
  }

}

sub make_trackDbtxt_file{

# track SAMD00009891
# superTrack on show
# shortLabel BioSample:SAMD00009891
# longLabel Oryza sativa Japonica Group; Total mRNA from shoot of rice (Oryza sativa ssp. Japonica cv. Nipponbare) seedling; ENA link: <a href="http://www.ebi.ac.uk/ena/data/view/SAMD00009891">SAMD00009891</a>
# metadata hub_created_date="Tue Feb  2 13:25:39 2016 GMT" cultivar=Nipponbare tissue_type=shoot germline=N description="Total mRNA from shoot of rice (Oryza sativa ssp. Japonica cv. Nipponbare) seedling" accession=SAMD00009891 environmental_sample=N scientific_name="Oryza sativa Japonica Group" sample_alias=SAMD00009891 tax_id=39947 center_name=BIOSAMPLE secondary_sample_accession=DRS000420 first_public=2012-01-06 
# 
# 	track DRR000756
# 	parent SAMD00009891
# 	bigDataUrl http://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/DRR000/DRR000756/DRR000756.cram 
# 	shortLabel DRR000756
# 	longLabel Illumina Genome Analyzer IIx sequencing; Illumina sequencing of cDNAs derived from rice mRNA_Phosphate sufficient_1day_Shoot; ENA link: <a href="http://www.ebi.ac.uk/ena/data/view/DRR000756">DRR000756</a>
# 	type cram

  my ( $ftp_dir_full_path, $study_obj , $assembly_name) = @_;
    
  my $meta_keys = ENA::get_all_sample_keys(); # ref to array
  my $study_id =$study_obj->id;

  my $trackDb_txt_file="$ftp_dir_full_path/$study_id/$assembly_name/trackDb.txt";

  if(run_system_command("touch $trackDb_txt_file") == UNSUCCESSFULLY_EXECUTED) {

    die "Could not create trackDb.txt file in the $server_dir_full_path/$study_id/$assembly_name location\n";

  }         

  open(my $fh, '>', $trackDb_txt_file) or die "Error in ".__FILE__." line ".__LINE__." Could not open file '$trackDb_txt_file' $!";

  foreach my $sample_id ( keys %{$study_obj->get_sample_ids} ) { 

## print sample super track ##
    print $fh "track ".$sample_id."\n";
    print $fh "superTrack on show\n";
    print $fh "shortLabel BioSample:".$sample_id."\n";
    my $longLabel_sample;
    
    if(ENA::get_ENA_sample_or_exp_title($sample_id) and ENA::get_ENA_sample_or_exp_title($sample_id) !~/^ *$/ ){  # there are cases where the sample doesnt have title ie : SRS429062 doesn't have sample title

      $longLabel_sample = "longLabel ".ENA::get_ENA_sample_or_exp_title($sample_id)."; ENA link: <a href=\"http://www.ebi.ac.uk/ena/data/view/".$sample_id."\">".$sample_id."</a>";

    }else{

      $longLabel_sample = "longLabel "."ENA link: <a href=\"http://www.ebi.ac.uk/ena/data/view/".$sample_id."\">".$sample_id."</a>";
      print STDERR "\nCould not get sample title from ENA API for sample $sample_id\n";

    }
    utf8::encode($longLabel_sample);  
    print $fh $longLabel_sample."\n" ;

    my $date_string = strftime "%a %b %e %H:%M:%S %Y %Z", gmtime;

    print $fh "metadata hub_created_date=".printlabel_value($date_string)." ";

      # returns a has ref or 0 if unsuccessful
    if (ENA::get_metadata_response_from_ENA_warehouse_rest_call (ENA::create_url_for_call_sample_metadata($sample_id,$meta_keys)) ==0){

      print STDERR "No metadata values found for sample $sample_id of study $study_id\n";

    }else{  # if there is metadata

      my %metadata_pairs = %{ENA::get_metadata_response_from_ENA_warehouse_rest_call (ENA::create_url_for_call_sample_metadata($sample_id,$meta_keys))};

      foreach my $meta_key (keys %metadata_pairs) {  # printing the sample metadata 

        utf8::encode($meta_key) ;
        my $meta_value = $metadata_pairs{$meta_key} ;
        utf8::encode($meta_value) ;

        if($meta_key =~/date/ and $meta_value =~/[(a-z)|(A-Z)]/){ # if the date of the metadata has the months in this format jun-Jun-June then I have to convert it to 06 as the Registry complains
          $meta_value = TransformDate->change_date($meta_value);
        }
        print $fh printlabel_key($meta_key)."=".printlabel_value($meta_value)." ";
      }

    }

    print $fh "\n\n";

## end of the sample super track
## now printing the bioreps of the sample

    foreach my $biorep_id (keys %{$study_obj->get_biorep_ids_from_sample_id($sample_id)}){

      my $ae_asssembly_name = $study_obj->get_assembly_name_from_biorep_id($biorep_id) ;
      my $proper_assembly_name= EG::get_right_assembly_name ( $ae_asssembly_name);

      next unless ($proper_assembly_name eq $assembly_name ) ;#and print "Something is wrong with the assembly name ; AE gives $ae_assembly_name , then my method in EG:get_right_assembly_name gives $proper_assembly_name while it should be $assembly_name\n";  # just for Q.C.
           
      my $server_location = $study_obj->get_big_data_file_location_from_biorep_id($biorep_id);

      print $fh "	track ". $biorep_id."\n"; 
      print $fh "	parent ". $sample_id."\n"; 
      print $fh "	bigDataUrl $server_location \n"; 
      print $fh "	shortLabel BioRep:".$biorep_id."\n";

      my $long_label_ENA;
      my $ena_title;

      if($biorep_id =~/biorep/){

        my @runs = @{$study_obj->get_run_ids_of_biorep_id($biorep_id)};

        if(ENA::get_ENA_sample_or_exp_title ($runs[0])){
          $ena_title = ENA::get_ENA_sample_or_exp_title ($runs[0]);
        }

      }else{
        if(ENA::get_ENA_sample_or_exp_title ($biorep_id)){
          $ena_title = ENA::get_ENA_sample_or_exp_title ($biorep_id);
        }
      } 

      if($biorep_id!~/biorep/){

        if(!$ena_title){

          print STDERR "biorep id $biorep_id was not found to have a title in ENA\n";
          $long_label_ENA = "	longLabel ENA link: <a href=\"http://www.ebi.ac.uk/ena/data/view/".$biorep_id."\">".$biorep_id."</a>\n" ;

        }else{

          $long_label_ENA = "	longLabel ".$ena_title."; ENA link: <a href=\"http://www.ebi.ac.uk/ena/data/view/".$biorep_id."\">".$biorep_id."</a>"."\n" ;
        }

      }else{ # run id would be "E-MTAB-2037.biorep4"

        $biorep_id=~/(.+)\.biorep.*/; 

        if(!$ena_title){

          print STDERR "first run of biorep id $biorep_id was not found to have a title in ENA\n";
          # i want the link to be like: http://www.ebi.ac.uk/arrayexpress/experiments/E-GEOD-55482/samples/?full=truehttp://www.ebi.ac.uk/~rpetry/bbrswcapital/E-GEOD-55482.bioreps.txt      
          $long_label_ENA = "	longLabel AE link: <a href=\"http://www.ebi.ac.uk/arrayexpress/experiments/E-GEOD-55482/samples/?full=truehttp://www.ebi.ac.uk/~rpetry/bbrswcapital/".$1.".bioreps.txt"."\">".$biorep_id."</a>\n" ;

        }else{
 
          $long_label_ENA = "	longLabel ".$ena_title."; AE link: <a href=\"http://www.ebi.ac.uk/arrayexpress/experiments/E-GEOD-55482/samples/?full=truehttp://www.ebi.ac.uk/~rpetry/bbrswcapital/".$1.".bioreps.txt"."\">".$biorep_id."</a>"."\n" ;
        }
      }
      utf8::encode($long_label_ENA) ;
      print $fh $long_label_ENA;

      print $fh "	type ".$study_obj->give_big_data_file_type_of_biorep_id($biorep_id)."\n";
      print $fh "\n";

    } #end of foreach run

  } # end of for each sample

}

sub printlabel_value {   # I want the value of the key-value pair of the metadata to have quotes in the whole string if the value is more than 1 word.

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
