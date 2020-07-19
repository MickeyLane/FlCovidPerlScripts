#!/usr/bin/perl
package html_xls_to_csv_a;
use warnings FATAL => 'all';
use strict;

#
#
#
sub get_tagged_element {
    my $html = shift;   # the block of something that contains one or more 
                         # tagged <...></...> structures
    my $tag = shift;

    my $rowspan = 1;
    my $colspan = 1;

    my $begin_search_string = "<$tag";
    my $end_search_string = "</$tag>";

    my $start = index ($html, $begin_search_string);
    if ($start == -1) {
        # $start = index ($block, '<td ');
        # if ($start == -1) {
            return (0, undef, undef);
        # }
    }

    my $end = index ($html, $end_search_string);
    if ($end == -1) {
        return (0, undef, undef);
    }

    my $len = $end - $start + (length ($tag) + 3);

    my $tagged_block = substr ($html, $start, $len);

    my $new_html_left = substr ($html, 0, $start);
    my $new_html_right = substr ($html, $end + (length ($tag) + 3));
    my $new_html = $new_html_left . $new_html_right;

    #
    #
    #
    my $left_angle = index ($tagged_block, '<');
    my $right_angle = index ($tagged_block, '>');
    if ($left_angle != 0) {
        die;
    }

    my $begin_tag = substr ($tagged_block, $left_angle, $right_angle);
    my $element_plus_end_tag = substr ($tagged_block, $right_angle + 1);
    $left_angle = rindex ($element_plus_end_tag, '<');
    my $element = substr ($element_plus_end_tag, 0, $left_angle);

    if ($begin_tag ne "<$tag>") {
        if ($begin_tag =~ /colspan="(\d+)"/) {
            $colspan = $1;
        }
        if ($begin_tag =~ /rowspan="(\d+)"/) {
            $rowspan = $1;
        }
    }

    return (1, $element, $rowspan, $colspan, $new_html);
}

if (1) {
    my $html_1 = '<head><td colspan="14" rowspan="1">';
    my $html_2 = "<div style='font-weight:bold' " . 'title="Measures, MeasuresLevel" dmn="0">' . "Resident Deaths</div>";
    my $html_3 = "</td>stuff</head>";
    my $html =  $html_1 . $html_2 . $html_3;
        
        
    my $tag = 'td';

    my ($status, $element, $rowspan, $colspan, $new_html) = get_tagged_element ($html, $tag);

    if (!$status) {
        print ("Bad status\n");
        exit (1);
    }

    if ($element ne $html_2) {
        print ("Bad element\n");
        print ("$element\n");
    }
    elsif ($colspan != 14) {
        print ("Bad colspan is $colspan\n");
    }
    elsif ($rowspan != 1) {
        print ("Bad rowspan\n");
    }
    elsif ($new_html ne '<head>stuff</head>') {
        print ("Bad new_html\n");
    }
    else {
        print ("Pass\n");
    }
}