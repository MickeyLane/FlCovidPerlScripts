#!/usr/bin/perl
package byzip_rel;
use warnings;
use strict;

#
# This file is part of byzip.pl. See information at the top of that file
#

# my $pp_google_byzip_share = 'https://drive.google.com/drive/folders/1hIXQUJExG0AWPm2oY5F_e_FbRmFwTeoG?usp=sharing';
my $pp_google_byzip_share = 'https://drive.google.com/drive/folders/1hIXQUJExG0AWPm2oY5F_e_FbRmFwTeoG';

sub setup {
    my $relative_local_data_dir = shift;
    my $first_directory = shift;

    my $cwd = Cwd::cwd();

    #
    # See if a local store exists
    #
    my $fq_data_store_dir = "$cwd/$relative_local_data_dir";
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
            mkdir ($fq_data_store_dir) or die "Could not make $fq_data_store_dir: $!";
        }
        else {
            #
            # No
            #
            print ("Permission not granted, execution halted\n");
            return (0);
        }
    }

    my $fq_first_date_dir = "$fq_data_store_dir/$first_directory";
    print ("Checking for $fq_first_date_dir...\n");
    if (!(-e $fq_first_date_dir)) {
        print ("Making $fq_first_date_dir\n");
        my $status = mkdir ($fq_data_store_dir);
        my $reason = $!;
        if ($status == 0) {
            print ("Could not make $fq_first_date_dir: $reason\n");
            return (0);
        }
    }

#
#
#
# use LWP::Simple;
# getstore($url, $file);


    return (1);
}

1;
