#!/usr/bin/perl
package byzip_a;
use warnings;
use strict;

#
# This file is part of byzip.pl. See information at the top of that file
#
#
# Given a file name and a list of zip code strings, return any record (row) that
# contains anything string of characters that might be a zip code
#
# While looking at the 1st record, find the offsets (column numbers) for various
# items of interest
#
sub get_records {
    my $found_csv_file = shift;
    my $zip_list_ptr = shift;
    my $report_generation_messages = shift;
    my $report_header_changes = shift;

    my $record_number = 0;
    my $header_string;
    my @header_list;
    my $cases_column_offset;
    my $zip_column_offset;
    my $reference_header_string;
    my @reference_header_list;
    my @possibly_useful_records;

    open (FILE, "<", $found_csv_file) or die "Can't open $found_csv_file: $!";
    while (my $record = <FILE>) {
        $record_number++;
        chomp ($record);

        if ($record_number == 1) {
            my $changed_flag = 0;
            my $initial_flag = 0;

            #
            # Remove BOM if any
            #
            if ($record =~ /^\xef\xbb\xbf/) {
                $header_string = substr ($record, 3);
            }
            elsif ($record =~ /^\xfe\xff\x00\x30\x00\x20\x00\x48\x00\x45\x00\x41\x00\x44/) {
                print ("  File is Unicode\n");
                die;
            }
            else {
                $header_string = $record;
            }

            if (!(defined ($reference_header_string))) {
                $reference_header_string = $header_string;
                @reference_header_list = split (',', $header_string);
                $initial_flag = 1;
            }

            if ($header_string ne $reference_header_string) {
                $reference_header_string = $header_string;
                @reference_header_list = split (',', $header_string);
                undef ($zip_column_offset);
                undef ($cases_column_offset);
                $changed_flag = 1;
            }

            my $len = @reference_header_list;
            for (my $j = 0; $j < $len; $j++) {
                my $h = lc $reference_header_list[$j];
                if ($h eq 'cases_1') {
                    $cases_column_offset = $j;
                }
                elsif ($h eq 'zip') {
                    $zip_column_offset = $j;
                }
                elsif ($h eq 'zipx') {
                    $zip_column_offset = $j;
                }
            }

            if (!(defined ($zip_column_offset))) {
                print ("Zip column offset not discovered in header\n");
                exit (1);
            }

            if ($report_generation_messages && $report_header_changes) {
                if ($changed_flag) {
                    print ("  Header change:\n");
                    print ("    'cases_1' offset is $cases_column_offset\n");
                    print ("    'zip' offset is $zip_column_offset\n");
                }
                elsif ($initial_flag) {
                    print ("  Initial header:\n");
                    print ("    'cases_1' offset is $cases_column_offset\n");
                    print ("    'zip' offset is $zip_column_offset\n");
                }
            }

            next;
        }
        
        #
        # Search for any instance of any of the zipcode string characters
        # Could be part of some totally unrelated number
        #
        my $found_zip_like_string = 0;
        foreach my $zip_to_test (@$zip_list_ptr) {
            my $j = index ($record, $zip_to_test);
            if ($j != -1) {
                $found_zip_like_string = 1;
                last;
            }
        }

        if ($found_zip_like_string == 0) {
            next;
        }

        push (@possibly_useful_records, $record);
    }

    close (FILE);

    return ($cases_column_offset, $zip_column_offset, \@possibly_useful_records);
}

1;
