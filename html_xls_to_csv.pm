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
    # BODY
    #
    
    my ($status, $body, $rowspan, $colspan, $new_html) = html_xls_to_csv_a::get_tagged_element ($html, 'body');
    if (!$status) {
        if ($verbose) {
            print ("Unable to isolate the body\n");
        }
        return (0, undef);
    }

    # print ("Body is $body_len characters\n");

    $html = $new_html;


    #
    # TABLE
    #
    my $table;
    ($status, $table, $rowspan, $colspan, $new_html) = html_xls_to_csv_a::get_tagged_element ($body, 'table');
    if (!$status) {
        if ($verbose) {
            print ("Unable to isolate the table\n");
        }
        return (0, undef);
    }

    # print ("Table is $table_len characters\n");
    # print ("Body is now $body_len characters\n");

    $body = $new_html;

    # open (FILE, ">", "body.txt") or die "Can not open body.txt: $!";
    # print (FILE $body);
    # close (FILE);

    #
    # THEAD
    #
    my $thead;
    ($status, $thead, $rowspan, $colspan, $new_html) = html_xls_to_csv_a::get_tagged_element ($table, 'thead');
    if (!$status) {
        if ($verbose) {
            print ("Unable to isolate the table head\n");
        }
        return (0, undef);
    }

    $table = $new_html;

    # print ("Thead is $thead_len characters\n");
    # print ("Table is now $table_len characters\n");

    # open (FILE, ">", "thead.txt") or die "Can not open thead.txt: $!";
    # print (FILE $thead);
    # close (FILE);

    # open (FILE, ">", "table.txt") or die "Can not open table.txt: $!";
    # print (FILE $table);
    # close (FILE);

    #
    # TBODY
    #
    my $tbody;
    ($status, $tbody, $rowspan, $colspan, $new_html) = html_xls_to_csv_a::get_tagged_element ($table, 'tbody');
    if (!$status) {
        if ($verbose) {
            print ("Unable to isolate the table body\n");
        }
        return (0, undef);
    }

    $table = $new_html;

    # print ("Tbody is $tbody_len characters\n");
    # print ("Table is now $table_len characters\n");

    # open (FILE, ">", "tbody.txt") or die "Can not open tbody.txt: $!";
    # print (FILE $tbody);
    # close (FILE);

    my @out_file;

    #
    # BODY LINES
    #
    # This allows the determination of the overall line length
    #
    my @body_csv_records;
    my $new_block_of_html;
    my $csv_record;
    $status = 1;
    while ($status) {
        ($status, $csv_record, $new_block_of_html) = tbody_lines ($tbody);
        if ($status) {
            push (@body_csv_records, $csv_record);
            $tbody = $new_block_of_html;
        }
    }

    my $out_file_csv_comma_count = ($body_csv_records[0] =~ tr/,/,/);

    #
    # OTHER
    #
    my @thead_csv_records;
    $status = 1;
    while ($status) {
        ($status, $csv_record, $new_block_of_html) = get_a_thead_row ($thead, $out_file_csv_comma_count);
        if ($status) {
            if (!(defined ($csv_record))) {
                die;
            }
            push (@thead_csv_records, $csv_record);
            $thead = $new_block_of_html;
        }
    }

    if (!@thead_csv_records) {
        die;
    }

    #
    # TOP 2 LINES
    #
    my $top_csv_records_ptr = top_lines ($body, $out_file_csv_comma_count, $commas);

    #
    # MAKE CSV
    #
    push (@out_file, @$top_csv_records_ptr);
    push (@out_file, @thead_csv_records);
    push (@out_file, @body_csv_records);

    # #
    # #
    # #
    # my $out_fn = $fn;
    # $out_fn =~ s/xls\z/csv/;
    # open (FILE, ">", $out_fn) or die "Can not open $out_fn: $!";
    # foreach my $rr (@out_file) {
    #     print (FILE "$rr\n");
    # }
    # close (FILE);

    # exit (1);

    return (1, \@out_file);
}

