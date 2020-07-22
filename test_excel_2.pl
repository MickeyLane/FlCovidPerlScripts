#!C:/Strawberry/perl/bin/perl.exe
#!/usr/bin/perl
use warnings FATAL => 'all';
use strict;

#
# This software is provided as is, where is, etc with no guarantee that it is
# fit for any purpose whatsoever. Use at your own risk. Mileage may vary.
#

use File::Find;           
use File::chdir;
use File::Basename;
use Cwd qw(cwd);
use List::Util qw (shuffle);
use POSIX;
use File::Copy;
use DateTime;
use Spreadsheet::Read qw(ReadData);

use lib '.';
use html_xls_to_csv;
use html_xls_to_csv_a;

package main;

my @ref = ("Resident Death Counts by Year by Age by Recorded County by Residence County,,,,,,,,,,,,,,",
"113 Causes of Death=Other & Unspecified Infectious/Parasitic Disease & Sequelae and Sex=Male and Race=Black and Ethnicity=Hispanic,,,,,,,,,,,,,,",
",Resident Deaths,,,,,,,,,,,,,",
",2020 (Provisional),,,,,,,,,,,,,Total",
",45-54,,,75-84,,,,,,,,,Total,",
",53,,Total,77,,80,,81,,83,,Total,,",
",Miami-Dade,Total,,Miami-Dade,Total,Miami-Dade,Total,Miami-Dade,Total,Miami-Dade,Total,,,",
"Miami-Dade,1,1,1,1,1,1,1,1,1,1,1,4,5,5",
"Total,1,1,1,1,1,1,1,1,1,1,1,4,5,5");

#
# Go to root dir
#
my $dir;
$CWD = 'D:/Covid/OiVey/2020-07-16';
my $cwd = Cwd::cwd();
print ("Current working directory is $cwd\n");

my $fq_input_file = "$cwd/FloridaDeathsReport (1) unmodified.xls";
my $fq_output_file = "$cwd/My.csv";

my @html_record_list;
open (FILE, "<", $fq_input_file) or die "Can not open $fq_input_file: $!";
while (my $record = <FILE>) {
    $record =~ s/[\r\n]+//;  # remove <cr><lf> if any
    push (@html_record_list, $record);
}


#  my @records;
# my $record;
# my $save_to_body_flag = 0;
# my $save_to_table_flag = 0;
#    my $i = index ($record, '<body>');
#     if ($save_to_body_flag == 0 && $i == -1) {
#         next;
#     }
#     if ($save_flag == 0 && $i != -1) {
#         push (@records, substr ($record, $i));
#         $save_flag = 1;
#         next;
#     }
#     if ($save_flag == 1) {
#         push (@records, $record);
#         next;
#     }
#     die;
# }
# close (FILE);

my $html = join ('', @html_record_list);
my $entire_file_len = length ($html);
# print ("Entire file is $entire_file_len characters\n");

my ($status, $csv_ptr) = html_xls_to_csv::html_xls_to_csv ($html, 1);
if (!$status) {
    print ("Fail\n");
    exit (1);
}

print ("\nPass\n");

#
#
#
my $c = @$csv_ptr;
for (my $k = 0; $k < $c; $k++) {
    my $mine = shift (@$csv_ptr);
    my $thiers = shift (@ref);

    print ("\n");
    my $cc = ($mine =~ tr/,/,/) + 1;
    print ("(me    $cc) $mine\n");
    $cc = ($thiers =~ tr/,/,/) + 1;
    print ("(Excel $cc) $thiers\n");
}
