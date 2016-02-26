package TrackHubCreation;

use strict ;
use warnings;

use Getopt::Long; # to use the options when calling the script
use POSIX qw(strftime); # to get GMT time stamp
use TransformDate;
use ENA;
use EG;
use AEStudy;
use SubTrack;
use SuperTrack;
use Helper;


sub new {

  my $class = shift;
  my $study_id  = shift; 
  my $meta_keys_arref = shift ;
  my $server_dir_full_path = shift;
  
  defined $study_id and defined $server_dir_full_path
    or die "Object must be constructed using 2 parameters: study id and folder path\n";

  my $self = {
    study_id  => $study_id ,
    meta_keys => $meta_keys_arref,
    server_dir_full_path => $server_dir_full_path
  };

  return bless $self, $class; # this is what makes a reference into an object
}


sub make_track_hub{ # main method, creates the track hub of a study in the folder/server specified

  my $self= shift;
  my $study_id= $self->{study_id};
  my $server_dir_full_path = $self->{server_dir_full_path};

  my $study_obj = AEStudy->new($study_id);

  make_study_dir($server_dir_full_path, $study_obj);

  make_assemblies_dirs($server_dir_full_path, $study_obj) ;  
  
  make_hubtxt_file($server_dir_full_path , $study_obj);

  make_genomestxt_file($server_dir_full_path , $study_obj);  

  my %assembly_names = %{$study_obj->get_assembly_names}; 

  foreach my $assembly_name (keys %assembly_names){
    make_trackDbtxt_file($self,$server_dir_full_path, $study_obj, $assembly_name);
  }

  return "..Done\n";
}

sub run_system_command {

  my $command = shift;

  `$command`;

  if($? !=0){ # if exit code of the system command is successful returns 0
    return 0; 

  }else{
     return 1;
  }
}

sub make_study_dir{

  my ($server_dir_full_path,$study_obj) = @_;
  my $study_id = $study_obj->id;  # getting an error here

  run_system_command("mkdir $server_dir_full_path" . '/' . $study_id)
    or die "I cannot make dir $server_dir_full_path/$study_id in script: ".__FILE__." line: ".__LINE__."\n";
}

sub make_assemblies_dirs{

  my ($server_dir_full_path,$study_obj) = @_;
  my $study_id = $study_obj->id;
  
  # For every assembly I make a directory for the study -track hub
  foreach my $assembly_name (keys %{$study_obj->get_assembly_names}){

    run_system_command("mkdir $server_dir_full_path/$study_id/$assembly_name")
      or die "I cannot make directories of assemblies in $server_dir_full_path/$study_id in script: ".__FILE__." line: ".__LINE__."\n";
  }
}

sub make_hubtxt_file{

  my ($server_dir_full_path,$study_obj) = @_;
  my $study_id = $study_obj->id;
  my $hub_txt_file= "$server_dir_full_path/$study_id/hub.txt";

  run_system_command("touch $hub_txt_file")
    or die "Could not create hub.txt file in the $server_dir_full_path location\n";
  
  open(my $fh, '>', $hub_txt_file) or die "Could not open file '$hub_txt_file' $! in ".__FILE__." line: ".__LINE__."\n";

  print $fh "hub $study_id\n";

  print $fh "shortLabel "."RNA-Seq alignment hub ".$study_id."\n"; 
  
  my $ena_study_title= ENA::get_ENA_study_title($study_id);
  my $long_label;

  if (!$ena_study_title) {
    print STDERR "I cannot get study title for $study_id from ENA\n";
    $long_label = $long_label = "longLabel <a href=\"http://www.ebi.ac.uk/ena/data/view/".$study_id."\">".$study_id."</a>"."\n";
  }else{
    $long_label = "longLabel $ena_study_title ; <a href=\"http://www.ebi.ac.uk/ena/data/view/".$study_id."\">".$study_id."</a>"."\n";
    utf8::encode($long_label) ; # i do this as from ENA there are some funny data like library names in the long label of the study and perl thinks it's non-ASCii character, while they are not.
    print $fh $long_label;
    print $fh "genomesFile genomes.txt\n";
    print $fh "email tapanari\@ebi.ac.uk\n";

  }
}