sub top_lines {
    my $body = shift;
    my $out_file_csv_comma_count = shift;
    my $commas = shift;

    print ("\$out_file_csv_comma_count = $out_file_csv_comma_count\n");

    my @out_file;

    my $begin = '<body><b>';
    if (!$body =~ /^\Q$begin/) {
        die;
    }
    my $start_br = 9;
    my $end_br = index ($body, '<br />');
    my $br_len = $end_br - $start_br;
    my $r = substr ($body, 9, $end_br - $start_br);

    $r .= substr ($commas, 0, $out_file_csv_comma_count);

    push (@out_file, $r);

    my $new_body = substr ($body, $end_br + 6);

    $br_len = index ($new_body, '<br />');
    $r = substr ($new_body, 0, $br_len);

    $r .= substr ($commas, 0, $out_file_csv_comma_count);

    push (@out_file, $r);

    return (\@out_file);
}


#
# Typical output:
#
#    Miami-Dade,1,1,1,1,1,1,1,1,1,1,1,4,5,5
#
sub tbody_lines {
    my $tbody = shift;

    my @out_file_csv_record_list;
    my $out_file_csv_record;

    my ($status, $trow, $new_tbody) = get_trow ($tbody);
    if ($status) {
        $tbody = $new_tbody;
        my $tbody_len = length ($tbody);

        my $trow_len = length ($trow);

        print ("Trow is $trow_len characters\n");
        print ("Tbody is now $tbody_len characters\n");

        #
        # TROW HEADER
        #
        my $theader_start = index ($trow, '<th ');
        my $theader_end = index ($trow, '</th>');
        my $theader_len = $theader_end - $theader_start + 5;

        my $theader = substr ($trow, $theader_start, $theader_len);
        if (!$theader =~ /\<\/th\>\z/) {
            die;
        }
        if (!$theader =~ /^\<th /) {
            die;
        }
        my $theader_len_2 = length ($theader);
        if ($theader_len != $theader_len_2) {
            die;
        }

        my $new_trow_left = substr ($trow, 0, $theader_start);
        my $new_trow_right = substr ($trow, $theader_end + 5);
        $trow = $new_trow_left . $new_trow_right;
        $trow_len = length ($trow);

        my $h = get_argument ($theader);
        push (@out_file_csv_record_list, $h);

        print ("Theader is $theader_len characters\n");
        print ("Trow is now $trow_len characters\n");

        open (FILE, ">", "trow.txt") or die "Can not open trow.txt: $!";
        print (FILE $trow);
        close (FILE);

        # print ("  $h\n");

        my $done = 0;
        while (!$done) {
            my $begin = index ($trow, '<td');
            if ($begin != -1) {
                my $end = index ($trow, '</td>');
                my $len = $end - $begin + 5;
                my $td = substr ($trow, $begin, $len);
                my $td_arg = get_argument ($td);
                my $left = substr ($trow, 0, $begin);
                my $right = substr ($trow, $end + 5);
                $trow = $left . $right;
                # print ("$td\n");
                push (@out_file_csv_record_list, $td_arg);

                # print ("    $td_arg\n");
            }
            else {
                $done = 1;
            }
        }

        $out_file_csv_record = join (',', @out_file_csv_record_list);

    }

    return ($status, $out_file_csv_record, $tbody);
}

sub get_argument {
    my $theader = shift;

    my $left = index ($theader, '>') + 1;
    my $right = rindex ($theader, '<');

    my $len = $right - $left;

    my $header_argument = substr ($theader, $left, $len);


    return ($header_argument);
}

