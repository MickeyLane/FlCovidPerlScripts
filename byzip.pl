#!C:/Strawberry/perl/bin/perl.exe
#!/usr/bin/perl
use warnings FATAL => 'all';
use strict;

#
# This software is provided as is, where is, etc with no guarantee that it is
# fit for any purpose whatsoever. Use at your own risk. Mileage may vary.
#
# You are free to do whatever you want with it. It would be nice if you gave credit
# to the author (Mickey Lane, chiliwhiz@gmail.com) if the situation warrants.
#
# This is a simulator. That means that while some of the input data may be real (or
# as real as the dept of health has decided to make it), all of the output is speculation.
# 

use File::Find;           
use File::chdir;
use File::Basename;
use Cwd qw(cwd);
use List::Util qw (shuffle);
use POSIX;
use File::Copy;
use DateTime;
use List::Util qw (max);

use lib '.';
use byzip_a;
use byzip_b;
use byzip_c;
use byzip_plot;

package main;

#
# Any variable that begins with 'fq_' is supposed to contain a fully qualified file name
# Any variable that begins with 'pp_' is a program parameter and is usually a flag to enable
# or disable some feature
#

#
# Edit the following as needed. If you are using Linux, ignore '_windows' and vice versa
#
my $fq_root_dir_for_windows = 'D:/Covid_ByZip';
my $fq_root_dir_for_linux = '/home/mickey/Covid_ByZip';
my $pp_create_missing_directories = 1;
our $pp_report_generation_messages = 0;
my $pp_report_sim_messages = 0;
my $pp_report_adding_case = 0;
my $pp_dont_do_sims = 0;
our $pp_report_header_changes = 0;

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
# print ("Current working directory is $cwd\n");

my  $pp_output_file = "$dir/byzip-output.csv";

my $zip_string;
my $mortality = 3.1;
my $duration_min = 9;
my $duration_max = 19;
my $untested_positive = 0;
# my $non_white;
# my $white;
my $severity = '40:40:20';

my @date_dirs;

my $untested_positive_switch = 'untested_positive=';
my $untested_positive_switch_string_len = length ($untested_positive_switch);
foreach my $switch (@ARGV) {
    my $lc_switch = lc $switch;
    if (index ($lc_switch, 'zip=') != -1) {
        $zip_string = substr ($switch, 4);
    }
    elsif (index ($lc_switch, 'mortality=') != -1) {
        $mortality = substr ($switch, 10);
    }
    elsif (index ($lc_switch, 'duration_min=') != -1) {
        my $val = substr ($switch, 13);
        $duration_min = int ($val);
    }
    elsif (index ($lc_switch, 'duration_max=') != -1) {
        my $val = substr ($switch, 13);
        $duration_max = int ($val);
    }
    elsif (index ($lc_switch, $untested_positive_switch) != -1) {
        my $val = substr ($switch, $untested_positive_switch_string_len);
        $untested_positive = int ($val);
    }
    # elsif (index ($lc_switch, 'non_white=') != -1) {
    #     my $val = substr ($switch, 10);
    #     $non_white = int ($val);
    # }
    else {
        print ("Don't know what to do with $switch\n");
        exit (1);
    }
}

if (!(defined ($zip_string))) {
    print ("No zip code specified\n");
    exit (1);
}

print ("Simulation values:\n");
print ("  Zip = $zip_string\n");
print ("  Mortality = $mortality percent\n");
print ("  Duration_min = $duration_min days\n");
print ("  Duration_max = $duration_max days\n");
print ("  Untested = add $untested_positive untested positive cases for every one detected\n");
# print ("  White = $white percent\n");
# print ("  Non_white = $non_white percent\n");
# print ("  Severity = $severity disease severity groups: no symptoms, moderate and severe\n");
# print ("      (Values are percents, total must be 100)\n");

my @csv_files;
my $mortality_x_10 = int ($mortality * 10);
# my $non_white_x_10 = int ($non_white * 10);

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

my @cases_list;
my %previous_cases_hash;
my $case_serial_number = 1;

#
# Make a list of zips to test. Could be only one
#
my @zip_list;
my $i = index ($zip_string, ',');
if ($i != -1) {
    @zip_list = split (',', $zip_string);
}
else {
    push (@zip_list, $zip_string);
}

#
# COLLECT DATA
# ============
#
print ("Searching .csv files and collecting data...\n");

