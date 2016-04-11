package SuperTrack;

use strict;
use warnings;


## this is a class of all the sub-track data of a sub-track stanza in the trackDb.txt file

sub new {

  my $class = shift;
  my $track_name = shift;
  my $long_label = shift;
  my $metadata = shift;

  my $self = {
    track_name => $track_name,
    long_label => $long_label,
    metadata => $metadata
  };

  return bless $self, $class; # this is what makes a reference into an object
}


# track SAMD00009891
# superTrack on show
# shortLabel BioSample:SAMD00009891
# longLabel Oryza sativa Japonica Group; Total mRNA from shoot of rice (Oryza sativa ssp. Japonica cv. Nipponbare) seedling; ENA link: <a href="http://www.ebi.ac.uk/ena/data/view/SAMD00009891">SAMD00009891</a>
# metadata hub_created_date="Tue Feb  2 13:25:39 2016 GMT" cultivar=Nipponbare tissue_type=shoot germline=N description="Total mRNA from shoot of rice (Oryza sativa ssp. Japonica cv. Nipponbare) seedling" accession=SAMD00009891 environmental_sample=N scientific_name="Oryza sativa Japonica Group" sample_alias=SAMD00009891 tax_id=39947 center_name=BIOSAMPLE secondary_sample_accession=DRS000420 first_public=2012-01-06 

sub print_track_stanza{

  my $self = shift;
  my $fh = shift;

  print $fh "track ". $self->{track_name}."\n"; 
  print $fh "superTrack on\n";
  print $fh "shortLabel BioSample:".$self->{track_name}."\n";
  print $fh "longLabel ".$self->{long_label}."\n";
  print $fh "metadata ".$self->{metadata}."\n";
  print $fh "type cram\n";


  print $fh "\n";

}


1;