package ENA;

use strict ;
use warnings;

use LWP::UserAgent;
use XML::LibXML;
use utf8;

sub get_ENA_study_title{  # there is also another way to get the title. using the warehouse call. check both and see which one is faster

  my $study_id = shift; 
  my $study_title;

  my $url ="http://www.ebi.ac.uk/ena/data/view/$study_id&display=xml";
  my $ua = LWP::UserAgent->new;
  my $response = $ua->get($url); 
  my $response_string = $response->decoded_content;

  my $parser = XML::LibXML->new;
  my $doc = $parser->parse_string($response_string);

  my @nodes = $doc->findnodes("//STUDY_TITLE");

  $study_title = $nodes[0]->firstChild->data; #it's always 1 node
  utf8::encode($study_title);
  return $study_title;
  
}

sub get_ENA_title { # it works for sample, run and experiment ids

  my $sample_id = shift ;
  my $sample_title ;

  my $url ="http://www.ebi.ac.uk/ena/data/view/$sample_id&display=xml";
  my $ua = LWP::UserAgent->new;
  my $response = $ua->get($url); 
  my $response_string = $response->decoded_content;

  my $parser = XML::LibXML->new;
  my $doc = $parser->parse_string($response_string);

  if(!$doc->findnodes("//TITLE")){
    return 0;   
  }else{

    my @nodes = $doc->findnodes("//TITLE");
  
    $sample_title = $nodes[0]->firstChild->data; #it's always 1 node
    utf8::encode($sample_title);

    return $sample_title;

  }
}

sub get_metadata_response_from_ENA_warehouse_rest_call {  # returns a hash ref if successful, or 0 if not successful -- this is very slow!!!

  my $sample_id =  shift;
  my %metadata_key_value_pairs;

  my $meta_keys = get_all_sample_keys(); # ref to array
  my $url = ENA::create_url_for_call_sample_metadata($sample_id,$meta_keys);

  my $ua = LWP::UserAgent->new;
  my $response = $ua->get($url); 

  my $response_code= $response->code;
  my $response_string = $response->decoded_content;

  my @lines = split(/\n/, $response_string);
  my $metadata_keys_line =  $lines[0];
  my $metadata_values_line =  $lines[1];


  if($response_code != 200 or $response_string =~ /^ *$/ or (!$metadata_values_line) or (!$metadata_keys_line ) ){ 

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
      if($metadata_key=~/date/ and $metadata_values [$index]=~/(\d+)-\d+-\d+\/\d+-\d+-\d+/){ # i do this as an exception because I had dates like this:  collection_date=2014-01-01/2014-12-31, I want to do it collection_date=2014
         $metadata_values [$index] = $1;
      }
      $metadata_key_value_pairs{$metadata_key} = $metadata_values [$index];
    }
    $index++;

  }
  return \%metadata_key_value_pairs ;

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

1;