package Helper;

use strict ;
use warnings;

sub run_system_command {

  my $command = shift;

  my $output = `$command`; # for example "mkdir", or "rm" , or "touch"

  if($? !=0){ # if exit code of the system command is successful returns 0
    
    return 0 ;

  }else{ # success

    return 1;
  }
}

sub run_system_command_with_output {

  my $command = shift;

  my $output = `$command`;  # for example ls (ls could return a list or nothing if dir is empty)

  if($? !=0){ # if exit code of the system command is successful returns 0
    
    return (0,"") ;

  }else{  # if command is run successfully

    if($output){

      return (1,$output);

    }else{

      return (1,"");
    }
  }
}

1;