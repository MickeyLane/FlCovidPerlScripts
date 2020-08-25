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
our $fq_root_dir_for_windows = 'D:/Covid/ByZip';
our $fq_root_dir_for_linux = '/home/mickey/Covid/ByZip';
# our $output_file_name = 'sliced.csv';
# our $output_file_column_header_file_name = 'output_file_column_names.txt';
# our $fq_cld_root_dir_for_windows = 'D:/Covid/CaseLineData';

my $pp_report_header_changes = 0;

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

my $find_dirs_flag = 1;
my $use_hard_coded_flag = 0;
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

if ($find_dirs_flag) {
    #
    # Make missing date directories
    #
    my $not_done = 1;
    while ($not_done) {
        $not_done = make_new_dirs ($dir);
    }

    #
    # Examine $dir and make dirs.txt
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

    print ("Making a new dirs.txt file...\n");
    open (FILE, ">", 'dirs.txt') or die "Can't open dirs.txt: $!";
    foreach my $w (@date_dirs) {
        print (FILE "$w\n");
        # print ("$w\n");
    }
    close (FILE);
}
elsif ($use_hard_coded_flag) {
    push (@date_dirs, "$cwd/2020-07-16");
}
else {
    #
    # Read existing dirs.txt
    #
    open (FILE, "<", 'dirs.txt') or die "Can't open dirs.txt: $!";
    while (my $record = <FILE>) {
        $record =~ s/[\r\n]+//;  # remove <cr><lf>
        push (@date_dirs, "$cwd/$record");
    }
    close (FILE);
}

my $reference_header_string;
my @reference_header_list;
my $cases_column_offset;
my $zip_column_offset;
my @cases_list;
my $previous_cases = 0;

#
# COLLECT DATA
# ============
#
# For each directory specified in dirs.txt, find a .csv file and make a case (or cases) in @cases_list
#
print ("Searching for .csv files...\n");
my @suffixlist = qw (.csv);
foreach my $dir (@date_dirs) {
    print ("$dir...\n");

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
        print ("  No .csv file found in $dir\n");
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
            }

            if ($pp_report_header_changes) {
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

            print ("  New cases = $new_cases, total now $int_cases\n");

            if ($dir =~ /^(\d{4})-(\d{2})-(\d{2})/) {
    
                my $start_dt = DateTime->new(
                    year       => $1,
                    month      => $2,
                    day        => $3
                );

                for (my $nc = 0; $nc < $new_cases; $nc++) {
                    my %hash;

                    $hash{'start dt'} = $start_dt;

                    my $end_dt;

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

                        $end_dt = $start_dt->add_duration ($sickness_dur);

                        $hash{'ending status'} = 'dead';
                        $hash{'end dt'} = $end_dt;
                    }
                    else {
                        my $sickness_dur = DateTime::Duration->new (
                            days        => 19);

                        $end_dt = $start_dt->add_duration ($sickness_dur);

                        $hash{'ending status'} = 'cured';
                    }

                    $hash{'end dt'} = $end_dt;

                    push ($cases_list, \%hash);
                }
            }

        }
    }
}

#
# PROCESS CASES
# =============
#
my $running_total_of_dead = 0;
my $running_total_of_cured = 0;
my $currently_sick;

# my @case_keys = sort (keys (%cases));
my $case_count = @cases_list;

my $sim_start_dt;
my $sim_end_dt;

my $dir = substr ($cases_list[0], 0, 10);
if ($dir =~ /^(\d{4})-(\d{2})-(\d{2})/) {
    $sim_start_dt = DateTime->new(
        year       => $1,
        month      => $2,
        day        => $3
    );
}

$dir = substr ($cases_list[$case_keys_count - 1], 0, 10);
if ($dir =~ /^(\d{4})-(\d{2})-(\d{2})/) {
    $sim_end_dt = DateTime->new(
        year       => $1,
        month      => $2,
        day        => $3
    );
}
my $done = 0;
my $doing_dt = $sim_start_dt;
my $top_case_stop_dt;
while (!$done) {
    my $dir_string = sprintf ("%04d-%02d-%02d", 
    $doing_dt->year(),
    $doing_dt->month(),
    $doing_dt->day());

    my $done_with_this_day = 0;
    my @new_cases_list;

    while (!$done_with_this_day) {
        #
        # Make a default output line
        #
        my $output_line = sprintf ("%s,%d,%d,%d",
            $dir_string, $running_total_of_cured, $currently_sick,
            $running_total_of_dead);

        #
        # Get the next case
        #
        my $top_case_ptr = shift (@cases_list);

        #
        # Is it processable?
        #
        my $top_case_start_dt = $top_case_ptr->{'start dt'};
        my $top_case_stop_dt = $top_case_ptr->{'stop dt'};
        if ($doing_dt < $top_case_start_dt) {
            #
            # No, case can not be processed yet
            # Put it in the new list. Use the default output line. Declare day is done
            #
            push (@new_cases_list, $top_case_ptr);
            $done_with_this_day = 1;
            goto end_of_day;
        }
        elsif ($doing_dt == $top_case_start_dt) {
            #
            # Start case
            # Put it in the new list. Make a new output line
            #
            push (@new_cases_list, $top_case_ptr);

            $top_case_stop_dt = $top_case_ptr->{'stop dt'};
            $currently_sick++;

            $output_line = sprintf ("%s,%d,%d,%d", $dir_string, $running_total_of_cured, $currently_sick,
                $running_total_of_dead);

            goto end_of_day;
        }
        elsif ($doing_dt < $top_case_stop_dt) {
            #
            # In the middle of this case
            # Put it in the new list. Use the default output line
            #
            push (@new_cases_list, $top_case_ptr);
            goto end_of_day;
        }
        elsif ($doing_dt == $top_case_stop_dt) {
            #
            # Ending a case
            # Do NOT put it in the new list
            #
            my $end_status = $top_case_ptr->{'ending status'};
            print (">> $p winds up $end_status\n");
            if ($end_status eq 'dead') {
                $running_total_of_dead++;
            }
            elsif ($end_status eq 'cured') {
                $running_total_of_cured++;
            }

            $output_line = sprintf ("%s,%d,%d,%d", $dir_string, $running_total_of_cured, $currently_sick,
                $running_total_of_dead);

            goto end_of_day;
        }
        else {
            print ("No clue how this happened\n");
            exit (1);
        }

end_of_day:
        print ("$output_line\n");

        if ($done_with_this_day) {
            push (@new_cases_list, @cases_list);
            @cases_list = @new_cases_list;
        }
    }
}

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
