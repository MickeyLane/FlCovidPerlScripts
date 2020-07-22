#!/usr/bin/perl
package html_xls_to_csv;
use warnings FATAL => 'all';
use strict;

use lib '.';
use html_xls_to_csv_a;

sub html_xls_to_csv {
    my $html = shift;
    my $verbose = shift // 0;

    my $commas = ',,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,';

    #
    # Get BODY
    #
    my ($status, $body, $rowspan, $colspan, $new_html) = html_xls_to_csv_a::get_tagged_element ($html, 'body');
    $html = $new_html;
    if ($status != 1) {
        if ($verbose) {
            print ("Unable to isolate the body\n");
        }
        return (0, undef);
    }

    #
    # Get TABLE
    #
    my $table;
    ($status, $table, $rowspan, $colspan, $new_html) = html_xls_to_csv_a::get_tagged_element ($body, 'table');
    $body = $new_html;
    if ($status != 1) {
        if ($verbose) {
            print ("Unable to isolate the table\n");
        }
        return (0, undef);
    }

    #
    # Get TABLE HEAD
    #
    my $thead;
    ($status, $thead, $rowspan, $colspan, $new_html) = html_xls_to_csv_a::get_tagged_element ($table, 'thead');
    $table = $new_html;
    if ($status != 1) {
        if ($verbose) {
            print ("Unable to isolate the table head\n");
        }
        return (0, undef);
    }

    #
    # Get TABLE BODY
    #
    my $tbody;
    ($status, $tbody, $rowspan, $colspan, $new_html) = html_xls_to_csv_a::get_tagged_element ($table, 'tbody');
    $table = $new_html;
    if ($status != 1) {
        if ($verbose) {
            print ("Unable to isolate the table body\n");
        }
        return (0, undef);
    }

    my @out_file;
    my @body_csv_records;

    #
    # Parse BODY LINES
    #
    # This allows the determination of the overall line length
    #
    # "Row" refers to an entire csv row including trailing commas
    #
    my $new_block_of_html;
    my $csv_record;
    $status = 1;
    while ($status == 1) {
        ($status, $csv_record, $new_block_of_html) = get_a_county_row ($tbody);
        if ($status == 1) {
            push (@body_csv_records, $csv_record);
            $tbody = $new_block_of_html;
        }
        elsif ($status == 0) {
            die;
        }
    }

    my $out_file_csv_column_count = ($body_csv_records[0] =~ tr/,/,/) + 1;
    if ($verbose) {
        print ("Output csv file has $out_file_csv_column_count columns\n");
    }

    #
    # Parse HEADER LINES
    #
    my $header_csv_record_ptr = get_header_rows ($thead, $out_file_csv_column_count, $commas, $verbose);

    #
    # Parse TOP 2 LINES
    #
    my $top_csv_records_ptr = get_top_rows ($body, $out_file_csv_column_count, $commas, $verbose);

    #
    # MAKE CSV
    #
    push (@out_file, @$top_csv_records_ptr);
    push (@out_file, @$header_csv_record_ptr);
    push (@out_file, @body_csv_records);

    return (1, \@out_file);
}

#
# <x:ExcelWorkbook><x:ExcelWorksheets><x:ExcelWorksheet><x:Name>Resident Death Counts by Year by Age by Recorded County by Residence County</x:Name><x:WorksheetOptions><x:Print><x:ValidPrinterInfo/></x:Print></x:WorksheetOptions></x:ExcelWorksheet></x:ExcelWorksheets></x:ExcelWorkbook></xml><![endif]--> 
# </head>
# <body>
# <b>Resident Death Counts by Year by Age by Recorded County by Residence County<br />
# 113 Causes of Death=Other & Unspecified Infectious/Parasitic Disease & Sequelae and Sex=Male and Race=Black and Ethnicity=Hispanic<br /></b><table cellSpacing='5' cellPadding='0' width='100%' align='center' border='1'>
sub get_top_rows {
    my $body = shift;
    my $out_file_csv_column_count = shift;
    my $commas = shift;
    my $verbose = shift // 0;

    my @out_file;

    my $begin = '<b>';
    if (!($body =~ /^\Q$begin/)) {
        die;
    }
    my $start_br = length ($begin);
    my $end_br = index ($body, '<br />');
    my $br_len = $end_br - $start_br;
    my $r = substr ($body, $start_br, $br_len);

    $r .= substr ($commas, 0, $out_file_csv_column_count - 1);

    push (@out_file, $r);

    my $new_body = substr ($body, $end_br + 6);

    $br_len = index ($new_body, '<br />');
    $r = substr ($new_body, 0, $br_len);

    $r .= substr ($commas, 0, $out_file_csv_column_count - 1);

    push (@out_file, $r);

    return (\@out_file);
}


