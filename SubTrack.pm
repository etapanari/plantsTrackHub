package SubTrack;

use strict;
use warnings;


## this is a class of all the track data of a track stanza in the trackDb.txt file

sub new {

    my $class = shift;
    my $track_name = shift;
    my $parent_name = shift;
    my $big_data_url = shift;
    my $short_label = "BioSample $track_name";
    my $long_label= shift;
    my $type = shift;

    my $self = {
      track_name => $track_name,
      parent_name => $parent_name,
      big_data_file_url => $big_data_url,
      short_label => $short_label,
      long_label => $long_label,
      file_type => $type
    };

   return bless $self, $class; # this is what makes a reference into an object
}


sub name{

  my $self = shift;
  return $self->{track_name};
}

sub parent_name{

  my $self = shift;
  return $self->{parent_name};
}

sub big_data_url{

  my $self = shift;
  return $self->{big_data_file_url};
}

sub short_label {

  my $self = shift;
  return $self->{short_label};
}

sub long_label{

  my $self = shift;
  return $self->{long_label};
}

sub big_data_file_type{

  my $self = shift;
  return $self->{file_type};
}
1;