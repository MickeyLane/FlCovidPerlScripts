#!/usr/bin/perl
package byzip_b;
use warnings;
use strict;

#
# This file is part of byzip.pl. See information at the top of that file
#

sub validate_records {
    my $dir = shift;
    my $ptr = shift;
    my $cases_column_offset = shift;
    my $zip_column_offset = shift;
    my $zip_list_ptr = shift;
    my $print_stuff = shift;

    my @possibly_useful_records = @$ptr;
    my @useful_records;
    
    my $dir_printed = 0;

    foreach my $record (@possibly_useful_records) {
        $dir_printed = 0;
        #
        # Delete fields wrapped in double quotes. They could contain commas
        #
        my $delete_done = 0;
        while (!$delete_done) {
            my $left_double_quote = index ($record, '"');
            if ($left_double_quote != -1) {
                my $right_double_quote = index ($record, '"', $left_double_quote + 1);
                my $left_half = substr ($record, 0, $left_double_quote);
                my $right_half = substr ($record, $right_double_quote + 1);
                $record = $left_half . $right_half;
            }
            else {
                $delete_done = 1;
            }
        }

        my @list = split (',', $record);

        my $this_zip = $list[$zip_column_offset];
        if ($print_stuff) {
            print ("  \$this_zip = $this_zip\n");
        }

        #
        # Zips are frequently given as "Hillsborough-33540" etc. Only 33540 is of interest
        # Replace the column value with just the 5 digits
        #
        my $zip_from_this_record;
        my $zip_is_good = 0;
        if ($this_zip =~ /(\d{5})/) {
            $zip_from_this_record = $1;
            foreach my $zip_to_test (@$zip_list_ptr) {
                if ($zip_to_test == $zip_from_this_record) {
                    $zip_is_good = 1;
                    # last;
                }
            }
        }
        else {
            print ("Unable to locate 5 consecutive digits in what is supposed to be the zip code column\n");
            exit (1);
        }

        if (!$zip_is_good) {
            next;
        }

        my $cases = $list[$cases_column_offset];
        if ($print_stuff) {
            print ("  \$cases = $cases\n");
        }

        if (length ($cases) eq 0) {
            print ("  Null cases column found at offset $cases_column_offset\n");
            exit (1);
        }

        #
        # If cases equal zero, ignore
        #
        if ($cases eq '0') {
            next;
        }

        #
        # If the 1st char is '<', ignore
        #
        my $first_cases_character = substr ($cases, 0, 1);
        if ($first_cases_character eq '<') {
            next;
        }

        #
        # If '5 to 9'
        #
        if ($cases eq '5 to 9') {
            if ($dir_printed == 0) {
                print ("$dir...\n");
                $dir_printed = 1;
            }

            print ("  Changing '5 to 9' to 7\n");
            $cases = '7';
        }

        #
        # If something other tha a simple number, complain
        #
        if ($cases =~ /[\D]/) {
            if ($dir_printed == 0) {
                print ("$dir...\n");
            }
            print ("  Non numeric found in cases field is $cases\n");
            exit (1);
        }

        #
        # Test for a negative value string. Probably not found anywhere
        #
        my $negative_value_flag = 0;
        if ($first_cases_character eq '-') {
            $negative_value_flag = 1;
            my $new_cases_string = substr ($cases, 1);
            $cases = $new_cases_string;
            print ("Negative value found in cases column\n");
            exit (1);
        }

        #
        # Update fields and make a new record
        #
        $list[$cases_column_offset] = $cases;
        $list[$zip_column_offset] = $zip_from_this_record;
        my $new_record = join (',', @list);
        push (@useful_records, $new_record);
    }

    return (\@useful_records);
}

1;