sub make_genomestxt_file{
  
  my ($server_dir_full_path,$study_obj) = @_;  
  my $assembly_names_href = $study_obj->get_assembly_names;
  my $study_id = $study_obj->id;

  my $genomes_txt_file = "$server_dir_full_path/$study_id/genomes.txt";

  run_system_command("touch $genomes_txt_file")
    or die "Could not create genomes.txt file in the $server_dir_full_path location\n";

  open(my $fh2, '>', $genomes_txt_file) or die "Could not open file '$genomes_txt_file' $!\n";

  foreach my $assembly_name (keys %{$assembly_names_href}) {

    print $fh2 "genome ".$assembly_name."\n"; 
    print $fh2 "trackDb ".$assembly_name."/trackDb.txt"."\n\n"; 
  }

}

sub make_trackDbtxt_file{

  my ($self, $ftp_dir_full_path, $study_obj , $assembly_name) = @_;
    
  my $study_id =$study_obj->id;

  my $trackDb_txt_file="$ftp_dir_full_path/$study_id/$assembly_name/trackDb.txt";

  run_system_command("touch $trackDb_txt_file")
    or die "Could not create trackDb.txt file in the $ftp_dir_full_path/$study_id/$assembly_name location\n";       

  open(my $fh, '>', $trackDb_txt_file)
    or die "Error in ".__FILE__." line ".__LINE__." Could not open file '$trackDb_txt_file' $!";

  my @sample_ids = keys %{$study_obj->get_sample_ids} ;
  if(scalar @sample_ids ==0){
    print STDERR "No samples found for study $study_id\n"; 
  }
  foreach my $sample_id ( @sample_ids ) { 

    my $super_track_obj = $self->make_biosample_super_track_obj($sample_id);
    $super_track_obj->print_track_stanza($fh);

    foreach my $biorep_id (keys %{$study_obj->get_biorep_ids_from_sample_id($sample_id)}){
    
      my $track_obj=make_biosample_sub_track_obj($study_obj,$biorep_id,$sample_id);
      $track_obj->print_track_stanza($fh);

    } 
  }
} 


# i want they key of the key-value pair of the metadata to have "_" instead of space if they are more than 1 word
sub printlabel_key {

  my $string = shift ;
  my @array = split (/ /,$string) ;

  if (scalar @array > 1) {
    $string =~ s/ /_/g;

  }
  return $string;
}

# I want the value of the key-value pair of the metadata to have quotes in the whole string if the value is more than 1 word.
sub printlabel_value {

  my $string = shift ;
  my @array = split (/ /,$string) ;

  if (scalar @array > 1) {
       
    $string = "\"".$string."\"";  

  }
  return $string;
}

sub get_ENA_biorep_title{

  my $study_obj = shift;
  my $biorep_id = shift ;

  my $biorep_title ;
  my %run_titles;

  my @run_ids = @{$study_obj->get_run_ids_of_biorep_id($biorep_id)};

  if(scalar @run_ids > 1){ # then it is a clustered biorep
    foreach my $run_id (@run_ids){
      $run_titles{ENA::get_ENA_title($run_id)} =1;  # I get all distinct run titles
    }
    my @distinct_run_titles = keys (%run_titles);
    $biorep_title= join(" ; ",@distinct_run_titles); # the run titles are seperated by comma

    return $biorep_title;
  }else{  # the biorep_id is the same as a run_id
    return ENA::get_ENA_title($biorep_id);
  }
}

