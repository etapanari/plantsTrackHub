package ENA;

use strict ;
use warnings;

use LWP::UserAgent;
use XML::LibXML;
use utf8;

my $ua = LWP::UserAgent->new;
my $parser = XML::LibXML->new;

sub get_ENA_study_title{  

  my $study_id = shift; 
  my $study_title;

  my $url ="http://www.ebi.ac.uk/ena/data/view/$study_id&display=xml";

  my $response = $ua->get($url); 

  my $response_string;

  if ($response->is_success) {
    $response_string = $response->decoded_content;  
  }
  else {
    return 0;
  }

  my $doc_obj = $parser->parse_string($response_string);

  if ($doc_obj =~/display type is either not supported or entry is not found/ or $doc_obj !~/\/STUDY_LINK/){
    return "not yet in ENA";
  }

  my @nodes = $doc_obj->findnodes("//STUDY_TITLE");

  if(!$nodes[0]){
    print STDERR "I could not get a node from the xml doc of STUDY_TITLE for study id $study_id\n";
    return "Study title was not find in ENA";
  }
  $study_title = $nodes[0]->firstChild->data; #it's always 1 node
  utf8::encode($study_title);
  return $study_title;
  
}

sub get_ENA_title { # it works for sample, run and experiment ids

  my $id = shift ;
  my $title ;

  my $url ="http://www.ebi.ac.uk/ena/data/view/$id&display=xml";

  my $response = $ua->get($url); 
  my $response_string;

  if ($response->is_success) {
    $response_string = $response->decoded_content;  
  }
  else {
    return 0;
  }
  my $doc = $parser->parse_string($response_string);

  if ($doc =~/display type is either not supported or entry is not found/){
    return "not yet in ENA";
  }

  elsif(!$doc->findnodes("//TITLE")){
    return 0;   
  }else{

    my @nodes = $doc->findnodes("//TITLE");
  
    $title = $nodes[0]->firstChild->data; #it's always 1 node
    utf8::encode($title);

    return $title;

  }
}
# I call the endpoint (of the ENA sample metadata stored in $url) and get this type of response:
#accession	altitude	bio_material	broker_name	cell_line	cell_type	center_name	checklist	col_scientific_name	col_tax_id	collected_by	collection_date	country	cultivar	culture_collection	depth	description	dev_stage	ecotype	elevation	environment_biome	environment_feature	environment_material	environmental_package	environmental_sample	experimental_factor	first_public	germline	host	host_body_site	host_genotype	host_gravidity	host_growth_conditions	host_phenotype	host_sex	host_status	host_tax_id	identified_by	investigation_type	isolate	isolation_source	location	mating_type	ph	project_name	protocol_label	salinity	sample_alias	sample_collection	sampling_campaign	sampling_platform	sampling_site	scientific_name	secondary_sample_accession	sequencing_method	serotype	serovar	sex	specimen_voucher	strain	sub_species	sub_strain	submitted_host_sex	submitted_sex	target_gene	tax_id	temperature	tissue_lib	tissue_type	variety
#SAMEA1711073						The Genome Analysis Centre										INF1-C								N		2012-07-13	N																				RW_S9_barley					Hordeum vulgare subsp. vulgare	ERS155504												112509				

#url call -> http://www.ebi.ac.uk/ena/data/warehouse/search?query=%22accession=SAMEA1711073%22&result=sample&display=report&fields=accession,altitude,bio_material,broker_name,cell_line,cell_type,center_name,checklist,col_scientific_name,col_tax_id,collected_by,collection_date,country,cultivar,culture_collection,depth,description,dev_stage,ecotype,elevation,environment_biome,environment_feature,environment_material,environmental_package,environmental_sample,experimental_factor,first_public,germline,host,host_body_site,host_genotype,host_gravidity,host_growth_conditions,host_phenotype,host_sex,host_status,host_tax_id,identified_by,investigation_type,isolate,isolation_source,location,mating_type,ph,project_name,protocol_label,salinity,sample_alias,sample_collection,sampling_campaign,sampling_platform,sampling_site,scientific_name,secondary_sample_accession,sequencing_method,serotype,serovar,sex,specimen_voucher,strain,sub_species,sub_strain,submitted_host_sex,submitted_sex,target_gene,tax_id,temperature,tissue_lib,tissue_type,variety