#
# For each directory specified in dirs.txt, find a .csv file and save records that might be useful
#
my @suffixlist = qw (.csv);
foreach my $dir (@date_dirs) {
    if ($pp_report_generation_messages) {
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
        if ($pp_report_generation_messages) {
            print ("  No .csv file found in $dir\n");
        }
        next;
    }

    #
    # Get records reads the .csv file and returns a list of records that _might_ contain
    # useful information
    #
    my ($cases_column_offset, $zip_column_offset, $ptr) = byzip_a::get_records ($found_csv_file, \@zip_list);
    my @possibly_useful_records = @$ptr;

    #
    # Process possibly useful records, make list of useful records
    #
    $ptr = byzip_b::validate_records (\@possibly_useful_records, $cases_column_offset,$zip_column_offset, \@zip_list);
    my @useful_records = @$ptr;

    #
    #
    #
    if ($pp_report_generation_messages) {
        print ("Process useful records...\n");
    }

    foreach my $record (@useful_records) {
        my @list = split (',', $record);

        #
        # Get the cases value
        #
        my $cases = $list[$cases_column_offset];
        my $zip_from_this_record = $list[$zip_column_offset];

        my $int_cases = int ($cases);
        # if ($negative_value_flag) {
        #     $int_cases = $int_cases * -1;
        # }

        if ($int_cases == 0) {
            next;
        }
        
        #
        # Determine new cases value
        #
        my $new_cases = 0;
        my $previous_cases = 0;
        if (exists ($previous_cases_hash{$zip_from_this_record})) {
            $previous_cases = $previous_cases_hash{$zip_from_this_record};
        }

        if ($previous_cases == 0) {
            #
            # First time a record has been found with 5 or more cases
            # so initialize $previous_cases
            #
            $new_cases = $int_cases;
            $previous_cases = $int_cases;
        }
        elsif ($previous_cases != $int_cases) {
            #
            # If cases from this record is not the same as previous cases, new
            # case records need to be generated
            #
            $new_cases = $int_cases - $previous_cases;
            $previous_cases = $int_cases;
        }

        $previous_cases_hash{$zip_from_this_record} = $previous_cases;

        #
        # Negative number of new cases. Someone at the health dept. twiddled the data.
        # Search previous cases for ones from this zip and delete them until the new
        # cases value is zero
        #
        if ($new_cases < 0) {
            my @cases_to_keep;
            while ($new_cases != 0) {
                my $cases_count = @cases_list;
                if ($cases_count == 0) {
                    print ("While attempting to delete cases due to a negative new case count, ran out of cases\n");
                    exit (1);
                }
                my $hash_ptr = pop (@cases_list);
                my $from_zip = $hash_ptr->{'from_zip'};
                if ($zip_from_this_record != $from_zip) {
                    push (@cases_to_keep, $hash_ptr);
                }
                else {
                    my $serial = $hash_ptr->{'serial'};
                    if ($pp_report_generation_messages) {
                        print ("  Deleting case with serial = $serial\n");
                    }
                    $new_cases++;
                }
            }

            push (@cases_list, @cases_to_keep);

            next;
        }
        
        if ($new_cases == 0) {
            next;
        }

        #
        # Generate new cases
        # ------------------
        #
        if ($pp_report_generation_messages) {
            print ("  New cases for $zip_from_this_record = $new_cases, total now $int_cases\n");
        }

        if ($dir =~ /^(\d{4})-(\d{2})-(\d{2})/) {
            my $begin_dt = DateTime->new(
                year       => $1,
                month      => $2,
                day        => $3
            );

            for (my $nc = 0; $nc < $new_cases; $nc++) {
                my %hash;
                $hash{'serial'} = $case_serial_number++;
                $hash{'begin_dt'} = $begin_dt;
                $hash{'from_zip'} = $zip_from_this_record;
                $hash{'sim_state'} = 'not started';

                # my $random_non_white = int (rand (1000) + 1);
                # if ($random_non_white <= $non_white_x_10) {
                #     $hash{'non_white'} = 1;
                # }
                # else {
                #     $hash{'non_white'} = 0;
                # }

                #
                # Add random values to case
                #
                add_random (\%hash);

                push (@cases_list, \%hash);
            }
        }
    }

}

#
# ADD UNTESTED POSITIVES
# ======================
#
my $count = @cases_list;
my $untested_positive_case_count = 0;
my $temp_hash_ptr = $cases_list[0];
my $first_simulation_dt = $temp_hash_ptr->{'begin_dt'};

if ($untested_positive > 0) {
    print ("Adding untested positive cases...\n");

    for (my $i = 0; $i < $count; $i++) {
        my $existing_case_ptr = shift (@cases_list);

        my $existing_begin_dt = $existing_case_ptr->{'begin_dt'};
        my $zip_from_this_record = $existing_case_ptr->{'from_zip'};

        my $change = DateTime::Duration->new (days => $i + 1);

        my $new_begin_dt = $existing_begin_dt->clone();
        $new_begin_dt->subtract_duration ($change);

        my $diff = DateTime->compare ($new_begin_dt, $first_simulation_dt);
        if ($diff == 1) {
            #
            # Create new cases
            #
            for (my $nc = 0; $nc < $untested_positive; $nc++) {
                my %hash;
                # print ("$case_serial_number\n");
                $hash{'serial'} = $case_serial_number++;
                $hash{'begin_dt'} = $new_begin_dt;
                $hash{'from_zip'} = $zip_from_this_record;
                $hash{'untested_positive'} = 1;
                $hash{'sim_state'} = 'not started';

                add_random (\%hash);
                
                push (@cases_list, \%hash);

                $untested_positive_case_count++;
            }
        }
        
        push (@cases_list, $existing_case_ptr);
    }

    my @new_cases_list = sort case_sort_routine (@cases_list);
    @cases_list = @new_cases_list;
    $count = @cases_list;
}

