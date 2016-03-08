package EG;

# this module is written in order to have a method that returns the right assembly name in the cases where AE gives the assembly accession instead of the assembly name (due to our bug)

use strict ;
use warnings;

use JsonResponse;

my $ens_genomes_plants_call = "http://rest.ensemblgenomes.org/info/genomes/division/EnsemblPlants?content-type=application/json"; # to get all ensembl plants names currently

my @array_response_plants_assemblies; 

my $json_response = JsonResponse::get_Json_response($ens_genomes_plants_call);  

if(!$json_response){ # if response is 0

  die "Could not get Ensembl plant names from EG rest call: $ens_genomes_plants_call\n";

}else{

  @array_response_plants_assemblies = @{$json_response};
}

# response:
#[{"base_count":"479985347","is_reference":null,"division":"EnsemblPlants","has_peptide_compara":"1","dbname":"physcomitrella_patens_core_28_81_11","genebuild":"2011-03-JGI","assembly_level":"scaffold","serotype":null,
#"has_pan_compara":"1","has_variations":"0","name":"Physcomitrella patens","has_other_alignments":"1","species":"physcomitrella_patens","assembly_name":"ASM242v1","taxonomy_id":"3218","species_id":"1",
#"assembly_id":"GCA_000002425.1","strain":"ssp. patens str. Gransden 2004","has_genome_alignments":"1","species_taxonomy_id":"3218"},

#examples:
#ass_name      ass_accession
#AMTR1.0	GCA_000471905.1
#Theobroma_cacao_20110822	GCA_000403535.1

my %asmbNames ;
my %asmbId_asmbName;
my %plant_names;
my %species_name_assembly_id_hash;

foreach my $hash_ref (@array_response_plants_assemblies){

  $asmbNames  {$hash_ref->{"assembly_name"}} = 1;
  $plant_names{$hash_ref->{"species"}} =1 ;

  if(! $hash_ref->{"assembly_id"}){# for the 2 species without assembly id , I store 0000, this is specifically for the THR to work

    $species_name_assembly_id_hash{$hash_ref->{"species"}} = "0000" ; # i make the hash with 2 keys because the assembly name is not unique: v1.0 GCA_000005505.1 brachypodium_distachyon
                                                                                                                                                                                  # v1.0 GCA_000143415.1 selaginella_moellendorffii
  }else{

    $species_name_assembly_id_hash {$hash_ref->{"species"} } =  $hash_ref->{"assembly_id"};
  }
  next if(!$hash_ref->{"assembly_id"}); # 2 species don't have assembly ids now (Feb 2016) : triticum_aestivum and oryza_rufipogon 

  $asmbId_asmbName{$hash_ref->{"assembly_id"} } = $hash_ref->{"assembly_name"}; 
  
}

sub get_plant_names{

  return \%plant_names;
}

#"assembly_name":"v1.0","taxonomy_id":"88036","species_id":"1","assembly_id":"GCA_000143415.1
#"v1.0","taxonomy_id":"15368","species_id":"1","assembly_id":"GCA_000005505.1"

sub get_right_assembly_name{  # this method returns the right assembly name in the cases where AE gives the assembly accession instead of the assembly name (due to our bug)

  my $assembly_string = shift;
  my $assembly_name=$assembly_string;

  if (!$asmbNames{$assembly_string}){ # if my assembl string is not assembly name (but assembly id), then I have to change it into assembly name

    if($asmbId_asmbName{$assembly_string}) {  # solanum_tuberosum has a wrong assembly.default it's neither the assembly.name nor the assembly.accession BUT should be : "assembly_name":"SolTub_3.0" and "assembly_id":"GCA_000226075.1"

      $assembly_name = $asmbId_asmbName{$assembly_string}; 
    }

  }

  if($assembly_string eq "3.0"){ # this is an exception for solanum_tuberosum, its assembly name is 3.0 in AE API while it should be SolTub_3.0
    $assembly_name = "SolTub_3.0";
  }
  return $assembly_name;
  
}


sub get_species_name_assembly_id_hash{

  return \%species_name_assembly_id_hash;

}

1;