sub get_sample_metadata_response_from_ENA_warehouse_rest_call {  # returns a hash ref if successful, or 0 if not successful -- this is very slow!!!

  my $sample_id =  shift;
  my $meta_keys = shift; 

  my %metadata_key_value_pairs;

  my $url = create_url_for_call_sample_metadata($sample_id,$meta_keys);

  my $response = $ua->get($url); 
  my $response_string;

  if ($response->is_success) {
    $response_string = $response->decoded_content;  
  }
  else {
    return 0;
  }

  my @lines = split(/\n/, $response_string);
  my $metadata_keys_line =  $lines[0];
  my $metadata_values_line =  $lines[1];


  if($response->code != 200 or $response_string =~ /^ *$/ or (!$metadata_values_line) or (!$metadata_keys_line ) ){ 

    print "Couldn't get metadata for $url with the first attempt, retrying..\n" ;

    my $flag_success=0;

    for(my $i=1; $i<=10; $i++) {

      print $i .".Retrying attempt: Retrying after 5s...\n";
      sleep 5;
      $response = $ua->get($url);

      if($response->code == 200){

        $response_string = $response->decoded_content;
        @lines = split(/\n/, $response_string);
        $metadata_keys_line =  $lines[0];
        $metadata_values_line =  $lines[1];

        $flag_success =1 ;
        print "Got metadata after all!\n";
        last;
      }

    }

    if($flag_success ==0 or $response_string =~ /^ *$/){  # if after the 10 attempts I still don't get the metadata..
     
      print STDERR "Didn't find metadata for url $url"."\t".$response->code."\n\n";
      return 0;
    }

  }
  
  my @metadata_keys = split(/\t/, $metadata_keys_line);
  my @metadata_values = split(/\t/, $metadata_values_line); 

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
  return \%metadata_key_value_pairs ; # hash with key -> metadata_key , value-> metadata_value

}


#content of the returned array:

#accession,altitude,bio_material,broker_name,cell_line,cell_type,center_name,checklist,col_scientific_name,col_tax_id,collected_by,collection_date,country,cultivar,culture_collection,depth,
#description,dev_stage,ecotype,elevation,environment_biome,environment_feature,environment_material,environmental_package,environmental_sample,experimental_factor,first_public,germline,host,host_body_site,host_genotype,
#host_gravidity,host_growth_conditions,host_phenotype,host_sex,host_status,host_tax_id,identified_by,investigation_type,isolate,isolation_source,location,mating_type,ph,project_name,protocol_label,
#salinity,sample_alias,sample_collection,sampling_campaign,sampling_platform,sampling_site,scientific_name,secondary_sample_accession,sequencing_method,serotype,serovar,sex,specimen_voucher,strain,sub_species,sub_strain,
#submitted_host_sex,submitted_sex,target_gene,tax_id,temperature,tissue_lib,tissue_type,variety[

sub get_all_sample_keys{

  my @array_keys;

  my $url ="http://www.ebi.ac.uk/ena/data/warehouse/usage?request=fields&result=sample";

  my $response = $ua->get($url); 

  my $response_string = $response->decoded_content;

  my @keys;

  if($response->code != 200 or $response_string =~ /^ *$/ ){

    print "Couldn't get sample metadata keys using $url with the first attempt, retrying..\n" ;

    my $flag_success = 0 ;
    for(my $i=1; $i<=10; $i++) {

      print $i .".Retrying attempt: Retrying after 5s...\n";
      sleep 5;
      $response = $ua->get($url);

      my $response_string = $response->decoded_content;

      $response->code= $response->code;

      if($response->code == 200){

        $response_string = $response->decoded_content;
        @keys = split(/\n/, $response_string);

        $flag_success =1 ;
        print "Got sample metadata keys after all!\n";
        last;
      }

    }
    if($flag_success ==0 or $response_string =~ /^ *$/){  # if after the 10 attempts I still don't get the metadata..
     
      print STDERR "Didn't get response for sample metadata keys using url $url"."\t".$response->code."\n\n";
      return 0;
    }

  }else{

    @keys = split(/\n/, $response_string);
  }

  foreach my $key (@keys){
    push (@array_keys ,$key);
  }

  return \@array_keys;

}

# it makes this url, given the table ref with the keys:

#http://www.ebi.ac.uk/ena/data/warehouse/search?query=%22accession=SAMPLE_id%22&result=sample&display=report&fields=accession,altitude,bio_material,broker_name,cell_line,cell_type,center_name,checklist,col_scientific_name,
#col_tax_id,collected_by,collection_date,country,cultivar,culture_collection,depth,description,dev_stage,ecotype,elevation,environment_biome,environment_feature,environment_material,environmental_package,environmental_sample,
#experimental_factor,first_public,germline,host,host_body_site,host_genotype,host_gravidity,host_growth_conditions,host_phenotype,host_sex,host_status,host_tax_id,identified_by,investigation_type,isolate,isolation_source,location,
#mating_type,ph,project_name,protocol_label,salinity,sample_alias,sample_collection,sampling_campaign,sampling_platform,sampling_site,scientific_name,secondary_sample_accession,sequencing_method,serotype,serovar,sex,
#specimen_voucher,strain,sub_species,sub_strain,submitted_host_sex,submitted_sex,target_gene,tax_id,temperature,tissue_lib,tissue_type,variety

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