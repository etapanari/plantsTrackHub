package SubTrack;

use strict;
use warnings;


## this is a class of all the sub-track data of a sub-track stanza in the trackDb.txt file

sub new {

  my $class = shift;
  my $track_name = shift;
  my $parent_name = shift;
  my $big_data_url = shift;
  my $long_label= shift;
  my $type = shift;

  my $self = {
    track_name => $track_name,
    parent_name => $parent_name,
    big_data_url => $big_data_url,
    long_label => $long_label,
    file_type => $type
  };

  return bless $self, $class; # this is what makes a reference into an object
}

# 	track DRR000756
# 	parent SAMD00009891
# 	bigDataUrl http://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/DRR000/DRR000756/DRR000756.cram 
# 	shortLabel BioRep:DRR000756
# 	longLabel Illumina Genome Analyzer IIx sequencing; Illumina sequencing of cDNAs derived from rice mRNA_Phosphate sufficient_1day_Shoot; ENA link: <a href="http://www.ebi.ac.uk/ena/data/view/DRR000756">DRR000756</a>
# 	type cram
sub print_track_stanza{

  my $self = shift;
  my $fh = shift;

  print $fh "	track ". $self->{track_name}."\n"; 
  print $fh "	parent ". $self->{parent_name}."\n"; 
  print $fh "	bigDataUrl ".$self->{big_data_url}."\n"; 
  print $fh "	shortLabel BioRep:".$self->{track_name}."\n";
  print $fh "	longLabel ".$self->{long_label};
  print $fh "	type ".$self->{file_type}."\n";
  print $fh "\n";

}


1;