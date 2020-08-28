#!/usr/bin/perl
package byzip_c;
use warnings;
use strict;

#
# This file is part of byzip.pl. See information at the top of that file
#

my $print_stuff = $main::pp_report_sim_messages;

sub process {
    my $cases_list_ptr = shift;
    my $last_serial = shift;
    my $debug_cases_list_ptr = shift;
    
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

        my $yr = $current_sim_dt->year();
        my $mo = $current_sim_dt->month();
        my $da = $current_sim_dt->day();
        my $dir_string = sprintf ("%04d-%02d-%02d", $yr, $mo, $da);

        if ($print_stuff) {
            print ("\n$dir_string...\n");
        }

        my $done_with_this_day = 0;
        my @new_cases_list;

        my $count_for_debug = 0;
        my $string_for_debug;
        while (!$done_with_this_day) {
            $count_for_debug++;

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

            if ($serial == $last_serial) {
                $done_with_this_day = 1;
            }

            if ($print_stuff) {
                #
                # Debug
                #
                my $debug_string = sprintf ("%04d-%02d-%02d to %04d-%02d-%02d",
                    $top_case_begin_dt->year(), $top_case_begin_dt->month(), $top_case_begin_dt->day(),
                    $top_case_end_dt->year(), $top_case_end_dt->month(), $top_case_end_dt->day());
                print ("\n  Case $serial: $debug_string\n");
            }

            #
            # Is it processable?
            #
            my $begin_cmp_result = DateTime->compare ($current_sim_dt, $top_case_begin_dt);
            my $end_cmp_result = DateTime->compare ($current_sim_dt, $top_case_end_dt);
            if ($print_stuff && 0) {
                print ("    \$begin_cmp_result = $begin_cmp_result\n");
                print ("    \$end_cmp_result = $end_cmp_result\n");
            }
            
            # if ($end_cmp_result == -1 && $case_state eq 'not started') {
            #     #
            #     # Startup 'bug'
            #     #
            #     $begin_cmp_result = 0;
            # }

            if ($begin_cmp_result == -1) {
                #
                # No, top case can not be processed yet
                # Put it in the new list. Use the default output line. Declare day is done
                #
                push (@new_cases_list, $top_case_ptr);
                $done_with_this_day = 1;
                $string_for_debug = 'not processed';
            }
            elsif ($begin_cmp_result == 0) {
                #
                # Start case
                # Put it in the new list. Make a new output line
                #
                push (@new_cases_list, $top_case_ptr);

                my $this_is_an_untested_positive_case = 0;
                if (exists ($top_case_ptr->{'untested_positive'})) {
                    $this_is_an_untested_positive_case = 1;
                }

                if ($this_is_an_untested_positive_case) {
                    $untested_positive_currently_sick++;
                    print ("+++ \$untested_positive_currently_sick = $untested_positive_currently_sick\n");

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
            }
            elsif ($end_cmp_result == -1) {
                #
                # In the middle of this case
                # Put it in the new list. Use the default output line
                #

                my $state = $top_case_ptr->{'sim_state'};
                if (index ($state, 'sick') == -1) {
                    print ("Found an in-progress case not marked sick\n");
                    print ("\$state = $state\n");
                    exit (1);
                }

                push (@new_cases_list, $top_case_ptr);

                $string_for_debug = 'ongoing';
            }
            elsif ($end_cmp_result == 0) {
                #
                # Ending a case
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
                    print ("--- \$untested_positive_currently_sick = $untested_positive_currently_sick\n");
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
            }
            elsif ($end_cmp_result == 1) {
                #
                # Case ended before the current sim date
                # Do NOT put it in the new list
                #
            }
            else {
                print ("No clue how this happened\n");

                my @debug_cases_list = @$debug_cases_list_ptr;
                my $max_lines = @debug_cases_list;
                my $first_line_to_print = $count_for_debug - 100;
                if ($first_line_to_print < 0) {
                    $first_line_to_print = 0;
                }
                my $last_line_to_print = $count_for_debug + 100;
                if ($last_line_to_print > $max_lines - 1) {
                    $last_line_to_print = $max_lines - 1;
                }

                for (my $i = $first_line_to_print; $i <= $last_line_to_print; $i++) {
                    print ("$debug_cases_list[$i]\n");
                }

                my $debug_string = sprintf ("%04d-%02d-%02d",
                    $current_sim_dt->year(), $current_sim_dt->month(), $current_sim_dt->day());
                # print ("  \$current_sim_dt is $debug_string\n");
                print ("  Sim pass $count_for_debug is doing $debug_string\n");

                my $end_debug_string = sprintf ("%04d-%02d-%02d",
                    $top_case_end_dt->year(), $top_case_end_dt->month(), $top_case_end_dt->day());
                # print ("  \$top_case_end_dt is $debug_string\n");

                my $begin_debug_string = sprintf ("%04d-%02d-%02d",
                    $top_case_begin_dt->year(), $top_case_begin_dt->month(), $top_case_begin_dt->day());
                print ("  Case is sick: $begin_debug_string to $end_debug_string\n");

                print ("  \$begin_cmp_result = $begin_cmp_result\n");
                print ("  \$end_cmp_result = $end_cmp_result\n");
                exit (1);
            }

            if ($print_stuff) {
                    # print ("    \$count_for_debug = $count_for_debug  $string_for_debug\n");
                print ("    $string_for_debug\n");
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
