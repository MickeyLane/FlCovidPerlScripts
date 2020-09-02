#!/usr/bin/perl
package byzip_plot;
use warnings;
use strict;

#
# This file is part of byzip.pl. See information at the top of that file
#

use GD::Graph::points;
use GD::Graph::lines;

sub make_plot {
    my $dir = shift;
    my $csv_ptr = shift;
    my $title = shift;

    my @data;
    
    my @csv_array = @$csv_ptr;
    my $column_titles = shift (@csv_array);

    my @new_array;

    my @header_array;

    my @cured_1_array;
    my @cured_2_array;
    my @cured_3_array;

    my @sick_1_array;
    my @untested_positive_sick_1_array;
    my @sick_2_array;
    my @untested_positive_sick_2_array;
    my @sick_3_array;
    my @untested_positive_sick_3_array;

    my @dead_1_array;
    my @dead_2_array;
    my @dead_3_array;

    my $len = @$csv_ptr;
    for (my $i = 0; $i < $len; $i++) {
        my @columns = split (',', $csv_array[$i]);
        my $column_index = 0;

        #
        # Date is column [0]
        #
        $header_array[$i] = $columns[$column_index++];

        $cured_1_array[$i] = $columns[$column_index++];
        $sick_1_array[$i] = $columns[$column_index++];
        $untested_positive_sick_1_array[$i] = $columns[$column_index++];
        $dead_1_array[$i] = $columns[$column_index++];
        
        $cured_2_array[$i] = $columns[$column_index++];
        $sick_2_array[$i] = $columns[$column_index++];
        $untested_positive_sick_2_array[$i] = $columns[$column_index++];
        $dead_2_array[$i] = $columns[$column_index++];
        
        $cured_3_array[$i] = $columns[$column_index++];
        $sick_3_array[$i] = $columns[$column_index++];
        $untested_positive_sick_3_array[$i] = $columns[$column_index++];
        $dead_3_array[$i] = $columns[$column_index++];
    }

    push (@data, \@header_array);

    push (@data, \@cured_1_array);
    push (@data, \@sick_1_array);
    push (@data, \@untested_positive_sick_1_array);
    push (@data, \@dead_1_array);

    push (@data, \@cured_2_array);
    push (@data, \@sick_2_array);
    push (@data, \@untested_positive_sick_2_array);
    push (@data, \@dead_2_array);

    push (@data, \@cured_3_array);
    push (@data, \@sick_3_array);
    push (@data, \@untested_positive_sick_3_array);
    push (@data, \@dead_3_array);

    my $graph_file = "$dir/graph.gif";

    my $graph = GD::Graph::lines->new (1500, 750);
    $graph->set( 
            x_label 	=> 'Dates', 
            y_label 	=> 'Cases', 
            title  		=> $title, 
            #cumulate 	=> 1, 
            dclrs 		=> [ 'green', 'orange', 'blue', 'red' ], 
            borderclrs 	=> [ qw(black black), qw(black black) ], 
            bar_spacing => 4, 
            transparent => 1,
            show_values => 0
    ); 

    my $gd = $graph->plot(\@data) or die $graph->error; 

    open(IMG, ">","$graph_file") or die $!;
    binmode IMG;
    print IMG $gd->gif;
    close IMG;

}

1;
