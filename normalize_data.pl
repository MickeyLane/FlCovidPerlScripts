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
use Cwd;
use List::Util qw (shuffle);
use POSIX;
use File::Copy;
use DateTime;

use lib '.';
use global_definitions;

package main;

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



my $f = "$dir/$global_definitions::column_name_output_file";
open (FILE, "<", $f) or die "Can not open $f: $!";
my $unified_name_string = <FILE>;
close (FILE);

my @nf_column_list = split (',', $unified_name_string);
my $nf_column_list_len = @nf_column_list;
my $dictionary_ptr = set_up_normalize_dictionary (\@nf_column_list);

#
# Get list of directories from the file dirs.txt
#
my @fq_all_dirs_by_date;
if (open (FILE, "<", 'dirs.txt')) {
    while (my $record = <FILE>) {
        $record =~ s/[\r\n]+//;  # remove <cr><lf>
        push (@fq_all_dirs_by_date, "$cwd/$record");
    }
}
close (FILE);

#
# Make a list of all the "$global_definitions::$NF_csv_file_name" files in all of the $fq_dir
#
my @new_files;
my @suffixlist = qw (.csv);
foreach my $fq_dir (@fq_all_dirs_by_date) {
    opendir (DIR, $fq_dir) or die "Can't open $fq_dir: $!";
    while (my $rel_filename = readdir (DIR)) {
        if ($rel_filename eq $global_definitions::NF_csv_file_name) {
            my $fq_filename = "$fq_dir/$rel_filename";
            push (@new_files, $fq_filename);
            last;
        }
    }
}

