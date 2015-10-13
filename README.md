# plantsTrackHub
Pipeline that creates Ensembl plant trackhubs given study ids and puts them in the Ensembl Track Hub Registry.

When running the pipeline: get_all_studies.pl:
a) it calls the script delete_registered_trackhubs.pl and removes everything registered in the Registry in your account
b) you remove all files and directories in the ftp server
c) it calls the script create_track_hub_pipeline.pl that creates for a given study a track hub (set of files) in the frp server
d) it calls the script trackHubRegistry and registers every track hub to the TrackHub Registry.
