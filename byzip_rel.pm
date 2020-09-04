#!/usr/bin/perl
package byzip_rel;
use warnings;
use strict;

#
# This file is part of byzip.pl. See information at the top of that file
#

use LWP::Simple;
use File::chdir;

# my $pp_google_byzip_share = 'https://drive.google.com/drive/folders/1hIXQUJExG0AWPm2oY5F_e_FbRmFwTeoG?usp=sharing';
my $pp_google_byzip_share = 'https://drive.google.com/drive/folders/1hIXQUJExG0AWPm2oY5F_e_FbRmFwTeoG';

my $byzip_csv_name = 'byzip.csv';

sub setup_relative {
    my $relative_local_data_dir = shift;
    my $first_directory = shift;

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
    my $fq_data_store_dir = "$dir/$relative_local_data_dir";
    my $fq_first_date_dir = "$fq_data_store_dir/$first_directory";
    my $now_dt = DateTime->now();
    my $now_epoch = $now_dt->epoch();
    my $fq_todays_date_dir = main::make_printable_date_string ($now_dt);

    #
    # See if a local store exists
    #
    print ("Checking for $fq_data_store_dir...\n");
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
            mkdir ($relative_local_data_dir) or die "Could not make $relative_local_data_dir: $!";
        }
        else {
            #
            # No
            #
            print ("Permission not granted, execution halted\n");
            return (0);
        }
    }

    print ("Checking for $fq_first_date_dir...\n");
    if (!(-e $fq_first_date_dir)) {
        print ("Making $fq_first_date_dir\n");

        local $CWD = $relative_local_data_dir;

        my $status = mkdir ($first_directory);
        my $reason = $!;
        if ($status == 0) {
            print ("Could not make $fq_first_date_dir: $reason\n");
            return (0);
        }

        print ("Created\n");
    }

    print ("Checking for $fq_todays_date_dir...\n");
    if (!(-e $fq_todays_date_dir)) {
        print ("Making missing date directories\n");

        my @dirs_to_create;

        opendir (DIR, $relative_local_data_dir) or die "Get_db_files() can't open $relative_local_data_dir: $!";
        while (my $ff = readdir (DIR)) {
            if ($ff =~ /^(\d{4})-(\d{2})-(\d{2})/) {
                my $current_dt = DateTime->new(
                    year       => $1,
                    month      => $2,
                    day        => $3
                );
                my $current_epoch = $current_dt->epoch();

                my $next_epoch = $current_epoch + 86400;

                if ($next_epoch <= $now_epoch) {                
                    my $next_dt = DateTime->from_epoch (epoch => $next_epoch);
                    my $next_date_dir = main::make_printable_date_string ($next_dt);
                    push (@dirs_to_create, $next_date_dir);
                }
            }

        }
        
        local $CWD = $relative_local_data_dir;

        # main::make_new_dirs ($relative_local_data_dir);
    }

    my $url = "$pp_google_byzip_share/$first_directory/$byzip_csv_name";
    my $file = "$relative_local_data_dir/$first_directory/$byzip_csv_name";

    #
    #
    #
    # 
    my $code = getstore ($url, $file);
    print ("Getstore response code $code\n");


    return (1, $dir);
}

1;
