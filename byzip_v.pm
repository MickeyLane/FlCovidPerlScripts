#!/usr/bin/perl
package byzip_v;
use warnings;
use strict;

#
# This file is part of byzip.pl. See information at the top of that file
#

my $print_stuff = $main::pp_report_sim_messages;

sub verify_case_list {
    my $case_list_ptr = shift;

    my @cases_list = @$case_list_ptr;
    
    my @debug_cases_list;
    my $last_serial = -1;
    my $index = 0;

    my $temp_dt = $cases_list[0]->{'begin_dt'};
    my $first_case_begin_dt = $temp_dt->clone();

    my $previous_begin_dt;

    foreach my $tc (@cases_list) {
        my $begin_dt = $tc->{'begin_dt'};
        if (!(defined ($begin_dt))) {
            print ("Start is undefined at byzip_v() " . __LINE__ . "\n");
            exit (1);
        }

        my $diff = DateTime->compare ($begin_dt, $first_case_begin_dt);
        if ($diff == -1) {
            my $left_string = sprintf ("%04d-%02d-%02d", $begin_dt->year(), $begin_dt->month(), $begin_dt->day());
            my $right_string = sprintf ("%04d-%02d-%02d", $first_case_begin_dt->year(), $first_case_begin_dt->month(), $first_case_begin_dt->day());
            print ("In byzip_v(), found start date $left_string before first sim $right_string\n");
            exit (1);
        }

        if (!(defined ($previous_begin_dt))) {
            $previous_begin_dt = $begin_dt->clone();
        }
        else {
            $diff = DateTime->compare ($begin_dt, $previous_begin_dt);
            if ($diff == -1) {
                my $left_string = sprintf ("%04d-%02d-%02d", $begin_dt->year(), $begin_dt->month(), $begin_dt->day());
                my $right_string = sprintf ("%04d-%02d-%02d", $previous_begin_dt->year(), $previous_begin_dt->month(), $previous_begin_dt->day());
                print ("In byzip_v(), found start date $left_string before first sim $right_string\n");
                exit (1);
            }
        }

        my $end_dt = $tc->{'end_dt'};
        my $s = $tc->{'serial'};
        if ($s > $last_serial) {
            $last_serial = $s;
        }

        my $debug_string = sprintf ("%03d  serial: %03d  begin date: %04d-%02d-%02d",
            $index++,
            $s,
            $begin_dt->year(), $begin_dt->month(), $begin_dt->day());
        push (@debug_cases_list, $debug_string);
        # print ("$s is $debug_string\n");

    }

    return ($last_serial, \@debug_cases_list);
}

1;