#
# Debug...
#
my @debug_cases_list;
my $last_serial = -1;
my $index = 0;
foreach my $tc (@cases_list) {
    my $begin_dt = $tc->{'begin_dt'};
    my $stop_dt = $tc->{'end_dt'};
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

    if (!(defined ($begin_dt))) {
        print ("Start is undefined at " . __LINE__ . "\n");
        exit (1);
    }
}

print ("Have $count cases of which $untested_positive_case_count are untested positives\n");
print ("Last serial = $last_serial\n");

#
# PROCESS CASES
# =============
#
if ($pp_dont_do_sims) {
    print ("No sim done!!! \$pp_dont_do_sims flag is set!!!\n");
    exit (1);
}

print ("Begin processing cases...\n");

my @output_csv;
my $output_count;
my $output_header;
for (my $run_number = 0; $run_number < 6; $run_number++) {

    foreach my $hash_ptr (@cases_list) {
        add_random ($hash_ptr);
    }

    my $ptr = byzip_c::process (\@cases_list, $last_serial, \@debug_cases_list);
    my @this_run_output = @$ptr;

    if ($run_number == 0) {
        @output_csv = @this_run_output;
        $output_count = @output_csv;
        $output_header = "Date,Cured,Sick,Dead";
    }
    else {
        my @new_output_csv;
        for (my $j = 0; $j < $output_count; $j++) {
            my $existing = shift (@output_csv);
            my $new = shift (@this_run_output);
            my $t = substr ($new, 10);
            my $s = $existing .= $t;
            push (@new_output_csv, $s);
        }
        @output_csv = @new_output_csv;
        $output_header .= ",Cured,Sick,Dead";
    }
}

open (FILE, ">", $pp_output_file) or die "Can't open $pp_output_file: $!";
print (FILE "$output_header\n");

foreach my $r (@output_csv) {
    print (FILE "$r\n");
}

close (FILE);

byzip_plot::make_plot ($dir, \@output_csv, $zip_string);


#
#
#
# print ("At end of simulation:\n");
# print ("  Dead: $running_total_of_dead\n");
# print ("  Cured: $running_total_of_cured\n");
# print ("  Still sick $currently_sick\n");

exit (1);


###################################################################################
#
#
sub case_sort_routine {

    my $a_dt = $a->{'begin_dt'};
    my $b_dt = $b->{'begin_dt'};
    
    return (DateTime->compare ($a_dt, $b_dt));
}


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


sub add_random {
    my $hash_ptr = shift;

    my $local_begin_dt = $hash_ptr->{'begin_dt'};

    #
    # Get a random value between 1 and 1000 inclusive
    #
    my $random_mortality = int (rand (1000) + 1);
    if ($random_mortality <= $mortality_x_10) {
        #
        # It's death. Assume 3 days sick
        #
        my $sickness_dur = DateTime::Duration->new (
            days        => 3);

        my $end_dt = $local_begin_dt->clone();
        $end_dt->add_duration ($sickness_dur);

        $hash_ptr->{'ending_status'} = 'dead';
        $hash_ptr->{'end_dt'} = $end_dt;
    }
    else {
        #
        # It's cured eventually. Figure out 'eventually'
        #
        my $span = $duration_max - $duration_min + 1;
        my $length_of_sickness_for_this_case = $duration_min + int (rand ($span) + 1);

        my $sickness_dur = DateTime::Duration->new (
            days        => $length_of_sickness_for_this_case);

        #
        # Make the end date
        #
        my $end_dt = $local_begin_dt->clone();
        $end_dt->add_duration ($sickness_dur);

        $hash_ptr->{'end_dt'} = $end_dt;
        $hash_ptr->{'ending_status'} = 'cured';
    }

    if ($pp_report_generation_messages && $pp_report_adding_case) {
        #
        # Debug...
        #
        my $s = $hash_ptr->{'begin_dt'};
        my $e = $hash_ptr->{'end_dt'};

        my $debug_string = sprintf ("%04d-%02d-%02d to %04d-%02d-%02d",
            $s->year(), $s->month(), $s->day(),
            $e->year(), $e->month(), $e->day());

        print ("  Adding case \"$debug_string\"\n");
    }
}

