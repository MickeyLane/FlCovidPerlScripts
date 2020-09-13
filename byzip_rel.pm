#!/usr/bin/perl
package byzip_rel;
use warnings;
use strict;

#
# This file is part of byzip.pl. See information at the top of that file
#

use LWP::Simple;
use File::chdir;
# https://drive.google.com/drive/folders/182LvT3tZaG7kALoNXRW1j4HP21uVafnb?usp=sharing
my $pp_google_byzip_share = 'https://drive.google.com/drive/folders/182LvT3tZaG7kALoNXRW1j4HP21uVafnb';
my $byzip_csv_name = 'byzip.csv';

my $pp_relative_local_data_dir = 'byzip_local_data_store';
my $pp_first_florida_directory = '2020-04-08';

sub setup_relative {

    my $dir;

    #
    # Get current directory and determine platform
    #
    my $windows_flag;
    my $cwd = Cwd::cwd();
    $windows_flag = 0;
    if ($cwd =~ /^[C-Z]:/) {
        $windows_flag = 1;
    }

    $dir = $cwd;
    my $fq_data_store_dir = "$dir/$pp_relative_local_data_dir";
    my $fq_first_date_dir = "$fq_data_store_dir/$pp_first_florida_directory";
    my $now_dt = DateTime->now();
    my $todays_directory = main::make_printable_date_string ($now_dt);
    my $fq_todays_date_dir = "$fq_data_store_dir/$todays_directory";

    #
    # See if a local store exists
    #
    print ("Checking for local storage dir ($fq_data_store_dir)...\n");
    if (!(-e $fq_data_store_dir)) {
        #
        # Local storage dir does not exist
        #
        print ("\nGrant permission to create local directory $fq_data_store_dir and\n");
        print ("   populate with downloaded zip data .csv files from a Google Drive? [y/n] ");
        my $nv = uc <STDIN>;  # force uppercase
        $nv =~ s/[\r\n]+//;
        if ($nv =~ /Y/) {
            #
            # Yes
            #
            print ("Making $fq_data_store_dir\n");
            mkdir ($pp_relative_local_data_dir) or die "Could not make $pp_relative_local_data_dir: $!";
        }
        else {
            #
            # No
            #
            print ("Permission not granted, execution halted\n");
            return (0);
        }
    }
    else {
        print ("Exists\n");
    }

    print ("Checking for 1st date dir ($fq_first_date_dir)...\n");
    if (!(-e $fq_first_date_dir)) {
        print ("Making $fq_first_date_dir\n");

        local $CWD = $pp_relative_local_data_dir;

        my $status = mkdir ($pp_first_florida_directory);
        my $reason = $!;
        if ($status == 0) {
            print ("Could not make $fq_first_date_dir: $reason\n");
            return (0);
        }

        print ("Created\n");
    }
    else {
        print ("Exists\n");
    }

    print ("Checking for today's date dir ($fq_todays_date_dir)...\n");
    if (!(-e $fq_todays_date_dir)) {

        print ("Making list of all possible date directories...\n");
        my $all_possible_dates_ptr = make_list_of_all_possible_date_dirs ($pp_first_florida_directory, $todays_directory);
        my @all_possible_dates = @$all_possible_dates_ptr;

        print ("Making missing date directories...\n");

        local $CWD = $pp_relative_local_data_dir;

        foreach my $dd (@all_possible_dates) {
            if (-e $dd) {
                next;
            }

            if (1) {
                mkdir ($dd);
            }
            else {
                print ("$dd\n");
            }
        }
    }
    else {
        print ("Exists\n");
    }

    my $url = "$pp_google_byzip_share/$pp_first_florida_directory/$byzip_csv_name";
    my $file = "$pp_relative_local_data_dir/$pp_first_florida_directory/$byzip_csv_name";

    #
    #
    #
    if (1) {
        my $code = getstore ($url, $file);
        print ("Getstore response code $code\n");
    }


    return (0, $dir);
}

sub make_list_of_all_possible_date_dirs {
    my $first_dir = shift;
    my $todays_directory = shift;

    my @list = $first_dir;
    my $current_epoch;

    #
    # Convert the 1st date dir string into an epoch value
    #
    if ($first_dir =~ /^(\d{4})-(\d{2})-(\d{2})/) {
        my $start_dt = DateTime->new (year => $1, month => $2, day => $3);
        $current_epoch = $start_dt->epoch();
    }
    else {
        print ("Passed a bad start date dir string\n");
        exit (1);
    }

    #
    # Get today's date into an epoch value
    #
    my $now_dt = DateTime->now();
    my $now_epoch = $now_dt->epoch();

    #
    # The loop starts with $current_epoch equal to the 1st dir. The 1st dir is
    # already in the list. Increment and add to list until the current date is
    # in the list
    #
    my $done = 0;
    while (!$done) {
        $current_epoch += 86400;

        if ($current_epoch <= $now_epoch) {                
            my $next_dt = DateTime->from_epoch (epoch => $current_epoch);
            my $next_date_dir = main::make_printable_date_string ($next_dt);
            push (@list, $next_date_dir);
        }
        else {
            $done = 1;
        }
    }

    return (\@list);
}

1;
