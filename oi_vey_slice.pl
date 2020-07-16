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
use Spreadsheet::Read qw(ReadData);

use lib '.';
use translate;
use global_definitions;
use set_up_column_matches;

package main;

#
# Any variable that begins with 'fq_' is supposed to contain a fully qualified file name
#

#
# Edit the following as needed. If you are using Linux, ignore '_windows' and vice versa
#
our $fq_root_dir_for_windows = 'D:/Covid/OiVey';
our $fq_root_dir_for_linux = '/home/mickey/Covid/OiVey';
our $output_file_name = 'sliced.csv';
our $output_file_column_header_file_name = 'output_file_column_names.txt';
our $fq_cld_root_dir_for_windows = 'D:/Covid/CaseLineData';

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

#
# Read the output .csv header row
#
my $f = "$dir/$output_file_column_header_file_name";
open (FILE, "<", $f) or die "Can not open $f: $!";
my $output_column_header = <FILE>;
close (FILE);
$output_column_header =~ s/[\r\n]+//;  # remove <cr><lf> if any

#
#
#
my $output_column_hash_ptr = make_name_hash ($output_column_header);
my $output_column_count = %$output_column_hash_ptr;

my $find_dirs_flag = 1;
# my ($switch_1, $switch_2) = @ARGV;
# if (defined ($switch_1)) {
#     $find_dirs_flag = 1;
# }

my @fq_all_dirs_by_date;
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
                push (@fq_all_dirs_by_date, "$date");
            }
        }
    }

    print ("Making a new dirs.txt file\n");
    open (FILE, ">", 'dirs.txt') or die "Can't open dirs.txt: $!";
    foreach my $w (@fq_all_dirs_by_date) {
        print (FILE "$w\n");
        # print ("$w\n");
    }
    close (FILE);
}
else {
    #
    # Read existing dirs.txt
    #
    open (FILE, "<", 'dirs.txt') or die "Can't open dirs.txt: $!";
    while (my $record = <FILE>) {
        $record =~ s/[\r\n]+//;  # remove <cr><lf>
        push (@fq_all_dirs_by_date, "$cwd/$record");
    }
    close (FILE);
}

#
# For each directory specified in dirs.txt, process all the .xlsx files
#
my @suffixlist = qw (.xlsx);
foreach my $fq_dir (@fq_all_dirs_by_date) {
    my @xlsx_files_in_this_dir;

    #
    # Make a list of all the .xlsx files in one date directory
    #
    opendir (DIR, $fq_dir) or die "Can't open $fq_dir: $!";
    while (my $rel_filename = readdir (DIR)) {
        if ($rel_filename eq $output_file_name) {
            next;
        }

        my $fq_filename = "$fq_dir/$rel_filename";
        if (-d $fq_filename) {
            next;
        }

        my ($name, $path, $suffix) = fileparse ($fq_filename, @suffixlist);
        $path =~ s/\/\z//;


        if ($suffix eq '.xlsx') {
            #
            # If the .xlsx file begins with a '~' it means the file is open in Excel
            #
            if ($rel_filename =~ /^[~]/) {
                next;
            }

            push (@xlsx_files_in_this_dir, $fq_filename);
        }
    }

    #
    # Set up the name of the file that's going to be created
    # This is once per directory. Start the output file with the combined column names
    #
    my $fq_output_file = "$fq_dir/$output_file_name";
    my $ofh;
    open ($ofh, ">", $fq_output_file) or die "Can't create fq_output_file: $!";
    print ($ofh "$output_column_header\n");

    #
    # Process each file found
    #
    my $file_number = 1;
    foreach my $fq_filename (@xlsx_files_in_this_dir) {
        #
        # Report to the user
        #
        if ($file_number == 1) {
            print ("\n");
        }

        #
        # Report to the user
        #
        my $string = sprintf ("%02d %s", $file_number++, $fq_filename);
        print ("\n$string\n");

        my $gender = '?';
        my $race = '?';
        my $i = index ($fq_filename, '_female');
        if ($i != -1) {
            $gender = 'F';
        }
        else {
            $i = index ($fq_filename, '_male');
            if ($i != -1) {
                $gender = 'M';
            }
        }

        $i = index ($fq_filename, 'black_');
        if ($i != -1) {
            $race = 'B';
        }
        else {
            $i = index ($fq_filename, 'white_');
            if ($i != -1) {
                $race = 'W';
            }
            else {
                $i = index ($fq_filename, 'hispanic_');
                if ($i != -1) {
                    $race = 'H';
                }
            }
        }

        if ($race eq '?' || $gender eq '?') {
            print ("Improperly named file is $fq_filename\n");
            exit (1);
        }

        process_file (
            $fq_filename,
            $ofh,
            $output_column_hash_ptr,
            $gender,
            $race);
    }
}

