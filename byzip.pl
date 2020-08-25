#!C:/Strawberry/perl/bin/perl.exe
#!/usr/bin/perl
use warnings FATAL => 'all';
use strict;

#
# This software is provided as is, where is, etc with no guarantee that it is
# fit for any purpose whatsoever. Use at your own risk. Mileage may vary.
#

use File::Find;           
use File::chdir;
use File::Basename;
use Cwd qw(cwd);
use List::Util qw (shuffle);
use POSIX;
use File::Copy;
use DateTime;
# use Spreadsheet::Read qw(ReadData);

use lib '.';

package main;

#
# Any variable that begins with 'fq_' is supposed to contain a fully qualified file name
# Any variable that begins with 'pp_' is a program parameter and is usually a flag to enable
# or disable some feature
#

#
# Edit the following as needed. If you are using Linux, ignore '_windows' and vice versa
#
my $fq_root_dir_for_windows = 'D:/Covid/ByZip';
my $fq_root_dir_for_linux = '/home/mickey/Covid/ByZip';
my $pp_report_header_changes = 0;
my $pp_report_collection_messages = 0;
my $pp_create_missing_directories = 0;

#
# This stuff is for the name_new_dirs routine
#
my $dur = DateTime::Duration->new(
    days        => 1);
my $now = DateTime->now;
my $last_dt;

#
# Get current directory and determine platform
#
my $cwd = Cwd::cwd();
my $windows_flag = 0;
if ($cwd =~ /^[C-Z]:/) {
    $windows_flag = 1;
}

#
# Go to root dir
#
my $dir;
if ($windows_flag) {
    $dir = lc $fq_root_dir_for_windows;
}
else {
    $dir = $fq_root_dir_for_linux;
}
$CWD = $dir;
$cwd = Cwd::cwd();
print ("Current working directory is $cwd\n");

my  $pp_output_file = "$dir/byzip-output.cvs";

my $zip;
my $mortality = 3;
my $duration_min = 9;
my $duration_max = 19;

foreach my $switch (@ARGV) {
    my $lc_switch = lc $switch;
    if (index ($lc_switch, 'zip=') != -1) {
        $zip = substr ($switch, 4);
    }
    elsif (index ($lc_switch, 'mortality=') != -1) {
        $mortality = substr ($switch, 10);
    }
    elsif (index ($lc_switch, 'duration_min=') != -1) {
        $duration_min = substr ($switch, 13);
    }
    elsif (index ($lc_switch, 'duration_max=') != -1) {
        $duration_max = substr ($switch, 13);
    }
    else {
        print ("Don't know what to do with $switch\n");
        exit (1);
    }
}

print ("Zip = $zip\n");
print ("Mortality = $mortality\n");
print ("Duration_min = $duration_min\n");
print ("Duration_max = $duration_max\n");

my @date_dirs;
my @csv_files;

if ($pp_create_missing_directories) {
    #
    # Make missing date directories
    #
    my $not_done = 1;
    while ($not_done) {
        $not_done = make_new_dirs ($dir);
    }
}

#
# Examine $dir
#
opendir (DIR, $dir) or die "Can't open $dir: $!";
while (my $fn = readdir (DIR)) {
    if ($fn =~ /^[.]/) {
        next;
    }
    my $fq_fn = "$dir/$fn";
    if (-d $fq_fn) {
        if ($fn =~ /(\d{4})-(\d{2})-(\d{2})/) {
            my $date = "$1-$2-$3";
            push (@date_dirs, "$date");
        }
    }
}

my $reference_header_string;
my @reference_header_list;
my $cases_column_offset;
my $zip_column_offset;
my @cases_list;
my $previous_cases = 0;
my $case_serial_number = 1;