#
# Typical input:
#
#    	<tr>
#			<th colspan="1" rowspan="1">Miami-Dade</th><td>1</td><td>1</td><td>1</td>
#               <td>1</td><td>1</td><td>1</td><td>1</td><td>1</td><td>1</td><td>1</td>
#               <td>1</td><td>4</td><td>5</td><td>5</td>
#		</tr>
#
# Typical output:
#
#    Miami-Dade,1,1,1,1,1,1,1,1,1,1,1,4,5,5
#
sub get_a_county_row {
    my $input_html = shift;
    my $verbose = shift // 0;

    my $out_file_csv_record = '';

    #
    # Get a row
    #
    my ($status, $county_row, $rowspan, $colspan, $html_to_return) = 
        html_xls_to_csv_a::get_tagged_element ($input_html, 'tr', $verbose);
    if ($status != 1) {
        #
        # Status can be 0 (error) or 2 (no more <tr> elements)
        #
        return ($status, undef, undef);
    }

    #
    # A row has a <th> followed by a bunch of <td>
    #
    my $row_header;
    my $remaining_row;
    ($status, $row_header, $rowspan, $colspan, $remaining_row) = 
        html_xls_to_csv_a::get_tagged_element ($county_row, 'th', $verbose);
    $county_row = $remaining_row;
    if ($status != 1) {
        #
        # Status can be 0 (error) or 2 (no more <tr> elements)
        #
        return ($status, undef, undef);
    }

    # print ("\$row_header = $row_header\n");
    $out_file_csv_record .= "$row_header";

    my $row_data;
    $status = 1;
    while ($status == 1) {
        ($status, $row_data, $rowspan, $colspan, $remaining_row) = 
            html_xls_to_csv_a::get_tagged_element ($county_row, 'td', $verbose);
        $county_row = $remaining_row;
        #
        # Status can be 0 (error), 1 (success) or 2 (no more <tr> elements)
        #
        if ($status == 0) {
            return ($status, undef, undef);
        }
        elsif ($status == 1) {
            # print ("\$row_data = $row_data\n");
            $out_file_csv_record .= ",$row_data";
        }
    }

    #
    # If $status is 2, the loop above terminated because there was no work to do
    # If $out_file_csv_record is not empty, return it with $status = 1
    #
    if ($status == 2 && length ($out_file_csv_record) > 0) {
        # print ("get_a_county_row() is returning status 1 with csv row \"$out_file_csv_record\"\n");
        $status = 1;
    }
    else {
        print ("get_a_county_row() is returning status $status\n");
    }

    return ($status, $out_file_csv_record, $html_to_return);
}

sub get_argument {
    my $theader = shift;

    my $left = index ($theader, '>') + 1;
    my $right = rindex ($theader, '<');

    my $len = $right - $left;

    my $header_argument = substr ($theader, $left, $len);

    # $header_argument =~ s/[^A-Za-z ]//g;

    return ($header_argument);
}

