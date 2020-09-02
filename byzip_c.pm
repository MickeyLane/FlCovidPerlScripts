#!/usr/bin/perl
package byzip_c;
use warnings;
use strict;

#
# This file is part of byzip.pl. See information at the top of that file
#


sub process {
    my $cases_list_ptr = shift;
    my $last_serial = shift;
    my $debug_cases_list_ptr = shift;
    my $print_stuff = shift;
    
    my $running_total_of_dead = 0;
    my $running_total_of_cured = 0;
    my $currently_sick = 0;
    my $untested_positive_currently_sick = 0;

    my @cases_list = @$cases_list_ptr;
    my $case_count = @cases_list;

    my @output_csv;

    my $one_day_duration_dt = DateTime::Duration->new (days => 1);

    #
    # Get the earliest and latest dates in the list of cases to
    # establish sim run time
    #
    my $temp_hash_ptr = $cases_list[0];
    my $first_simulation_dt = $temp_hash_ptr->{'begin_dt'};

    $temp_hash_ptr = $cases_list[$case_count - 1];
    my $last_simulation_dt = $temp_hash_ptr->{'begin_dt'};

    my $done = 0;
    my $current_sim_dt = $first_simulation_dt->clone();
    my $top_case_end_dt;
    my $output_line;
    my $do_startup_safty_check = 1;

    while (!$done) {
        if ($do_startup_safty_check) {
            if (!(defined ($current_sim_dt))) {
                print ("It's broken, Jim\n");
                exit (1);
            }
            $do_startup_safty_check = 0;
        }

        my $dir_string = main::make_printable_date_string ($current_sim_dt);

        if ($print_stuff) {
            print ("\n$dir_string...\n");
        }

        my $done_with_this_day = 0;
        my @new_cases_list;

         my $current_sim_epoch = $current_sim_dt->epoch();

        my $string_for_debug;
        while (!$done_with_this_day) {
            #
            # Make a default output line
            #
            $output_line = sprintf ("%s,%d,%d,%d,%d",
                $dir_string,
                $running_total_of_cured,
                $currently_sick,
                $untested_positive_currently_sick,
                $running_total_of_dead);

            #
            # Get the next case
            #
            my $top_case_ptr = shift (@cases_list);

            my $top_case_begin_dt = $top_case_ptr->{'begin_dt'};
            if (!(defined ($top_case_begin_dt))) {
                print ("Begin date is undefined\n");
                exit (1);
            }
            my $top_case_end_dt = $top_case_ptr->{'end_dt'};
            if (!(defined ($top_case_end_dt))) {
                print ("End date is undefined\n");
                exit (1);
            }
            my $serial = $top_case_ptr->{'serial'};
            my $case_state = $top_case_ptr->{'sim_state'};
            my $this_case_begin_epoch = $top_case_begin_dt->epoch();
            my $this_case_end_epoch = $top_case_end_dt->epoch();

            my $duration = $this_case_begin_epoch - $current_sim_epoch;
            my $days = 0;
            if ($duration > 0) {
                $days = $duration / 86400;
            }


            $days = 0;



            if ($serial == $last_serial || $days > 10) {
                $done_with_this_day = 1;

                if ($print_stuff) {
                    print ("  Processing last serial $serial in state \"$case_state\"\n");
                }
            }
            else {
                if ($print_stuff) {
                    my $b = main::make_printable_date_string ($top_case_begin_dt);
                    my $e = main::make_printable_date_string ($top_case_end_dt);
                    print ("  Processing serial $serial ($b to $e) in state \"$case_state\"\n");
                }
            }

            # my $begin_cmp_result = DateTime->compare ($current_sim_dt, $top_case_begin_dt);
            # my $end_cmp_result = DateTime->compare ($current_sim_dt, $top_case_end_dt);
            # if ($print_stuff && 0) {
            #     print ("    \$begin_cmp_result = $begin_cmp_result\n");
            #     print ("    \$end_cmp_result = $end_cmp_result\n");
            # }
            
            # if ($end_cmp_result == -1 && $case_state eq 'not started') {
            #     #
            #     # Startup 'bug'
            #     #
            #     $begin_cmp_result = 0;
            # }
            if ($this_case_end_epoch < $current_sim_epoch) {
                #
                # Case ended before the current sim date
                # Do NOT put it in the new list
                #
                print ("Found a case that ended before the current sim date\n");
                exit (1);
            }

            if ($this_case_begin_epoch > $current_sim_epoch) {
                #
                # No, top case can not be processed yet
                # Put it in the new list. Use the default output line
                #
                push (@new_cases_list, $top_case_ptr);
                # $done_with_this_day = 1;
                $string_for_debug = 'not processed';

                goto end_of_cases_for_this_sim_date;
            }

            if ($this_case_begin_epoch == $current_sim_epoch) {
                #
                # Begin
                # -----
                #
                # Put it in the new list. Make a new output line
                #
                push (@new_cases_list, $top_case_ptr);

                my $this_is_an_untested_positive_case = 0;
                if (exists ($top_case_ptr->{'untested_positive'})) {
                    $this_is_an_untested_positive_case = 1;
                }

                if ($this_is_an_untested_positive_case) {
                    $untested_positive_currently_sick++;
                    # print ("+++ \$untested_positive_currently_sick = $untested_positive_currently_sick\n");

                    $top_case_ptr->{'sim_state'} = 'untested positive sick';

                }
                else {
                    $currently_sick++;
                    $top_case_ptr->{'sim_state'} = 'sick';
                }

                $output_line = sprintf ("%s,%d,%d,%d,%d",
                    $dir_string,
                    $running_total_of_cured,
                    $currently_sick,
                    $untested_positive_currently_sick,
                    $running_total_of_dead);

                $string_for_debug = 'new';

                goto end_of_cases_for_this_sim_date;

            }


            if ($this_case_end_epoch > $current_sim_epoch) {
                #
                # In progress
                # -----------
                #
                # Put it in the new list. Use the default output line
                #
                my $state = $top_case_ptr->{'sim_state'};
                if ($state ne 'sick' && $state ne 'untested positive sick') {
                    print ("\n$dir_string...\n");
                    print ("  Found an in-progress case not marked \"sick.\" Marked \"$state\"\n");

                    byzip_debug::report_case (
                        \@new_cases_list,
                        $top_case_ptr,
                        \@cases_list);
                }

                push (@new_cases_list, $top_case_ptr);

                $string_for_debug = 'ongoing';

                goto end_of_cases_for_this_sim_date;
            }

            if ($this_case_end_epoch == $current_sim_epoch) {
                #
                # End a case
                # ----------
                #
                # Do NOT put it in the new list
                #
                my $end_status = $top_case_ptr->{'ending_status'};
                if ($end_status eq 'dead') {
                    $running_total_of_dead++;
                    $top_case_ptr->{'sim_state'} = 'dead';
                }
                elsif ($end_status eq 'cured') {
                    $running_total_of_cured++;
                    $top_case_ptr->{'sim_state'} = 'cured';
                }

                my $this_is_an_untested_positive_case = 0;
                if (exists ($top_case_ptr->{'untested_positive'})) {
                    $this_is_an_untested_positive_case = 1;
                }

                if ($this_is_an_untested_positive_case) {
                    #
                    # Debug...
                    #
                    if ($untested_positive_currently_sick < 0) {
                        print ("Attempt to move an untested positive case from sick status to cured status\n");
                        print ("untested positive count is zero\n");
                        exit (1);
                    }
                    $untested_positive_currently_sick--;
                    # print ("--- \$untested_positive_currently_sick = $untested_positive_currently_sick\n");
                }
                else {
                    $currently_sick--;
                }

                $output_line = sprintf ("%s,%d,%d,%d,%d",
                    $dir_string,
                    $running_total_of_cured,
                    $currently_sick,
                    $untested_positive_currently_sick,
                    $running_total_of_dead);

                $string_for_debug = 'ending';

                goto end_of_cases_for_this_sim_date;
            }

            print ("No clue how this happened\n");

            # my $cases_list_1_ptr = byzip_debug::make_case_list (\@new_cases_list);
            # my $cases_list_2_ptr = byzip_debug::make_case_list (\@cases_list);

            byzip_debug::report_case (
                \@new_cases_list,
                $top_case_ptr,
                \@cases_list);

end_of_cases_for_this_sim_date:

            if ($print_stuff) {
                print ("  Result: $string_for_debug\n");
            }
        }
        
        if ($print_stuff) {
            my $cnt = @new_cases_list;
            print ("  New cases list has $cnt cases\n");
        }

        push (@new_cases_list, @cases_list);
        @cases_list = @new_cases_list;

        push (@output_csv, "$output_line");

        my $d = DateTime->compare ($current_sim_dt, $last_simulation_dt);
        if ($d == 0) {
            $done = 1;
        }
        else {
            $current_sim_dt->add_duration ($one_day_duration_dt);
        }
    }

    return (\@output_csv);
}


1;