sub make_biosample_super_track_obj{
# i need 3 pieces of data to make the track obj :  track_name, long_label , metadata
  my $self= shift;
  my $sample_id = shift; # track name

  my $ena_sample_title = ENA::get_ENA_title($sample_id);
  my $long_label;

  # there are cases where the sample doesnt have title ie : SRS429062 doesn't have sample title
  if($ena_sample_title and $ena_sample_title !~/^ *$/ ){ 
    $long_label= "$ena_sample_title ; <a href=\"http://www.ebi.ac.uk/ena/data/view/".$sample_id."\">".$sample_id."</a>";

  }else{
    $long_label = "<a href=\"http://www.ebi.ac.uk/ena/data/view/".$sample_id."\">".$sample_id."</a>";
    print STDERR "\nCould not get sample title from ENA API for sample $sample_id\n";

  }
  utf8::encode($long_label);  
  my $date_string = strftime "%a %b %e %H:%M:%S %Y %Z", gmtime;  # date is of this type: "Tue Feb  2 17:57:14 2016 GMT"
  my $metadata_string="hub_created_date=".printlabel_value($date_string);
    
  # returns a has ref or 0 if unsuccessful
  my $meta_keys_arref = $self->{meta_keys};
  my $metadata_respose = ENA::get_sample_metadata_response_from_ENA_warehouse_rest_call( $sample_id,$meta_keys_arref);  
  if ($metadata_respose==0){
    print STDERR "No metadata values found for sample $sample_id\n";

  }else{  # if there is metadata
    my %metadata_pairs = %{$metadata_respose};
    my @meta_pairs;

    foreach my $meta_key (keys %metadata_pairs) {  # printing the sample metadata 

      utf8::encode($meta_key) ;
      my $meta_value = $metadata_pairs{$meta_key} ;
      utf8::encode($meta_value) ;
      # if the date of the metadata has the months in this format jun-Jun-June then I have to convert it to 06 as the Registry complains
      if($meta_key =~/date/ and $meta_value =~/[(a-z)|(A-Z)]/){ 
        $meta_value = TransformDate->change_date($meta_value);
      }
      my $pair= printlabel_key($meta_key)."=".printlabel_value($meta_value);
      push (@meta_pairs, $pair);
    }
    $metadata_string = $metadata_string." " . join(" ",@meta_pairs);
  }

  my $super_track_obj = SuperTrack->new($sample_id,$long_label,$metadata_string);
  return $super_track_obj;
}

sub make_biosample_sub_track_obj{ 
# i need 5 pieces of data to make the track obj :  track_name, parent_name, big_data_url , long_label ,file_type

  my $study_obj = shift;
  my $biorep_id = shift; #track name
  my $parent_id = shift;

  my $big_data_url = $study_obj->get_big_data_file_location_from_biorep_id($biorep_id);
  my $long_label_ENA;
  my $ena_title = get_ENA_biorep_title($study_obj,$biorep_id);

  if($biorep_id!~/biorep/){
    if(!$ena_title){
       print STDERR "biorep id $biorep_id was not found to have a title in ENA\n";
       $long_label_ENA = "<a href=\"http://www.ebi.ac.uk/ena/data/view/".$biorep_id."\">".$biorep_id."</a>\n" ;

    }else{
       $long_label_ENA = $ena_title." ; <a href=\"http://www.ebi.ac.uk/ena/data/view/".$biorep_id."\">".$biorep_id."</a>"."\n" ;
    }

  }else{ # run id would be "E-MTAB-2037.biorep4"       
    my $biorep_accession; 
    if($biorep_id=~/(.+)\.biorep.*/){
      $biorep_accession = $1;
    } 
 
    if(!$ena_title){
      print STDERR "first run of biorep id $biorep_id was not found to have a title in ENA\n";
      # i want the link to be like: http://www.ebi.ac.uk/arrayexpress/experiments/E-GEOD-55482/samples/?full=truehttp://www.ebi.ac.uk/~rpetry/bbrswcapital/E-GEOD-55482.bioreps.txt      
      $long_label_ENA = "<a href=\"http://www.ebi.ac.uk/arrayexpress/experiments/E-GEOD-55482/samples/?full=truehttp://www.ebi.ac.uk/~rpetry/bbrswcapital/".$1.".bioreps.txt"."\">".$biorep_id."</a>\n" ;

     }else{ 
        $long_label_ENA = $ena_title.";<a href=\"http://www.ebi.ac.uk/arrayexpress/experiments/E-GEOD-55482/samples/?full=truehttp://www.ebi.ac.uk/~rpetry/bbrswcapital/".$biorep_accession.".bioreps.txt"."\">".$biorep_id."</a>"."\n" ;
      }
  }
  utf8::encode($long_label_ENA);

  my $file_type =$study_obj->give_big_data_file_type_of_biorep_id($biorep_id);

  my $track_obj = SubTrack->new($biorep_id,$parent_id,$big_data_url,$long_label_ENA,$file_type);
  return $track_obj;

}


1;