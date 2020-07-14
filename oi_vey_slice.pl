#!C:/Strawberry/perl/bin/perl.exe
#!/usr/bin/perl
use warnings FATAL => 'all';
use strict;

#
# This software is provided as is, where is, etc with no guarantee that it is
# fit for any purpose whatsoever. Use at your own risk. Mileage may vary.
#

#
# This script is horribly inefficient on purpose. Some (a lot?) of people reviewing it
# may not know perl and being able to say "I can see that this section just does so and
# so" will help
#
use File::Find;           
use File::chdir;
use File::Basename;
use Cwd qw(cwd);
use List::Util qw (shuffle);
use POSIX;
use File::Copy;
use DateTime;

use lib '.';
use translate;
use global_definitions;
use set_up_column_matches;

package main;

our $fq_root_dir_for_windows = 'D:/Covid/OiVey';
our $fq_root_dir_for_linux = '/home/mickey/Covid/OiVey';
our $sliced_output_file = 'sliced.csv';
our $record_debug_limit = 3;

my $cwd = Cwd::cwd();
my $windows_flag = 0;
if ($cwd =~ /^[C-Z]:/) {
    $windows_flag = 1;
}

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

my $f = "$dir/$sliced_output_file";
open (FILE, "<", $f) or die "Can not open $f: $!";
my $output_column_header = <FILE>;
close (FILE);

my $output_column_hash_ptr = make_name_hash ($output_column_header);
my $output_column_count = %$output_column_hash_ptr;

#
# Read dirs.txt
#
my @fq_all_dirs_by_date = '2020-07-05';
# if (open (FILE, "<", 'dirs.txt')) {
#     while (my $record = <FILE>) {
#         $record =~ s/[\r\n]+//;  # remove <cr><lf>
#         push (@fq_all_dirs_by_date, "$cwd/$record");
#     }
# }
# close (FILE);

