# plantsTrackHub
Pipeline that creates Ensembl plant track hubs given ENA study ids and puts them in the Ensembl Track Hub Registry.
The track hubs contain the Array Experess' alignments of Ensembl plants to RNAseq data available in ENA.
They provide the .cram files of the alignments and using their REST API I get access to the available alignments they have prepared.

When running the pipeline: track_hub_creation_and_registration_pipeline.pl:
a) it calls the script delete_registered_trackhubs.pl and removes everything registered in the Registry in your account
b) removes all files and directories from the ftp server
c) it calls the script create_track_hub.pl that creates for a given study a track hub (set of files) in the ftp server
d) it calls the script register_track_hub.pl and registers every track hub to the TrackHub Registry.
