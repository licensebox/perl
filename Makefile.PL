use strict;use warnings;use ExtUtils::MakeMaker;
my $dir=$ENV{LICENSEBOX_LIB_DIR};
WriteMakefile(NAME=>'Licensebox',VERSION_FROM=>'lib/Licensebox.pm',ABSTRACT=>'Native Licensebox application SDK',AUTHOR=>'Vijai Kumar <https://meshing.engineer>',LICENSE=>'mit',LIBS=>[$dir?"-L$dir -llicensebox":'-llicensebox'],PREREQ_PM=>{'JSON::PP'=>0,'Encode'=>0},MIN_PERL_VERSION=>'5.020');
