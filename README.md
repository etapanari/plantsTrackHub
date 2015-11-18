# plantsTrackHub
Pipeline that creates Ensembl plant track hubs given ENA study ids and puts them in the Ensembl Track Hub Registry.
The track hubs contain the Array Experess' alignments of Ensembl plants to RNAseq data available in ENA.
Array Express provides the .cram files of the alignments and using their REST API I get access to the available alignments they have prepared.

Pipeline:

 track_hub_creation_and_registration_pipeline.pl:

Parameters:

-username   (of the track Hub Registry account)
-password   (of the track Hub Registry account)
-local_ftp_dir_path 
-http_url
-do_track_hubs_from_scratch (optional flag) 

Example run:

perl get_all_studies.pl -username my_username -password my_password -local_ftp_dir_path my_path_to_the_track_hub_dir  -http_url my_http_url_of_the_track_hub_files