#
#   0
#  ===
# <td rowspan="5">
#   <div style='font-weight:bold'>			</div>
# </td>
#
# <td colspan="14" rowspan="1">
#   <div style='font-weight:bold' title="Measures, MeasuresLevel" dmn="0">				Resident Deaths			</div>
# </td>
#
#   1
#  ===
#
# <td colspan="13" rowspan="1">
#   <div style='font-weight:bold' title="Year, Year" dmn="1">				2020 (Provisional)			</div>
# </td>
#
# <td colspan="1" rowspan="4"  style='font-weight:bold' total="1">
#   <div style='font-weight:bold' title="Recorded County, (All)" dmn="3">				Total			</div>
# </td>
sub get_header_rows {
    my $input_html = shift;
    my $out_file_csv_column_count = shift;
    my $commas = shift;
    my $verbose = shift // 0;

    #
    # Initialize a grid
    #
    my @csv_row_matrix;
    my @csv_row_length;
    for (my $row = 0; $row < 10; $row++) {
        for (my $col = 0; $col < $out_file_csv_column_count; $col++) {
            $csv_row_matrix[$col][$row] = '';
        }
        $csv_row_length[$row] = 0;
    }
    my $current_row = 0;
    my $trow;
    my $rowspan;
    my $colspan;
    my $remaining_html = $input_html;
    my $html_to_return;
    my $new_html;

    #
    # Get a row
    #
    my $row_status = 1;
    while ($row_status == 1) {
        ($row_status, $trow, $rowspan, $colspan, $new_html) = html_xls_to_csv_a::get_tagged_element ($remaining_html, 'tr', $verbose);
        $remaining_html = $new_html;
        if ($row_status == 0) {
            return (undef);
        }
        elsif ($row_status == 1) {

            if ($rowspan != 1 || $colspan != 1) {
                die;
            }

            #
            # Iterate through the data in the header row
            #
            my $td;
            my $new_trow;
            my $data_element = 0;
            my $data_status = 1;
            # my $effective_column = -1;
            while ($data_status == 1) {
                ($data_status, $td, $rowspan, $colspan, $new_trow) = html_xls_to_csv_a::get_tagged_element ($trow, 'td', $verbose);
                $trow = $new_trow;
                if ($data_status == 0) {
                    return (undef);
                }
                elsif ($data_status == 1) {
                    print ("\nRow = $current_row, Data element = $data_element\n");
                    $data_element++;
                    #
                    # Get and trim argument. May be a null string afterwards
                    #
                    my $arg = get_argument ($td);
                    $arg =~ s/^\s+//; # leading white space
                    $arg =~ s/\s+$//; # trailing white space

                    print ("  Row span = $rowspan, col span = $colspan, arg = \"$arg\"\n");

                    #
                    #
                    #
                    my $col = $csv_row_length[$current_row];
                    for (my $row_iterator = 0; $row_iterator < $rowspan; $row_iterator++) {
                        my $row = $current_row + $row_iterator;
                        $csv_row_matrix[$col][$row] = $arg;
                        print ("  Adding \"$arg\" to col [$col] row [$row]\n");
                        $csv_row_length[$row] += $colspan;
                    }
                }
            }
            
            $current_row++;
            if ($current_row > 6) {
                die;
            }
        }
    }

    #
    # If $status is 2, the loop above terminated because there was no work to do
    # If $out_file_csv_record is not empty, return it with $status = 1
    #
    if (($row_status == 2) && ($csv_row_length[0] > 0)) {
        print ("get_a_header_row() is returning status 1\n");
        # my $cc = ($out_file_csv_record =~ tr/','//);
        # print ("  column count $cc\n");

        my @return_array;

        for (my $row = 0; $row < $current_row; $row++) {
            my $csv_row_record = $csv_row_matrix[0][$row];
            for (my $col = 1; $col < $out_file_csv_column_count; $col++) {
                $csv_row_record .= ",$csv_row_matrix[$col][$row]";
            }
            push (@return_array, $csv_row_record);
            print ("  csv row \"$csv_row_record\"\n");
        }

        return (\@return_array);
    }

    print ("\$row_status = $row_status\n");
    die;
}

1;