sub get_trow {
    my $block = shift;   # the block of something that contains one or more 
                         # trow <tr></tr> structures

    my $start = index ($block, '<tr>');
    if ($start == -1) {
        $start = index ($block, '<tr ');
        if ($start == -1) {
            return (0, undef, undef);
        }
    }

    my $end = index ($block, '</tr>');
    my $len = $end - $start + 5;

    my $trow = substr ($block, $start, $len);
    if (!$trow =~ /\<\/tr\>\z/) {
        die;
    }
    if (!$trow =~ /^\<tr/) {
        die;
    }
    my $len_2 = length ($trow);
    if ($len != $len_2) {
        die;
    }

    my $new_block_left = substr ($block, 0, $start);
    my $new_block_right = substr ($block, $end + 5);
    $block = $new_block_left . $new_block_right;
    # $block_len = length ($block);

    return (1, $trow, $block);
}

#
# <td rowspan="5">
# <div style='font-weight:bold'>     </div>
# </td>
#
sub get_td_with_span {
    my $block = shift;   # the block of something that contains one or more 
                         # td <td></td> structures

    my $span = 1;

    my $start = index ($block, '<td>');
    if ($start == -1) {
        $start = index ($block, '<td ');
        if ($start == -1) {
            return (0, undef, undef);
        }
    }

    my $end = index ($block, '</td>');
    my $len = $end - $start + 5;

    my $td = substr ($block, $start, $len);
    if (!$td =~ /\<\/td\>\z/) {
        die;
    }
    if (!$td =~ /^\<td/) {
        die;
    }
    my $len_2 = length ($td);
    if ($len != $len_2) {
        die;
    }

    my $new_block_left = substr ($block, 0, $start);
    my $new_block_right = substr ($block, $end + 5);
    $block = $new_block_left . $new_block_right;
    # $block_len = length ($block);

    return (1, $td, $span, $block);
}

# sub get_a_thead_row {
#     my $thead = shift;

#     my @out_file_csv_record_list;
#     my $out_file_csv_record;

#     my ($status, $trow, $new_thead) = get_trow ($thead);
#     if ($status == 0) {
#         return (0);
#     }

#     $thead = $new_thead;
#     my $thead_len = length ($thead);
#     my $trow_len = length ($trow);

#     print ("In get_a_thead_row(), trow is $trow_len characters\n");
#     print ("  Thead is now $thead_len characters\n");

#     #
#     # TROW HEADER
#     #
#     my $theader_start = index ($trow, '<th ');
#     my $theader_end = index ($trow, '</th>');
#     my $theader_len = $theader_end - $theader_start + 5;

#     my $theader = substr ($trow, $theader_start, $theader_len);
#     if (!$theader =~ /\<\/th\>\z/) {
#         die;
#     }
#     if (!$theader =~ /^\<th /) {
#         die;
#     }
#     my $theader_len_2 = length ($theader);
#     if ($theader_len != $theader_len_2) {
#         die;
#     }
# q
        # my $new_trow_left = substr ($trow, 0, $theader_start);
        # my $new_trow_right = substr ($trow, $theader_end + 5);
        # $trow = $new_trow_left . $new_trow_right;
        # $trow_len = length ($trow);

        # my $h = get_argument ($theader);
        # push (@out_file_csv_record_list, $h);

        # print ("Theader is $theader_len characters\n");
        # print ("Trow is now $trow_len characters\n");

        # open (FILE, ">", "trow.txt") or die "Can not open trow.txt: $!";
        # print (FILE $trow);
        # close (FILE);

        # # print ("  $h\n");

        # my $done = 0;
        # while (!$done) {
        #     my $begin = index ($trow, '<td');
        #     if ($begin != -1) {
        #         my $end = index ($trow, '</td>');
        #         my $len = $end - $begin + 5;
        #         my $td = substr ($trow, $begin, $len);
        #         my $td_arg = get_argument ($td);
        #         my $left = substr ($trow, 0, $begin);
        #         my $right = substr ($trow, $end + 5);
        #         $trow = $left . $right;
        #         # print ("$td\n");
        #         push (@out_file_csv_record_list, $td_arg);

        #         # print ("    $td_arg\n");
        #     }
        #     else {
        #         $done = 1;
        #     }
        # }

        # $out_file_csv_record = join (',', @out_file_csv_record_list);

#     }

#     return ($status, $out_file_csv_record, $tbody);
# }

1;
