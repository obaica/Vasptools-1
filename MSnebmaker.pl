#!perl
#add a sortatoms function ,sort the atoms if the atoms oder changes . but not works for stacking faults!!! ponychen 20190502.
#i like model systems in MS but it's awful to make neb path by using nebmake.pl under linux. sometimes you need further modulate the path.thus i
#wrote this script to create neb path in the MS. make life better.....
#usage: 1.drag your initial and final structure into MS
#       2.set the values $inifile $finfile $images_num $dmin
#       3.run it and click in the status.txt, it will tell you the atoms meeting too closely!! you may futher modurate these images by yourself!!
#caution: please make sure the cell and atom orders are exactly right between initial and final structures.
#author: ponychen  20190426
#email: 18709821294@outlook.com
use strict;
use Getopt::Long;
use MaterialsScript qw(:all);

#chage following values
my $inifile = "00"; #your initial xsd filename
my $finfile = "08"; #your final xsd filename
my $images_num = 5; #how much images would you create
my $dmin = 2.0;       #belowe which the atoms are thought to be close, unit angstrom
my $sort = "False"; # if True, sored the final structure by the initial structure

#do not change below codes unless you konw what yuou are doing!!!
my @stepx;
my @stepy;
my @stepz;
my $status = Documents->New("status.txt");

my $inidoc = $Documents{"$inifile.xsd"};
my $findoc = $Documents{"$finfile.xsd"};

my $iniatoms = $inidoc->UnitCell->Atoms;
my $finatoms = $findoc->UnitCell->Atoms;
       

sub check_d {
    #this function check the distance between atoms, three input parameters are: atoms list, output status file, dmin
    my ($a, $b, $c) = @_;
    for(my $m=0; $m<$a->Count; ++$m){
        for(my $n=$m+1; $n<$a->Count; ++$n){
            my $dx = (@$a[$m]->X - @$a[$n]->X)**2;
            my $dy = (@$a[$m]->Y - @$a[$n]->Y)**2;
            my $dz = (@$a[$m]->Z - @$a[$n]->Z)**2;
            my $ds = sqrt($dx + $dy + $dz);
            if ($ds < $dmin){
                $b->Append(sprintf " caution! the %sth atom and %sth atom in %s.xsd are too close. \n", $m, $n, $c);
                }}}
                }

sub sortatoms {
    my ($k, $l) = @_;
    my $sorteddoc = Documents->New("sorted.xsd");
    $sorteddoc->CopyFrom($inidoc);
    my $sortedatoms = $sorteddoc->UnitCell->Atoms;
    for(my $i=0; $i<$sortedatoms->Count; ++$i){
        my $rc = 5;
        my $atomnew = @$l[0];
        foreach my $atoml (@$l){
            my $r = (@$k[$i]->X - $atoml->X)**2 + (@$k[$i]->Y - $atoml->Y)**2 + (@$k[$i]->Z - $atoml->Z)**2;
            if ($r < $rc and @$k[$i]->ElementSymbol == $atoml->ElementSymbol){
                $rc = $r;
                $atomnew = $atoml;
                }
        }
        @$sortedatoms[$i]->X = $atomnew->X;
        @$sortedatoms[$i]->Y = $atomnew->Y;
        @$sortedatoms[$i]->Z = $atomnew->Z;
        
        }}
        
if ( $sort eq "True" ){

sortatoms($iniatoms, $finatoms);
$finatoms = $Documents{"sorted.xsd"}->UnitCell->Atoms;
$finfile = "sorted";
       }

check_d($iniatoms, $status, $inifile);
check_d($finatoms, $status, $finfile);

#get the stepsize between images            
for(my $i=0; $i<$iniatoms->Count; ++$i){
    $stepx[$i] = (@$finatoms[$i]->X - @$iniatoms[$i]->X)/($images_num + 1);
    $stepy[$i] = (@$finatoms[$i]->Y - @$iniatoms[$i]->Y)/($images_num + 1);
    $stepz[$i] = (@$finatoms[$i]->Z - @$iniatoms[$i]->Z)/($images_num + 1);
    }

#create images
for(my $j=1; $j<=$images_num; ++$j){
    my $innerdoc = Documents->New("$j.xsd");
    $innerdoc->CopyFrom($inidoc);
    my $inneratoms = $innerdoc->UnitCell->Atoms;
    for(my $k=0; $k<$inneratoms->Count; ++$k){
        @$inneratoms[$k]->X = @$iniatoms[$k]->X + $j*$stepx[$k];
        @$inneratoms[$k]->Y = @$iniatoms[$k]->Y + $j*$stepy[$k];
        @$inneratoms[$k]->Z = @$iniatoms[$k]->Z + $j*$stepz[$k];
    }
    check_d($inneratoms, $status, $j);
    }