#
# COLLECT DATA
# ============
#
# For each directory specified in dirs.txt, find a .csv file and make a case (or cases) in @cases_list
#
print ("Searching for .csv files...\n");
my @suffixlist = qw (.csv);
foreach my $dir (@date_dirs) {
    if ($pp_report_collection_messages) {
        print ("$dir...\n");
    }

    opendir (DIR, $dir) or die "Can't open $dir: $!";

    my $found_csv_file;

    while (my $rel_filename = readdir (DIR)) {
        #
        # Convert the found relative file name into a fully qualified name
        # If it turns out to be a subdirectory, ignore it
        #
        my $fq_filename = "$dir/$rel_filename";
        if (-d $fq_filename) {
            next;
        }

        my ($name, $path, $suffix) = fileparse ($fq_filename, @suffixlist);
        $path =~ s/\/\z//;

        if ($suffix eq '.csv') {
            # push (@csv_files, $fq_filename);
            # print ("$fq_filename\n");

            if (defined ($found_csv_file)) {
                print ("  There are multiple .csv files in $dir\n");
                exit (1);
            }

            $found_csv_file = $fq_filename;
        }
    }

    close (DIR);

    if (!(defined ($found_csv_file))) {
        if ($pp_report_collection_messages) {
            print ("  No .csv file found in $dir\n");
        }
        next;
    }

    my $record_number = 0;
    my $header_string;
    my @header_list;
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

            if ($pp_report_collection_messages && $pp_report_header_changes) {
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
        # Search for any instance of the zipcode numbers.
        # Could be part of something totally unrelated
        #
        my $i = index ($record, $zip);
        if ($i != -1) {
            #
            # Delete fields wrapped in double quotes
            #
            my $left_double_quote = index ($record, '"');
            if ($left_double_quote != -1) {
                my $right_double_quote = rindex ($record, '"');
                my $left_half = substr ($record, 0, $left_double_quote);
                my $right_half = substr ($record, $right_double_quote + 1);
                $record = $left_half . $right_half;
            }

            my @list = split (',', $record);

            my $this_zip = $list[$zip_column_offset];

            if ($this_zip =~ /(\d{5})/) {
                if ($zip != $1) {
                    next;
                }
            }

            my $cases = $list[$cases_column_offset];

            if ($cases eq '<5') {
                next;
            }

            if (length ($cases) eq 0) {
                print ("  Null cases column at record $record_number\n");
                print ("     Cases column offset = $cases_column_offset\n");
                exit (1);
            }

            my $int_cases = int ($cases);

            if ($int_cases == 0) {
                next;
            }
            
            if ($int_cases == $previous_cases) {
                next;
            }

            my $new_cases = 0;
            if ($previous_cases == 0) {
                #
                # First time
                #
                $new_cases = $int_cases;
                $previous_cases = $int_cases;
            }
            elsif ($previous_cases != $int_cases) {
                $new_cases = $int_cases - $previous_cases;
                $previous_cases = $int_cases;
            }

            if ($new_cases == 0) {
                next;
            }

            if ($pp_report_collection_messages) {
                print ("  New cases = $new_cases, total now $int_cases\n");
            }

            if ($dir =~ /^(\d{4})-(\d{2})-(\d{2})/) {
                my $start_dt = DateTime->new(
                    year       => $1,
                    month      => $2,
                    day        => $3
                );

                for (my $nc = 0; $nc < $new_cases; $nc++) {
                    my %hash;
                    $hash{'serial'} = $case_serial_number++;
                    $hash{'begin_dt'} = $start_dt;

                    #
                    # Return a value between 1 and 100 inclusive
                    #
                    my $random_mortality = int (rand (100)) + 1;
                    if ($random_mortality <= $mortality) {
                        #
                        # It's death. Assume 3 days sick
                        #
                        my $sickness_dur = DateTime::Duration->new (
                            days        => 3);

                        my $end_dt = $start_dt->clone();
                        $end_dt->add_duration ($sickness_dur);

                        $hash{'ending_status'} = 'dead';
                        $hash{'end_dt'} = $end_dt;
                    }
                    else {
                        #
                        # It's cured eventually. Figure out eventually
                        #
                        my $span = $duration_max - $duration_min + 1;
                        my $length_of_sickness_for_this_case = int (rand ($span)) + 1;

                        my $sickness_dur = DateTime::Duration->new (
                            days        => $length_of_sickness_for_this_case);

                        #
                        # Make the end date
                        #
                        my $end_dt = $start_dt->clone();
                        $end_dt->add_duration ($sickness_dur);

                        $hash{'end_dt'} = $end_dt;
                        $hash{'ending_status'} = 'cured';
                    }

                    if ($pp_report_collection_messages && 1) {
                        #
                        # Debug...
                        #
                        my $s = $hash{'begin_dt'};
                        my $e = $hash{'end_dt'};

                        my $debug_string = sprintf ("%04d-%02d-%02d to %04d-%02d-%02d",
                            $s->year(), $s->month(), $s->day(),
                            $e->year(), $e->month(), $e->day());

                        print ("  Adding case \"$debug_string\"\n");
                    }

                    push (@cases_list, \%hash);
                }
            }

        }
    }

    close (FILE);
}




# exit (1);

#
# Debug...
#
my $last_serial;
foreach my $tc (@cases_list) {
    my $top_case_start_dt = $tc->{'begin_dt'};
    my $top_case_stop_dt = $tc->{'end_dt'};
    $last_serial = $tc->{'serial'};

    if (!(defined ($top_case_start_dt))) {
        print ("Start is undefined at " . __LINE__ . "\n");
        exit (1);
    }
}
print ("Last serial = $last_serial\n");


#
# PROCESS CASES
# =============
#
print ("Begin processing cases...\n");

open (FILE, ">", $pp_output_file) or die "Can't open $pp_output_file: $!";

my $running_total_of_dead = 0;
my $running_total_of_cured = 0;
my $currently_sick = 0;

# my @case_keys = sort (keys (%cases));
my $case_count = @cases_list;

#
# Get the earliest and latest dates in the list of cases to
# establish sim run time
#
my $temp_hash_ptr = $cases_list[0];
my $sim_start_dt = $temp_hash_ptr->{'begin_dt'};

