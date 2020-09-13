#!/usr/bin/perl
package byzip_local;
use warnings;
use strict;

#
# This file is part of byzip.pl. See information at the top of that file
#

use Cwd qw(cwd);
use POSIX;
use File::chdir;

#
# Edit the following as needed. If you are using Linux, ignore '_windows' and vice versa
#
my $fq_florida_root_dir_for_windows = 'D:/Covid/Florida/ByZip';
my $fq_florida_root_dir_for_linux = '/home/mickey/Florida/ByZip';
my $fq_newyork_root_dir_for_windows = 'D:/Covid/NewYork/ByZip';
my $fq_newyork_root_dir_for_linux = '/home/mickey/NewYork/ByZip';

my $pp_first_florida_directory = '2020-04-08';
my $pp_first_newyork_directory = '2020-03-31';

sub setup_local {
    my $state = shift;
    my $create_missing_directories_flag = shift;

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

    #
    # Go to root dir
    #
    if ($windows_flag && $state eq 'newyork') {
        $dir = lc $fq_newyork_root_dir_for_windows;
    }
    elsif ($windows_flag && $state eq 'florida') {
        $dir = lc $fq_florida_root_dir_for_windows;
    }
    elsif ($windows_flag == 0 && $state eq 'newyork') {
        $dir = lc $fq_newyork_root_dir_for_linux;
    }
    elsif ($windows_flag == 0 && $state eq 'florida') {
        $dir = lc $fq_florida_root_dir_for_linux;
    }
    else {
        print ("Can't figure out base \$dir\n");
        print ("  \$windows_flag = $windows_flag\n");
        print ("  \$state = $state\n");
        exit (1);
    }

    $CWD = $dir;
    $cwd = Cwd::cwd();

    if ($create_missing_directories_flag) {
        #
        # Make missing date directories
        #
        my $not_done = 1;
        while ($not_done) {
            $not_done = make_new_dirs ($dir);
        }
    }

    return (1, $dir);
}

###################################################################################
#
# This could be improved. See relative method
#
sub make_new_dirs {
    my $dir = shift;

    my $dur = DateTime::Duration->new (days => 1);
    my $now = DateTime->now;

    my @all_date_dirs;
    my $did_something_flag = 0;

    opendir (DIR, $dir) or die "Get_db_files() can't open $dir: $!";
    while (my $ff = readdir (DIR)) {
        #
        # This is used to rename a bunch of YYYY MM DD directories to YYYY-MM-DD
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

1;
