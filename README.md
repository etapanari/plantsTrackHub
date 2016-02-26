# plantsTrackHub
Pipeline that creates Ensembl plant track hubs given ENA study ids and puts them in the Ensembl Track Hub Registry.<br />
The track hubs contain the Array Experess' alignments of Ensembl plant genomes to the RNAseq data available in ENA.<br />
Array Express provides the .cram files of the alignments and using their REST API the pipeline communicates with the AE data.<br />
Every track hub represents an ENA study. A track hub can have more than 1 plant species. The tracks of the track hubs are the CRAM alignement files.<br />

Pipeline:

 pipeline_create_register_track_hubs.pl

Parameters:

-THR_username etapanari   (of the track Hub Registry account) 

-THR_password  (of the track Hub Registry account) 

-server_dir_full_path  (location of where the track hub files to be stored)

-server_url  (server url of the location of the track hubs)

-do_track_hubs_from_scratch (optional flag) 

Example run:

perl pipeline_create_register_track_hubs.pl -THR_username etapanari -THR_password testing -server_dir_full_path /nfs/ensemblgenomes/ftp/pub/misc_data/.TrackHubs/ena_warehouse_meta/testing -server_url ftp://ftp.ensemblgenomes.org/pub/misc_data/.TrackHubs/ena_warehouse_meta/testing  -do_track_hubs_from_scratch 1> output 2>errors


