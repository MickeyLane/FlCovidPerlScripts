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
my $fq_root_dir_for_windows = 'D:/Covid/ByZip';
my $fq_root_dir_for_linux = '/home/mickey/ByZip';



sub setup_local {
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

    #
    # Go to root dir
    #
    if ($windows_flag) {
        $dir = lc $fq_root_dir_for_windows;
    }
    else {
        $dir = $fq_root_dir_for_linux;
    }

    $CWD = $dir;
    $cwd = Cwd::cwd();

    return (1, $dir);
}

1;
