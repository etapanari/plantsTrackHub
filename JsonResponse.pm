package JsonResponse;

use strict ;
use warnings;

use HTTP::Tiny;
use JSON;

my $http = HTTP::Tiny->new();

sub get_Json_response { # it returns the json response given the endpoint as param, it returns an array reference that contains hash references . If response not successful it returns 0
  
  my $url = shift; # example: "http://plantain:3000/json/70/getRunsByStudy/SRP033494";

  my $response = $http->get($url);
  my $content;
  my $json;

  if (!$response->{success}) {

    for(my $i=1; $i<=10; $i++) {
      sleep 5;
      $response = $http->get($url);

      next unless ($response->{success} and $response->{success} ==1);
      $content=$response->{content};     
      $json = decode_json($content); # it returns an array reference 
      return ($json);      
    }

    my ($status, $reason) = ($response->{status}, $response->{reason}); #LWP perl library for dealing with http
    print STDERR "ERROR in: ".__FILE__." line: ".__LINE__ ." Failed for $url! Status code: ${status}. Reason: ${reason}\n";  # if response is successful I get status "200", reason "OK"
    return 0;

  }elsif($response->{success} ==1) { # if the response is successful then I get 1 # checks the url to be correct and server to give response

    $content=$response->{content};     
    $json = decode_json($content); # it returns an array reference 

    return ($json);
  }
}


1;