foreach my $in_fn (@new_files) {
    print ("$in_fn\n");

    my $out_fn = $in_fn;
    my $last_slash = rindex ($out_fn, '/');
    my $new = $global_definitions::NF_normalized_csv_file_name;
    my $new_len = length ($new);
    substr ($out_fn, $last_slash, $new_len, "/$new");

    my $input_file_handle;
    my $output_file_handle;
    my %change_log_for_this_file;

    open ($input_file_handle, "<", $in_fn) or die "Can not open $in_fn: $!";

    my $record_number = 0;
    open ($output_file_handle, ">", $out_fn) or die "Can not open $out_fn: $!";


    my $FBT_header;
    while (my $record = <$input_file_handle>) {
        #
        # Chomp seems to work differently on Windows and Linux Mint. Use the regex to get
        # rid of any carriage control, new line characters
        #
        $record =~ s/[\r\n]+//;  # remove <cr><lf>


        $record_number++;
        if ($record_number == 1) {
            #
            # 1st record has column heading names
            #
            # Remove BOM if any
            #
            if ($record =~ /^\xef\xbb\xbf/) {
                $FBT_header = substr ($record, 3);
            }
            # elsif ($record =~ /^\xfe\xff\x00\x30\x00\x20\x00\x48\x00\x45\x00\x41\x00\x44/) {
            #     print ("File is Unicode\n");
            #     die;
            # }
            else {
                $FBT_header = $record;
            }

            print ($output_file_handle $FBT_header);
        }
        else {
            #
            # 2nd+ record has information
            #
            # Split the FBT column data into a list of values
            #
            my @FBT_column_values = split (',', $record);
            my $len = @FBT_column_values;

            #
            # Go through all the columns. If a column has a value, see if it
            # needs to be normalized
            #
            for (my $column = 0; $column < $len; $column++) {
                if (length ($FBT_column_values[$column]) > 0) {
                    #
                    # There's something in this column...
                    #
                    my $old_val = $FBT_column_values[$column];
                    
                    my $new_val;
                    my $col_name = $nf_column_list[$column];

                    if (exists ($dictionary_ptr->{$col_name})) {
                        $new_val = $dictionary_ptr->{$col_name}->($old_val, \%change_log_for_this_file);
                    }
                    else {
                        $new_val = $old_val;
                    }

                    $FBT_column_values[$column] = $new_val;
                }
            }

            #
            # Reassemble the record and write it out to the new file
            #
            my $new_csv_record = join (',', @FBT_column_values);

            print ($output_file_handle "$new_csv_record\n");
        }
    }

    close ($input_file_handle);
    close ($output_file_handle);

    my $change_count = %change_log_for_this_file;
    if ($change_count) {
        while (my ($key, $val) = each %change_log_for_this_file) {
            # my $string = sprintf ("%02d %s", $count++, $key);
            print ("  $key\n");
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

###################################################################################
#
# The dictionary is actually a hash of functions with the keys being the column names
#
# Input to the function is the value from a cell of the file being tested
# Output is either a new value or the same value
#
# Example:
#   For Gender, convert 'Male' to 'M' and 'Female' to 'F'
#
sub set_up_normalize_dictionary {
    my $column_list_ptr = shift;

    my %dictionary;

    # ,,,,,,,,,Case1,Hospitalized,,RunningCount,DayofM,,,,Died,Origin,Travel_Related,Travel,EDvisit,Age_group,Case
    $dictionary{'ObjectId'} = sub {
        my $old_val = shift;
        return ($old_val);
    };

    $dictionary{'Jurisdiction'} = sub {
        my $old_val = shift;
        return ($old_val);
    };

    $dictionary{'ChartDate'} = sub {
        my $old_val = shift;
        return ($old_val);
    };

    $dictionary{'Age'} = sub {
        my $old_val = shift;
        return ($old_val);
    };

    $dictionary{'County'} = sub {
        my $old_val = shift;
        return ($old_val);
    };

    $dictionary{'CaseNum'} = sub {
        my $old_val = shift;
        return ($old_val);
    };

    $dictionary{'State'} = sub {
        my $old_val = shift;
        return ($old_val);
    };

    $dictionary{'Contact'} = sub {
        my $old_val = shift;
        return ($old_val);
    };

    $dictionary{'DateChart'} = sub {
        my $old_val = shift;
        return ($old_val);
    };

    $dictionary{'DateC'} = sub {
        my $old_val = shift;
        return ($old_val);
    };

    $dictionary{'EventDate'} = sub {
        my $old_val = shift;
        my $change_log_for_this_file_ptr = shift;

        my $new_val;
        if ($old_val =~ /^\d{13}/) {
            $new_val = convert_epoch ($old_val);

            $change_log_for_this_file_ptr->{'EventDate'} = 1;
        }
        else {
            $new_val = $old_val;
        }

        return ($new_val);
    };

    $dictionary{'CaseDate'} = $dictionary{'EventDate'};

    $dictionary{'Gender'} = sub {
        my $old_val = shift;
        my $change_log_for_this_file_ptr = shift;

        if ($old_val eq 'Male') {
            $change_log_for_this_file_ptr->{'Male'} = 1;
            return ('M');
        }
        elsif ($old_val eq 'Female') {
            $change_log_for_this_file_ptr->{'Female'} = 1;
            return ('F');
        }
        else {
            return ($old_val);
        }
    };

    $dictionary{'Case_'} = sub {
        my $old_val = shift;
        my $change_log_for_this_file_ptr = shift;

        my $new_val;
        if ($old_val =~ /^(\d{2})\/(\d{2})\/(\d{2})/) {
            my $year = "20$3";
            my $month = "$2";
            my $day = "$1";
            my $hour = 0;
            my $minute = 0;
            $new_val = sprintf ("%04d-%02d-%02d %02d:%02d", $year, $month, $day, $hour, $minute);
            $change_log_for_this_file_ptr->{'Case_'} = 1;
        }
        elsif ($old_val =~ /^(\d+)\/(\d{2})\/(\d{4})/) {
            my $year = "$3";
            my $month = "$2";
            my $day = int ($1);
            my $hour = 0;
            my $minute = 0;
            $new_val = sprintf ("%04d-%02d-%02d %02d:%02d", $year, $month, $day, $hour, $minute);
            $change_log_for_this_file_ptr->{'Case_'} = 1;
        }
        elsif ($old_val =~ /^\d{13}/) {
            $new_val = convert_epoch ($old_val);
            $change_log_for_this_file_ptr->{'Case_'} = 1;
        }
        else {
            $new_val = $old_val;
        }

        return ($new_val);
    };

    return (\%dictionary);
}

sub convert_epoch {
    my $milliseconds = shift;

    my $microseconds = int ($milliseconds / 1000);
    my $seconds = int ($microseconds / 1000);

    my $dt = DateTime->from_epoch (epoch => $microseconds);

    # my $epoch = $dt->epoch();
    # print ("\$epoch = $epoch\n");

    my $day = $dt->day;
    my $month = $dt->month;
    my $year = $dt->year;
    my $hour = $dt->hour;
    my $minute = $dt->minute;
    my $string = sprintf ("%04d-%02d-%02d %02d:%02d", $year, $month, $day, $hour, $minute);

    return ($string);
}

1;  # required

