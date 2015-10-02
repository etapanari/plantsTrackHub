  

  use strict ;
  use warnings;


  my $file = $ARGV[0];

  my %hash;

   open(IN, $file) or die "Can't open $file\n";

        while(<IN>){

           chomp;
           my @words = split(/\t/, $_);
           $hash {$words[0]} ++;

        }

   close(IN);



  foreach my $key (keys %hash ){
    
     print $key . "\t" . $hash{$key} . "\n";

  }