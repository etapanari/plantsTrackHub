# input : STUDY_ID 
# output : a trackhub here: http://www.ebi.ac.uk/~tapanari/

# how to call it:
# perl create_track_hub_pipeline.pl SRP036860 /nfs/panda/ensemblgenomes/development/tapanari/trackHub_stuff  /homes/tapanari/public_html  http://www.ebi.ac.uk/~tapanari/

    use strict ;
    use warnings;
    use Data::Dumper;
    use Bio::EnsEMBL::DBSQL::DBAdaptor;
    use Bio::EnsEMBL::Registry;
    use Bio::EnsEMBL::ENA::SRA::BaseSraAdaptor qw(get_adaptor);


    my $study_id=$ARGV[0];
    my $full_path_to_store_bam_files=$ARGV[1];
    my $ftp_dir_full_path=$ARGV[2]; #"/homes/tapanari/public_html";
    my $url_root=$ARGV[3]; #"http://www.ebi.ac.uk/~tapanari/";

    my $registry = 'Bio::EnsEMBL::Registry';

    $registry->load_registry_from_db(
     -host       => 'mysql-eg-staging-1.ebi.ac.uk',
     -port       =>  4160,
     -user       => 'ensro',
     -db_version => '80',
    );

     #`source /homes/oracle/ora11setup.sh`;
     `/nfs/ma/home/atlas3-production/sw/atlasinstall_prod/atlasprod/irap/single_lib/db/scripts/findCRAMFiles.sh $study_id >  $study_id.cram.locations`;

# output of the first 2 lines of the above script (Robert's)
    #study_id	run_id	cram_location	organism	processing_status
    #ERP004714	ERR424721	ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/ERR424/ERR424721/ERR424721.cram	triticum_aestivum	18-JUN-15	completed

   my %run_id_location;
   my $species_name;

   open(IN, "$study_id.cram.locations") or die "Can't open $study_id.cram.locations\n";
       
        while(<IN>){

           chomp;
           next if($_=~/^study/); # i skip the label line
           my @words = split(/\t/, $_);

           my $run_id=$words[1];
           my $location=$words[2];
           $species_name=$words[3];

           if($words[5] eq "completed"){
             $run_id_location{$run_id}=$location;
           }
        }

   close(IN);


    my $meta_container = $registry->get_adaptor( $species_name, 'Core', 'MetaContainer' );

    my $assembly_name = $meta_container->single_value_by_key('assembly.name'); 

    `mkdir $ftp_dir_full_path/$study_id`;

    `mkdir $ftp_dir_full_path/$study_id/$assembly_name`;


    foreach my $run_id (keys %run_id_location){


      #`wget $run_id_location{$run_id} `; # to download the cram files
     # make the bam files for each run:
      `samtools view -T $full_path_to_store_bam_files/$species_name/Physcomitrella_patens.ASM242v1.26.dna.toplevel.fa -b -o  $full_path_to_store_bam_files/$species_name/$run_id.bam $run_id_location{$run_id}`;  # CRAM to BAM
      `samtools index -b $full_path_to_store_bam_files/$species_name/$run_id.bam` ; # to index the bam (creates bam.bai file) 

     # to create the links to the bam and bam.bai files of each run:
      `ln -s  $full_path_to_store_bam_files/$species_name/$run_id.bam $ftp_dir_full_path/$study_id/$run_id.bam`;
      `ln -s  $full_path_to_store_bam_files/$species_name/$run_id.bam.bai $ftp_dir_full_path/$study_id/$run_id.bam.bai`;
    }


#hub.txt content:

#hub Whole transcriptome sequencing of wheat 3B chromosome  ->study_title
#shortLabel Whole transcriptome sequencing of wheat 3B chromosome  ->study_title
#longLabel The project aims to establish a transcriptional map of wheat 3B chromosome, i.e., identify the expressed portions of the chromosome, correlate the expression patterns to the chromosomal localization and to refine the sequence annotation through the validation of gene structure and position ->study_abstract
#genomesFile genomes.txt
#email tapanari@ebi.ac.uk


      my $hub_txt_file="$ftp_dir_full_path/$study_id/hub.txt";

      `touch $hub_txt_file`;

      my $study_adaptor = get_adaptor('Study');

      my @studies =@{$study_adaptor->get_by_accession($study_id)};

      foreach my $study (@studies){

	  open(my $fh, '>', $hub_txt_file) or die "Could not open file '$hub_txt_file' $!";

	  print $fh $study->accession."\n"; 
	  print $fh "shortLabel hub ENA STUDY: ".$study->accession."\n"; 
	  print $fh "longLabel ".$study->title." ,<a href=\"www.ebi.ac.uk/ena/data/view/".$study->accession."\">".$study->accession."</a>"."\n";
	  print $fh "genomesFile genomes.txt\n";
	  print $fh "email tapanari\@ebi.ac.uk\n";
      
      }


#genomes.txt content (for an assembly hub - for a track hub you only need genome and trackDb lines):

# genome IWGSC1.0+popseq
# trackDb IWGSC1.0+popseq/trackDb.txt


       my $genomes_txt_file="$ftp_dir_full_path/$study_id/genomes.txt";

       `touch $genomes_txt_file`;

        open(my $fh, '>', $genomes_txt_file) or die "Could not open file '$genomes_txt_file' $!";

        print $fh "genome ".$assembly_name."\n"; 
        print $fh "trackDb ".$assembly_name."/trackDb.txt"."\n"; 

# trackDb.txt content:

#track run_ERR424721
#bigDataUrl http://www.ebi.ac.uk/~tapanari/ERP004714/ERR424721.bam
#shortLabel Illumina HiSeq 2000 paired end sequencing; ble HiSeq 2000 Simple ou Paire multiplex , URL: http://www.ebi.ac.uk/ena/data/view/ERR424721
#longLabel Illumina HiSeq 2000 paired end sequencing; ble HiSeq 2000 Simple ou Paire multiplex , URL: http://www.ebi.ac.uk/ena/data/view/ERR424721
#type bam

       my $trackDb_txt_file="$ftp_dir_full_path/$study_id/$assembly_name/trackDb.txt";

       `touch $trackDb_txt_file`;

       foreach my $study (@studies){

         open(my $fh, '>', $trackDb_txt_file) or die "Could not open file '$trackDb_txt_file' $!";

         for my $run (@{$study->runs()}) {

           print $fh $run->accession()."\n"; 
           print $fh "bigDataUrl $url_root".$study->accession()."/".$run->accession().".bam"."\n"; 
           print $fh "shortLabel track ENA RUN: ".$run->accession()."\n"; 
           print $fh "longLabel ".$run->title()."; <a href=\"www.ebi.ac.uk/ena/data/view/".$run->accession."\">".$run->accession."</a>"."\n" 
           print $fh "type bam\n\n";

         }     
      }
 
# groups.txt content:

#name map
#label Mapping
#priority 2
#defaultIsClosed 0

       my $groups_txt_file="$ftp_dir_full_path/$study_id/$assembly_name/groups.txt";

       `touch $groups_txt_file`;

        open(my $fh2, '>', $groups_txt_file) or die "Could not open file '$groups_txt_file' $!";

        print $fh2 "name map\n";
        print $fh2 "label Mapping\n"; 
        print $fh2 "priority 2\n"; 
        print $fh2 "defaultIsClosed 0\n"; 

