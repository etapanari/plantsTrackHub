package EG;

# this module is written in order to have a method that returns the right assembly name in the cases where AE gives the assembly accession instead of the assembly name (due to our bug)

use strict ;
use warnings;

use JsonResponse;

my $ens_genomes_plants_call = "http://rest.ensemblgenomes.org/info/genomes/division/EnsemblPlants?content-type=application/json"; # to get all ensembl plants names currently

#test server - new assemblies:
#my $ens_genomes_plants_call = "http://test.rest.ensemblgenomes.org/info/genomes/division/EnsemblPlants?content-type=application/json";

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
my %species_name_assembly_name_hash;


foreach my $hash_ref (@array_response_plants_assemblies){

  $asmbNames  {$hash_ref->{"assembly_name"}} = 1;
  $plant_names{$hash_ref->{"species"}} =1 ;

  $species_name_assembly_name_hash {$hash_ref->{"species"} } =  $hash_ref->{"assembly_name"};

  if(! $hash_ref->{"assembly_id"}){# for triticum_aestivum that is without assembly id , I store 0000, this is specifically for the THR to work

    $species_name_assembly_id_hash{$hash_ref->{"species"}} = "0000" ;
                                                                     
  }else{
    $species_name_assembly_id_hash {$hash_ref->{"species"} } =  $hash_ref->{"assembly_id"};
  }
  next if(!$hash_ref->{"assembly_id"}); # 2 species don't have assembly ids now (Feb 2016) : triticum_aestivum and oryza_rufipogon 

  $asmbId_asmbName{$hash_ref->{"assembly_id"} } = $hash_ref->{"assembly_name"}; 

  
}


sub get_plant_names{

  return \%plant_names;
}


sub get_assembly_name_using_species_name{ 

  my $species_name = shift;
  my $assembly_name = "unknown";

  if(!$species_name_assembly_name_hash{$species_name}){

    print STDERR "The species name: $species_name is not in EG REST response ($ens_genomes_plants_call) in the species field\n";
    return $assembly_name;
  }else{

    return $species_name_assembly_name_hash{$species_name};
  }
}

sub get_species_name_assembly_id_hash{

  return \%species_name_assembly_id_hash;

}

1;