#
# For each directory, process all the .csv files
#
my @suffixlist = qw (.csv);
foreach my $fq_dir (@fq_all_dirs_by_date) {
    my @csv_files_in_this_dir;
    my $fq_output_file;

    #
    # Start the output file with the combined column names
    #
    my @raw_new_file = $output_column_header;

    #
    # Make a list of all the .csv files in the $fq_dir. As (if) the first one
    # is found, make up the fully qualified name of the output file
    #
    opendir (DIR, $fq_dir) or die "Can't open $fq_dir: $!";
    while (my $rel_filename = readdir (DIR)) {
        my $fq_filename = "$fq_dir/$rel_filename";
        if (-d $fq_filename) {
            next;
        }

        if ($rel_filename eq $sliced_output_file) {
            next;
        }

        my ($name, $path, $suffix) = fileparse ($fq_filename, @suffixlist);
        $path =~ s/\/\z//;

        if ($suffix eq '.csv') {
            push (@csv_files_in_this_dir, $fq_filename);

            if (!(defined ($fq_output_file))) {
                $fq_output_file = "$path/$global_definitions::NF_csv_file_name";
            }
        }
    }

    my $file_number = 1;
    foreach my $fq_filename (@csv_files_in_this_dir) {

        #
        # Report to the user
        #
        if ($file_number == 1) {
            print ("\n");
        }

        my $string = sprintf ("%02d %s", $file_number++, $fq_filename);
        print ("$string\n");

        my $gender = 'F';

        process_file (
            $fq_filename,
            $output_column_hash_ptr,
            $gender,
            $record_debug_limit);
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
    my $fbt_file = shift;
    my $output_column_hash_ptr = shift;
    my $gender = shift;
    my $record_debug_limit = shift;

#     #
#     # Define a simple list of numbers. The 1st number ([0]) represents the 1st column
#     # in the FBT. It contains a number that represents the destination column in the 
#     # in the new output file with the standard names
#     #
#     my @column_matcher;
#     my $column_matcher_len;
#     my @deleted_columns;
#     my $deleted_column_list_len;

#     my $NF_column_count = %$NF_hash_ptr;
#     my @pre_initialized_NF_record;
#     for (my $i = 0; $i < $NF_column_count; $i++) {
#         $pre_initialized_NF_record[$i] = '';
#     }

#     #
#     # Loop through the records in the single specified file
#     #

    my %begin_of_age_group_block;
    my %begin_of_age_block;
    my @age_group_list;
    my @column_to_ignore;

    my $record_number = 0;
    open (FILE, "<", $fbt_file) or die "Can not open $fbt_file: $!";
    while (my $record = <FILE>) {
        #
        # Chomp seems to work differently on Windows and Linux Mint. Use the regex to get
        # rid of any carriage control, new line characters
        #
        $record =~ s/[\r\n]+//;  # remove <cr><lf>

        #
        # If the record ends with a comma, remove it
        #
        $record =~ s/,\z//;

         $record_number++;

         my $header;
         if ($record_number == 1) {
            if ($record =~ /^\xef\xbb\xbf/) {
                $header = substr ($record, 3);
            }
            # elsif ($record =~ /^\xfe\xff\x00\x30\x00\x20\x00\x48\x00\x45\x00\x41\x00\x44/) {
            #     print ("File is Unicode\n");
            #     die;
            # }
            else {
                $header = $record;
            }

#             my ($column_matcher_ptr) = set_up_column_matches::set_up_column_matches (
#                 $header,
#                 $NF_hash_ptr);
#             @column_matcher = @$column_matcher_ptr;
#             $column_matcher_len = @column_matcher;
        }
        elsif ($record_number == 5) {
            print ("Line $record_number\n");
            my @columns = split (',', $record);
            my $column_count = 0;
            my $value_count = 0;
            my @columns_with_values;
            foreach my $v (@columns) {
                if (length ($v) > 0) {
                    push (@columns_with_values, "\"$v\" at $column_count");

                    my $age_group_string = "$v";
                    $begin_of_age_group_block{$column_count} = $age_group_string;

                    push (@age_group_list, $column_count);

                    $value_count++;
                }
                
                $column_count++;
            }
            print ("  Record 6 has $column_count columns. $value_count have values\n");
            print ("  \%age_group_list:\n");
            foreach my $cv (@age_group_list) {
                print ("    $cv\n");
            }
            print ("  \%begin_of_age_group_block:\n");
            while (my ($key, $val) = each %begin_of_age_group_block) {
                print ("    $key is begin of $val\n");
            }

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
                    print ("  Column $sc to $ec is age group $begin_of_age_group_block{$start_column}\n");
                }

                if ($i >= $start_column && $i < $end_column) {
                    my $cell_value = $columns[$i];
                    if (length ($cell_value) == 0) {
                        $debug_string .= ".";
                    }
                    else {
                        $begin_of_age_block{$i} = $cell_value;

                        $debug_string .= " $cell_value";
                    }
                }

                if ($i == $end_column) {

                    # push (@column_to_ignore, $i);

                    print ("    $debug_string\n");

                    $debug_string = '';

                    $start_column = shift (@temp);
                    my $values_left = @temp;
                    if ($values_left == 0) {
                        last;
                    }
                    $end_column = $temp[0] - 1;
                }


            }

            # print ("  \%begin_of_age_block:\n");
            # my @list_1;
            # while (my ($key, $val) = each %begin_of_age_block) {
            #     push (@list_1, "$key is begin of $val");
            # }
            # my @list_2 = sort (@list_1);
            # foreach my $y (@list_2) {
            #     print ("    $y\n");
            # }
        }
        elsif ($record_number == 7) {
            print ("Line $record_number\n");
            print ("  Header: \"$output_column_header\"\n");
        }
        elsif ($record_number > 7) {
            print ("Line $record_number\n");
            
            my @temp = @age_group_list;

            #
            # Figure out the start end columns for the 1st age group
            #
            my $start_column = shift (@temp);
            my $end_column = $temp[0] - 1;

            my @list_for_output;
            my $age;
            #
            #
            #
            my @columns = split (',', $record);
            my $column_count = @columns;

            for (my $i = 0; $i < $column_count; $i++) {
                # my $ignore_flag = 0;
                # foreach my $c2i (@column_to_ignore) {
                #     if ($i == $c2i) {
                #         $ignore_flag = 1;
                #     }
                # }

                # if ($ignore_flag) {
                #     if ($i == $start_column || $i == $end_column) {
                #         die;
                #     }
                #     next;
                # }

                if ($i == $start_column) {
                    my $ptr = init_output_line_list (
                        $output_column_count,
                        $gender,
                        $output_column_hash_ptr,
                        \%begin_of_age_group_block,
                        $start_column);
                    @list_for_output = @$ptr;
                }

                if ($i >= $start_column && $i < $end_column) {
                    if (exists ($begin_of_age_block{$i})) {
                        $age = $begin_of_age_block{$i};
                        my $age_column_number = $output_column_hash_ptr->{'Age'};
                        $list_for_output[$age_column_number] = $age;
                    }
                }

                if ($i == $end_column) {
                    my $record_for_output = join (',', @list_for_output);
                    print ("  Output: \"$record_for_output\"\n");

                    $start_column = shift (@temp);
                    my $values_left = @temp;
                    if ($values_left == 0) {
                        last;
                    }
                    $end_column = $temp[0] - 1;

                    my $ptr = init_output_line_list (
                        $output_column_count,
                        $gender,
                        $output_column_hash_ptr,
                        \%begin_of_age_group_block,
                        $start_column);
                    @list_for_output = @$ptr;
                }
            }


            last;
        }
    }

    close (FILE);
}

sub init_output_line_list {
    my $output_col_cnt = shift;
    my $gender = shift;
    my $output_column_hash_ptr = shift;
    my $begin_of_age_group_block_ptr = shift;
    my $row_start_column = shift;

    my @list;
    for (my $i = 0; $i < $output_col_cnt; $i++) {
        push (@list, ' ');
    }

    my $age_group = $begin_of_age_group_block_ptr->{$row_start_column};
    my $age_group_column_number = $output_column_hash_ptr->{'Age_group'};

    my $gender_column_number = $output_column_hash_ptr->{'Gender'};

    $list[$age_group_column_number] = $age_group;
    $list[$gender_column_number] = $gender;

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

    my $letters;

    if ($n >= 1 && $n <= 26) {
        my $ascii_val = ord ('A') + $n;
        $letters = chr ($ascii_val);
    }
    elsif ($n >= 27 && $n <= 52) {
        my $ascii_val = ord ('A') + ($n - 26);
        $letters = 'A' . chr ($ascii_val);
    }
    else {
        $letters = 'X';
    }

    return ($letters);
}

1;  # required

