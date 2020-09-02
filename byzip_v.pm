#!/usr/bin/perl
package byzip_v;
use warnings;
use strict;

#
# This file is part of byzip.pl. See information at the top of that file
#

my $print_stuff = 1;

sub verify_case_list {
    my $case_list_ptr = shift;

    if ($print_stuff) {
        print ("Case verify routine...\n");
    }

    my @cases_list = @$case_list_ptr;
    my $largest_serial = -1;
    my $last_serial;

    my %serials;
    foreach my $cl (@cases_list) {
        $last_serial = $cl->{'serial'};
        if (exists ($serials{$last_serial})) {
            print ("  Duplicate serial is $last_serial\n");
            exit (1);
        }
    }

    my $previous_begin_dt;
    my $index = 0;

    my $temp_dt = $cases_list[0]->{'begin_dt'};
    my $first_case_begin_dt = $temp_dt->clone();
    my $first_case_string = main::make_printable_date_string ($first_case_begin_dt);
    if ($print_stuff) {
        print ("  First simulation date is $first_case_string\n");
    }

    foreach my $tc (@cases_list) {
        my $being_tested_dt = $tc->{'begin_dt'};
        my $being_tested_string = main::make_printable_date_string ($being_tested_dt);

        if (!(defined ($being_tested_dt))) {
            print ("  Start is undefined in $being_tested_string\n");
            exit (1);
        }

        #
        # compute_days_diff (from, to)
        #
        my $dur_days = compute_days_diff ($first_case_begin_dt, $being_tested_dt);

        # print ("$being_tested_string - $first_case_string = $dur_days days\n");

        if (!(defined ($previous_begin_dt))) {
            $previous_begin_dt = $being_tested_dt->clone();
        }
        else {
            $dur_days = compute_days_diff ($previous_begin_dt, $being_tested_dt);
            # my $diff = DateTime->compare ($being_tested_dt, $previous_begin_dt);
            if ($dur_days < 0) {
                my $previous_string = main::make_printable_date_string ($previous_begin_dt);
                print ("  $being_tested_string before $previous_string\n");
                exit (1);
            }
        }

        my $end_dt = $tc->{'end_dt'};
        my $s = $tc->{'serial'};
        if ($s > $largest_serial) {
            $largest_serial = $s;
        }
    }

    print ("  Verify complete\n");

    return ($last_serial, $largest_serial);
}

sub compute_days_diff {
    my $from_dt = shift;
    my $to_dt = shift;

    my $duration;
    my $from_epoch = $from_dt->epoch();
    my $to_epoch = $to_dt->epoch();

    my $dur_to_days = 86400;
    # if (0) {
        # my $diff = DateTime->compare ($being_tested_dt, $first_case_begin_dt);
    # }
    # elsif (0) {
        # $duration = $being_tested_dt->subtract_datetime ($first_case_begin_dt);
        # $dur_days = $duration->days();
    # }
    # elsif (0) {
        # $duration = $first_case_begin_dt->subtract_datetime ($being_tested_dt);
        # $dur_days = $duration->days();
    # }
    # elsif (0) {
        # $duration = $first_case_epoch - $being_tested_epoch;
        # if ($duration == 0) {
        #     $dur_days = 0;
        # }
        # else {
        #     $dur_days = $duration / $dur_to_days;
        # }
    # }
    # else {
        $duration = $to_epoch - $from_epoch;
        if ($duration == 0) {
            return (0);
        }
        else {
            return ($duration / $dur_to_days);
        }
    # }

}

1;
