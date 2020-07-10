#!/usr/bin/perl
use warnings FATAL => 'all';
use strict;

#
# This software is provided as is, where is, etc with no guarantee that it is
# fit for any purpose whatsoever. Use at your own risk. Mileage may vary.
#

#
# This script is inefficient on purpose. Some (a lot?) of people reviewing it
# may not know perl and keeping it simple is good
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

package main;

#
# Are we Windows or Linux?
#
my $cwd = Cwd::cwd();
my $windows_flag = 0;
if ($cwd =~ /^[C-Z]:/) {
    $windows_flag = 1;
}

my $dir;
if ($windows_flag) {
    $dir = lc $global_definitions::fq_root_dir_for_windows;
}
else {
    $dir = $global_definitions::fq_root_dir_for_linux;
}
$CWD = $dir;
$cwd = Cwd::cwd();
print ("Current working directory is $cwd\n");

#
# Read the old unified header file if it exists
# This is for reporting purposes only
#
my $old_unified_name_string;
my $f = "$dir/$global_definitions::column_name_output_file";
if (-e $f) {
    open (FILE, "<", $f) or die "Can not open $f: $!";
    $old_unified_name_string = <FILE>;
    close (FILE);
}

#
# Part 1
# ------
#
# Read dirs.txt
#
my @fq_all_dirs_by_date;
open (FILE, "<", 'dirs.txt') or die "Can't open dirs.txt: $!";
while (my $record = <FILE>) {
    #
    # Chomp seems to work differently on Windows and Linux Mint. Use the regex to get
    # rid of any carriage control, new line characters
    #
    $record =~ s/[\r\n]+//;  # remove <cr><lf>

    push (@fq_all_dirs_by_date, "$cwd/$record");
}
close (FILE);

#
# Part 2
# ------
#
# Go through all the dirs.txt directories and pick out the ones that contain at least
# one .csv file. Make a list of those directories
#
my $have = 0;
my $missing = 0;
my @fq_dirs_with_data;
foreach my $fq_dir (@fq_all_dirs_by_date) {

    my $ptr = get_csvs ($fq_dir);

    if (defined ($ptr)) {
        push (@fq_dirs_with_data, $fq_dir);
        $have++;
    }
    else {
        print ("\n$fq_dir does not contain a .csv file\n");
        $missing++;
    }
}

#
# Report to the user
#
if ($have == 0) {
    print ("No .csv files found\n");
    exit (1);
}

my $total = $have + $missing;
my $percent = int (($have / $total) * 100);
print ("Have at least one .csv file in $have out of $total directories ($percent percent)\n");

#
# Part 3
# ------
#
# Go through all of the directories that have .csv files and inventory the column
# headers. They changed quite a bit as time passed. Make a 'master header' that
# accomodates all .csv files
#
my %master_column_name_hash;
foreach my $fq_dir (@fq_dirs_with_data) {
    #
    # Part 3.A
    #
    # Get a list of files in a date directory that end with .csv
    #
    my $ptr = get_csvs ($fq_dir);
    my @list_of_csv_files = @$ptr;

    my %column_name_hash_for_all_files_in_a_given_directory;

    #
    # Part 3.B
    #
    # Determine the headers for all the files for this date
    #
    my $file_number = 0;
    foreach my $csv_file (@list_of_csv_files) {
        $file_number++;
        check_file_column_headers ($csv_file,
            $file_number,
            \%column_name_hash_for_all_files_in_a_given_directory);
    }

    #
    # Part 3.C
    #
    # Go through the column headers for a given directory (the sum of all the files in
    # that directory) and anything new to the master coulumn header inventory
    #
    while (my ($key, $not_used) = each %column_name_hash_for_all_files_in_a_given_directory) {
        if (exists ($master_column_name_hash{$key})) {
            my $val = $master_column_name_hash{$key};
            $val++;
            $master_column_name_hash{$key} = $val;
        }
        else {
            $master_column_name_hash{$key} = 1;
        }
    }
}

my $unified_column_name_count = %master_column_name_hash;
if ($unified_column_name_count == 0) {
    print ("Did not make any column names for the unified files\n");
    exit (1);
}

#
# Make a list of the keys in the master column hash
#
my @mc_list_1 = keys %master_column_name_hash;
#
# Optional: Sort the list
#
my $mc_string;
my @mc_list;
if (1) {
    my @mc_list_2;
    foreach my $mc_1 (@mc_list_1) {
        push (@mc_list_2, $mc_1);
    }
    @mc_list = sort (@mc_list_2);
    $mc_string = join (',', @mc_list);
}
else {
    @mc_list = @mc_list_1;
    $mc_string = join (',', @mc_list);
}