$temp_hash_ptr = $cases_list[$case_count - 1];
my $sim_end_dt = $temp_hash_ptr->{'begin_dt'};

my $done = 0;
my $current_sim_dt = $sim_start_dt->clone();
my $top_case_stop_dt;
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

    print ("\n$dir_string...\n");

    my $done_with_this_day = 0;
    my @new_cases_list;

    my $count_for_debug = 0;
    my $string_for_debug;
    while (!$done_with_this_day) {
        $count_for_debug++;

        #
        # Make a default output line
        #
        $output_line = sprintf ("%s,%d,%d,%d",
            $dir_string, $running_total_of_cured, $currently_sick,
            $running_total_of_dead);

        #
        # Get the next case
        #
        my $top_case_ptr = shift (@cases_list);

        my $top_case_start_dt = $top_case_ptr->{'begin_dt'};
        my $top_case_stop_dt = $top_case_ptr->{'end_dt'};
        my $serial = $top_case_ptr->{'serial'};

        if ($serial == $last_serial) {
            $done_with_this_day = 1;
        }

        if (!(defined ($top_case_start_dt))) {
            print ("Start is undefined\n");
            exit (1);
        }
        if (!(defined ($top_case_stop_dt))) {
            print ("Stop is undefined\n");
            exit (1);
        }

        if (1) {
            #
            # Debug
            #
            my $debug_string = sprintf ("%04d-%02d-%02d to %04d-%02d-%02d",
                $top_case_start_dt->year(), $top_case_start_dt->month(), $top_case_start_dt->day(),
                $top_case_stop_dt->year(), $top_case_stop_dt->month(), $top_case_stop_dt->day());
            print ("\n  Case $serial: $debug_string\n");
        }

        #
        # Is it processable?
        #
        my $begin_cmp_result = DateTime->compare ($current_sim_dt, $top_case_start_dt);
        my $end_cmp_result = DateTime->compare ($current_sim_dt, $top_case_stop_dt);
        if (0) {
            print ("    \$begin_cmp_result = $begin_cmp_result\n");
            print ("    \$end_cmp_result = $end_cmp_result\n");
        }
        
        #     print ("  Top case
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

            $currently_sick++;

            $output_line = sprintf ("%s,%d,%d,%d", $dir_string, $running_total_of_cured, $currently_sick,
                $running_total_of_dead);

            $string_for_debug = 'new';
        }
        elsif ($end_cmp_result == -1) {
            #
            # In the middle of this case
            # Put it in the new list. Use the default output line
            #
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
            }
            elsif ($end_status eq 'cured') {
                $running_total_of_cured++;
            }

            $output_line = sprintf ("%s,%d,%d,%d", $dir_string, $running_total_of_cured, $currently_sick,
                $running_total_of_dead);

            $string_for_debug = 'ending';
        }
        else {
            print ("No clue how this happened\n");
            exit (1);
        }

        # print ("    \$count_for_debug = $count_for_debug  $string_for_debug\n");
        print ("    $string_for_debug\n");
    }
    
    my $cnt = @new_cases_list;
    print ("  New cases list has $cnt cases\n");

    push (@new_cases_list, @cases_list);
    @cases_list = @new_cases_list;

    print (FILE "$output_line\n");

    $current_sim_dt->add_duration ($dur);
    if ($current_sim_dt > $sim_end_dt) {
        $done = 1;
    }
}

close (FILE);

#
#
#
exit (1);

###################################################################################
#
#
sub make_new_dirs {
    my $dir = shift;

    my @all_date_dirs;
    my $did_something_flag = 0;

    opendir (DIR, $dir) or die "Get_db_files() can't open $dir: $!";
    while (my $ff = readdir (DIR)) {
        #
        # This is used to rename a bunch of YYYY MM DD directories to YYYY-MM-DD
        #
        if ($ff =~ /^(\d{4}) (\d{2}) (\d{2})/) {
            my $oldff = "$dir/$ff";
            my $newff = "$dir/$1-$2-$3";
            rename ($oldff, $newff) or die "Can't rename $oldff: $!";
        }

        if ($ff =~ /^(\d{4})-(\d{2})-(\d{2})/) {
            push (@all_date_dirs, "$ff");
    
            my $current_dt = DateTime->new(
                year       => $1,
                month      => $2,
                day        => $3
            );

            my $next_dt = $current_dt->add_duration ($dur);
            if ($next_dt > $now) {
                next;
            }

            my $next_dir_string = sprintf ("%04d-%02d-%02d",
                $next_dt->year(),
                $next_dt->month(),
                $next_dt->day());

            if (-e $next_dir_string) {
                next;
            }

            print ("Creating missing date directory $next_dir_string\n");

            mkdir ($next_dir_string) or die "Can't make $next_dir_string: $!";

            $did_something_flag = 1;
        }
    }

    close (DIR);

    return ($did_something_flag);
}

1;  # required