#
#
#
exit (1);

###################################################################################
#
#
sub process_file {
    my $fq_filename = shift;
    my $ofh = shift;
    my $output_column_hash_ptr = shift;
    my $gender = shift;
    my $race = shift;

    my %column_to_age_group_map;
    my %column_to_age_map;
    my @age_group_list;
    my @age_list;
    my @column_to_ignore;
    my @csv_style_rows;

    #
    # Get the Excel file into the Excel perl package
    # Make a csv style array of rows
    #
    my $book = ReadData ($fq_filename);
    my @rows = Spreadsheet::Read::rows($book->[1]);
    foreach my $i (1 .. scalar @rows) {
        my $csv_style_record = '';

        foreach my $j (1 .. scalar @{$rows[$i-1]}) {
            my $cell = ($rows[$i-1][$j-1] // '');
            $csv_style_record .= "$cell,";
        }
        $csv_style_record =~ s/,\z//;
        push (@csv_style_rows, $csv_style_record);
    }

    #
    # Process each row
    #
    my $record_number = 0;
    foreach my $record (@csv_style_rows) {
        $record_number++;

        if ($record_number < 5) {
            next;
        }

        if ($record_number == 5) {
            print ("Line $record_number\n");
            my @columns = split (',', $record);
            my $column_count = 0;
            my $value_count = 0;
            my @columns_with_values;
            foreach my $v (@columns) {
                if (length ($v) > 0) {
                    push (@columns_with_values, "\"$v\" at $column_count");

                    my $age_group_string = "$v";
                    $column_to_age_group_map{$column_count} = $age_group_string;

                    push (@age_group_list, $column_count);

                    $value_count++;
                }
                
                $column_count++;
            }
            print ("  Record 6 has $column_count columns. $value_count have values\n");
        }
        elsif ($record_number == 6) {
            print ("Line $record_number\n");

            my @temp = @age_group_list;

            #
            # Figure out the start stop columns for each age group
            #
            my $start_column = shift (@temp);
            my $end_column = $temp[0] - 1;

            #
            #
            #
            my @columns = split (',', $record);
            my $column_count = @columns;

            my $debug_string = '';

            for (my $i = 0; $i < $column_count; $i++) {
                if ($i == $start_column) {
                    my $sc = convert_column_number_to_excel_letters ($start_column);
                    my $ec = convert_column_number_to_excel_letters ($end_column);
                    print ("  Column $sc to $ec is age group $column_to_age_group_map{$start_column}\n");
                }

                if ($i >= $start_column && $i < $end_column) {
                    my $cell_value = $columns[$i];
                    if (length ($cell_value) == 0) {
                        $debug_string .= ".";
                    }
                    else {
                        if (exists ($column_to_age_map{$i})) {
                            my $hash_ptr = $column_to_age_map{$i};
                            $hash_ptr->{'Age'} = $cell_value;
                        }
                        else {
                            my %hash;
                            $hash{'Age'} = $cell_value;
                            $column_to_age_map{$i} = \%hash;
                        }
                        push (@age_list, $i);

                        $debug_string .= " $cell_value";
                    }
                }

                if ($i == $end_column) {

                    # push (@column_to_ignore, $i);

                    # print ("    $debug_string\n");

                    $debug_string = '';

                    $start_column = shift (@temp);
                    my $values_left = @temp;
                    if ($values_left == 0) {
                        last;
                    }
                    $end_column = $temp[0] - 1;
                }
            }
        }
        elsif ($record_number == 7) {
            print ("Line $record_number\n");

            my @columns = split (',', $record);
            my $column_count = @columns;

            for (my $i = 0; $i < $column_count; $i++) {
                if (exists ($column_to_age_map{$i})) {
                    my $hash_ptr = $column_to_age_map{$i};
                    if (!defined ($hash_ptr)) {
                        print ("\%column_to_age_map hash ptr is missing!\n");
                        die;
                    }

                    my $row_7_counties_map_ptr;
                    if (exists ($hash_ptr->{'Counties'})) {
                        $row_7_counties_map_ptr = $hash_ptr->{'Counties'};
                    }
                    else {
                        my %new_hash;
                        $row_7_counties_map_ptr = \%new_hash;
                    }

                    my $j = $i;
                    my $done = 0;
                    while (!$done) {
                        my $county = $columns[$j];

                        if ($county eq 'Total') {
                            $done = 1;
                        }
                        else {
                            $row_7_counties_map_ptr->{$j} = $county;
                            $j++;
                        }
                    }

                    $hash_ptr->{'Counties'} = $row_7_counties_map_ptr;

                    # print ("\$county = $county\n");
                }
            }
        }
        elsif ($record_number > 7) {
            print ("Line $record_number");
            
            my $output_rows_created_for_this_input_row = 0;

            my $age;
            my $age_group;
            my $column_0_county;
            my $row_7_counties_map_ptr;

            #
            #
            #
            my @columns = split (',', $record);
            my $column_count = @columns;

            #
            # Loop through the columns laft to right
            #
            for (my $i = 0; $i < $column_count; $i++) {
                if ($i == 0) {
                    #
                    # Column 0 county aka place of death
                    #
                    if ($columns[0] eq 'Total') {
                        last;
                    }
                    
                    if ($columns[0] eq 'Unknown') {
                        last;
                    }
                    
                    $column_0_county = $columns[0];
                    next;
                }

                if (exists ($column_to_age_group_map{$i})) {
                    #
                    # Current column is the begin of an age group
                    # Nothing is done with this except put it in the output row
                    #
                    $age_group = $column_to_age_group_map{$i};
                }

                if (exists ($column_to_age_map{$i})) {
                    #
                    # Column is the begin of a single age
                    # Get a pointer to a hash that contains Age and another hash pointer. The 2nd
                    #   hash pointer maps from column numbers to row counties aka residence counties
                    #
                    my $hash_ptr = $column_to_age_map{$i};
                    if (!defined ($hash_ptr)) {
                        print ("\%column_to_age_map hash ptr is missing!\n");
                        die;
                    }

                    $age = $hash_ptr->{'Age'};

                    $row_7_counties_map_ptr = $hash_ptr->{'Counties'};
                }

                #
                # Is this dumb or what?
                #
                my $good_to_go = 0;
                my $missing;
                if (defined ($column_0_county)) {
                    if (defined ($row_7_counties_map_ptr)) {
                        if (defined ($age_group)) {
                            if (defined ($race)) {
                                if (defined ($gender)) {
                                    if (defined ($age)) {
                                        $good_to_go = 1;
                                    }
                                    else {
                                        $missing = '$age';
                                    }
                                }
                                else {
                                    $missing = '$gender';
                                }
                            }
                            else {
                                $missing = '$race';
                            }
                        }
                        else {
                            $missing = '$age_group';
                        }
                    }
                    else {
                        $missing = '$row_7_counties_map_ptr';
                    }
                }
                else {
                    $missing = '$column_0_county';
                }

                if (!$good_to_go) {
                    print ("At column $i, missing $missing\n");
                    die;
                }

                if ($columns[$i] ne 0) {
                    if (exists ($row_7_counties_map_ptr->{$i})) {
                        my $row_7_county = $row_7_counties_map_ptr->{$i};
                        my $deaths = $columns[$i];

                        try_to_find_cld_matches (
                            $fq_filename,
                            $column_0_county,  # aka place_of_death county
                            $row_7_county,     # aka residence county
                        );

                        for (my $j = 0; $j < $deaths; $j++) {
                            my $ptr = make_output_line_list (
                                $output_column_hash_ptr,
                                $output_column_count,
                                $gender,
                                $race,
                                $age,
                                $column_0_county,  # aka place_of_death county
                                $row_7_county,     # aka residence county
                                $age_group);

                            my $record_for_output = join (',', @$ptr);

                            print ($ofh "$record_for_output\n");
                            $output_rows_created_for_this_input_row++;
                        }
                    }
                }
            }

            if ($output_rows_created_for_this_input_row) {
                print (" created $output_rows_created_for_this_input_row rows\n");
            }
            else {
                print ("\n");
            }
        }
    }
}

sub make_output_line_list {
    my $output_column_hash_ptr = shift;
    my $output_col_cnt = shift;
    my $gender = shift;
    my $race = shift;
    my $age = shift;
    my $column_0_county = shift;
    my $row_7_county = shift;
    my $age_group = shift;

    my @list;
    for (my $i = 0; $i < $output_col_cnt; $i++) {
        push (@list, ' ');
    }

    my $age_group_column_number = $output_column_hash_ptr->{'Age_group'};

    my $gender_column_number = $output_column_hash_ptr->{'Gender'};

    my $race_column_number = $output_column_hash_ptr->{'Race'};

    my $row_county_column_number = $output_column_hash_ptr->{'RowCounty'};

    my $column_0_county_column_number = $output_column_hash_ptr->{'ColumnCounty'};

    my $age_column_number = $output_column_hash_ptr->{'Age'};

    $list[$age_group_column_number] = $age_group;
    $list[$gender_column_number] = $gender;
    $list[$race_column_number] = $race;
    $list[$row_county_column_number] = $row_7_county;
    $list[$column_0_county_column_number] = $column_0_county;
    $list[$age_column_number] = $age;

    return (\@list);
}

sub make_name_hash {
    my $names_string = shift;

    my @names_list = split (',', $names_string);
    my $names_list_len = @names_list;
    my %names_hash;
    for (my $i = 0; $i < $names_list_len; $i++) {
        my $key = $names_list[$i];
        $names_hash{$key} = $i;
    }

    return (\%names_hash);
}

sub convert_column_number_to_excel_letters {
    my $n = shift;

    my $left_letter_int = int ($n / 26);
    my $right_letter_int = $n - ($left_letter_int * 26);

    if ($left_letter_int == 0) {
        my $ascii_val = ord ('A') + $right_letter_int;
        return (chr ($ascii_val));
    }

    my $left_letter;
    my $right_letter;
    if ($left_letter_int <= 26) {
        my $ascii_val = ord ('A') + ($left_letter_int);
        $left_letter = chr ($ascii_val);
        $ascii_val = ord ('A') + $right_letter_int;
        $right_letter = chr ($ascii_val);
    }
    else {
        my $ascii_val = ord ('a') + ($left_letter_int);
        $left_letter = chr ($ascii_val);
        $ascii_val = ord ('a') + $right_letter_int;
        $right_letter = chr ($ascii_val);
    }

    return ($left_letter . $right_letter);
}

sub try_to_find_cld_matches {
    my $fq_filename = shift;
    my $column_0_county = shift;  # aka place_of_death county
    my $row_7_county = shift;     # aka residence county
    
}

sub make_new_dirs {
    my $dir = shift;

    my @all_date_dirs;
    my $did_something_flag = 0;

    opendir (DIR, $dir) or die "Get_db_files() can't open $dir: $!";
    while (my $ff = readdir (DIR)) {
        #
        # This was used to rename a bunch of YYYY MM DD directories to YYYY-MM-DD
        #
        # if ($ff =~ /^(\d{4}) (\d{2}) (\d{2})/) {
        #     my $oldff = "$dir/$ff";
        #     my $newff = "$dir/$1-$2-$3";
        #     rename ($oldff, $newff) or die "Can't rename $oldff: $!";
        # }
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