#
# Report to the user
#
print ("\nUnified column names:\n");
my $count = 0;
foreach my $key (@mc_list) {
    my $string = sprintf ("%02d %s", $count++, $key);
    print ("  $string\n");
}

#
# See if the new one matches the old one. If so, report
#
if (defined ($old_unified_name_string)) {
    if ($mc_string eq $old_unified_name_string) {
        print ("The new string is the same as the old one\n");
    }
}

my $output_file_name = "$cwd/$global_definitions::column_name_output_file";

open (FILE, ">", $output_file_name) or die "Can not open $output_file_name: $!";
print (FILE "$mc_string");
close (FILE);

#
# End of Script
#
exit (1);   # unnecessary


###################################################################################
#
# Given a fully qualified subdirectory, return a list of all the .csv files it contains, if any
#
sub get_csvs {
    my $subdir = shift;

    my @found_file;
    my @suffixlist = qw (.csv);

    opendir (DIR, $subdir) or die "Get_db_files() can't open $subdir: $!";
    while (my $relative = readdir (DIR)) {
        if ($relative eq $global_definitions::NF_csv_file_name || $relative eq $global_definitions::NF_normalized_csv_file_name) {
            next;
        }

        my $fully_qualified = "$subdir/$relative";

        if (-d $fully_qualified) {
            next;
        }

        my ($name, $path, $suffix) = fileparse ($fully_qualified, @suffixlist);
        $path =~ s/\/\z//;

        if ($suffix eq '.csv') {
            push (@found_file, $fully_qualified);
        }
    }

    if (@found_file) {
        return (\@found_file);
    }
    else {
        return (undef);
    }
}

###################################################################################
#
sub check_file_column_headers {
    my $csv_file = shift;
    my $file_number = shift;
    my $column_name_hash_ptr = shift;

    my $fh;
    my $date = "YYYY MM DD";
    if ($csv_file =~ /\/(\d{4})-(\d{2})-(\d{2})\//) {
        $date = "$1-$2-$3";
    }
    my $file_number_string = sprintf ("%02d", $file_number);

    #
    # Loop through the records in a single file
    #
    my $record_number = 0;
    if (open ($fh, "<", $csv_file)) {
        while (my $record = <$fh>) {
            #
            # Chomp seems to work differently on Windows and Linux Mint. Use the regex to get
            # rid of any carriage control, new line characters
            #
            $record =~ s/[\r\n]+//;  # remove <cr><lf>

            $record_number++;

            my $header;
            if ($record_number == 1) {
                #
                # Remove BOM if any
                #
                if ($record =~ /^\xef\xbb\xbf/) {
                    $header = substr ($record, 3);
                }
                elsif ($record =~ /^\xfe\xff\x00\x30\x00\x20\x00\x48\x00\x45\x00\x41\x00\x44/) {
                    print ("File is Unicode\n");
                    die;
                }
                else {
                    $header = $record;
                }

                my @column_name_list = split (/,/, $header);

                my ($new_string, $new_column_name_list_ptr, $deleted_columns_ptr) = 
                    translate::translate_names (\@column_name_list);

                $header = $new_string;
                @column_name_list = @$new_column_name_list_ptr;
                # @deleted_columns = @$deleted_columns_ptr;

                if ($file_number == 1) {
                    print ("\n$date\n");
                    print ("  $file_number_string: $header\n");
                    #
                    # For the 1st (possibly only) .csv file in any given date directory,
                    # create a hash with the keys set to the column names and the values
                    # set to one
                    #
                    %$column_name_hash_ptr = map { $_ => 1 } @column_name_list;
                }
                else {
                    #
                    # For file 2+, 
                    #
                    print ("  $file_number_string: $header\n");
                    foreach my $cn (@column_name_list) {
                        if (exists ($column_name_hash_ptr->{$cn})) {
                            my $val = $column_name_hash_ptr->{$cn};
                            $val++;
                            $column_name_hash_ptr->{$cn} = $val;
                        }
                        else {
                            $column_name_hash_ptr->{$cn} = 1;
                            print ("File $file_number_string, a column named $cn was added\n");
                        }
                    }
                }
            }
            else {
                last;
            }
        }
    }

    close ($fh);

    return (0);
}
