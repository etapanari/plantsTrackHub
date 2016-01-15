package TransformDate;


use strict ;
use warnings;


my %months = (
        "jan" => "01",
        "feb" => "02",
        "mar" => "03",
        "apr" => "04",
        "may" => "05",
        "jun" => "06",
        "jul" => "07",
        "aug" => "08",
        "sep" => "09",
        "oct" => "10",
        "nov" => "11",
        "dec" => "12",
        "Jan" => "01",
        "Feb" => "02",
        "Mar" => "03",
        "Apr" => "04",
        "May" => "05",
        "Jun" => "06",
        "Jul" => "07",
        "Aug" => "08",
        "Sep" => "09",
        "Oct" => "10",
        "Nov" => "11",
        "Dec" => "12",
        "January" => "01",
        "February" => "02",
        "March" => "03",
        "April" => "04",
        "June" => "06",
        "July" => "07",
        "Aug" => "08",
        "September" => "09",
        "October" => "10",
        "November" => "11",
        "December" => "12"
);



sub change_date {

 my $date = shift;

 if($date =~/(jan|January|Jan|feb|Feb|February|mar|March|Mar|apr|Apr|April|may|May|jun|Jun|June|jul|Jul|July|aug|Aug|August|sept|Sept|September|oct|Oct|October|nov|Nov|November|dec|Dec|December)/){
   my $month = $1;
   my $correct_month = $months{$month};
   $date =~ s/$month/$correct_month/;
 }
 return $date;

}

1