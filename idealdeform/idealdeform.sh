#!/bin/bash
#20190624 add support for any direction in cartesian axis space.for example,
#if you set shear to "on", then script will set mystrain according to shear_direction
#warning:the direction are based on cartesian direction!!!
#20190611 add support for specified strain tensor.you need add six tensor component
#in the mystrain,mystrain means step size of the apply strain.
#20190528 add true stress strain curve and add PBS related parameters and fix some bugs
#20190524 fix a bug
#a simple bash shell to perform ideal tansile or shear process,and get the
#stress-strain curve
#usage:prepare needed file for VASP, set ISIF=2, run this script, use stress_strain to plot curve
#warning: you should use the direct coordition 
#warning: your cell should better to be orthogonallty
#ponychen 2019/05/23
#email: 18709821294@outlook.com

#PBS related parameters
##PBS -L nodes=6:ppn=12
##PBS -L walltime=3:00:00
##PBS -V
##PBS -N test

#change following parameters as you like
orientation="XX"  #set which type of strain
initial=0.0       #set the initial strain
step=0.01         #set the step size
num=2             #how much strain to apply
mpiexec="vasp_std"
mystrain=( )      #set step size of the strain, if  specified, only num value are used and other valuies are ommtied
tensile="off"     #if on,then mystrain will be setted according to tensile_direction
tensile_direction=(1 1 1)  #direction in cartesian axis space three axis are xx yy zz
shear="off"       #if in,then mystrain will be setted according to shear_direction
shear_direction=(1 1 1) #three axis are xy xz yz

#mpiexe="mpirun -np 12 vasp_std"

#do not change following codes unless you know what you are doing
deform(){
#this function apply the specific strain on cell
local newstrain
newstrain=(` echo "$@" `)

eval $(awk -v arr1="${newstrain[*]}" '
           BEGIN{split(arr1, adds, " ");
	             adds[1]+=1;
			     adds[2]+=1;
			     adds[3]+=1;}
		   NR>=3 && NR<=5 {r0[NR]=$1;s0[NR]=$2;t0[NR]=$3}
		   END{r1[3]=adds[1]*r0[3]+adds[4]*r0[4]+adds[5]*r0[5];
		       s1[3]=adds[1]*s0[3]+adds[4]*s0[4]+adds[5]*s0[5];
			   t1[3]=adds[1]*t0[3]+adds[4]*t0[4]+adds[5]*t0[5];
			   r1[4]=adds[4]*r0[3]+adds[2]*r0[4]+adds[6]*r0[5];
			   s1[4]=adds[4]*s0[3]+adds[2]*s0[4]+adds[6]*s0[5];
			   t1[4]=adds[4]*t0[3]+adds[2]*t0[4]+adds[6]*t0[5];
			   r1[5]=adds[5]*r0[3]+adds[6]*r0[4]+adds[3]*r0[5];
			   s1[5]=adds[5]*s0[3]+adds[6]*s0[4]+adds[3]*s0[5];
			   t1[5]=adds[5]*t0[3]+adds[6]*t0[4]+adds[3]*t0[5];
			   for(i=3;i<=5;i++){
				   printf("newpos[%s]=\" %9.6f %9.6f %9.6f\n\";",i,r1[i],s1[i],t1[i])}
			   }' POSCAR)			   
sed -i "3c${newpos[3]}" POSCAR
sed -i "4c${newpos[4]}" POSCAR
sed -i "5c${newpos[5]}" POSCAR
}

unify(){
	#this function unify the prefactor of POSCAR to 1.000
	eval $(awk '
	    NR==2 {scal=$1}
		NR>=3 && NR<=5 {r[NR]=$1*scal;s[NR]=$2*scal;t[NR]=$3*scal}
	END{for(i=3;i<=5;i++){
	    printf("newaxis[%s]=\"%9.6f\t%9.6f\t%9.6f\n\";",i,r[i],s[i],t[i])}
	}' POSCAR)
    sed -i "2c 1.0000"      POSCAR
	sed -i "3c${newaxis[3]}" POSCAR
	sed -i "4c${newaxis[4]}" POSCAR
	sed -i "5c${newaxis[5]}" POSCAR
}

#unify the prefactor of POSCAR
unify

cp POSCAR POSCAR.orig
echo "starting calculation, hold on, drink coffee and sleeping..."

#check wether tensile or shear key word ativazed
if [ "$tensile" == "on" ];then
	eval $(awk -v dirc="${tensile_direction[*]}" -v step=$step  '
		BEGIN{split(dirc, add, " ");
		s=sqrt(add[1]^2+add[2]^2+add[3]^2);
     	t=s/step;
	 	for(i=1;i<=3;i++){
		 	add[i]=add[i]/t};
    	printf("mystrain=( %9.6f %9.6f %9.6f 0.0 0.0 0.0 )\n",add[1],add[2],add[3])}')
fi
if [ "$shear" == "on" ];then
	eval $(awk -v dirc="${shear_direction[*]}" -v step=$step  '
		BEGIN{split(dirc, add, " ");
		s=sqrt(add[1]^2+add[2]^2+add[3]^2);
     	t=s/step;
	 	for(i=1;i<=3;i++){
		 	add[i]=add[i]/t};
    	printf("mystrain=( 0.0 0.0 0.0 %9.6f %9.6f %9.6f )\n",add[1],add[2],add[3])}')
fi
#get the strain type
for((i=0;i<=num;i++))
do
    if  test -z "${mystrain[*]}" ;then
	eval $(awk -v i=$i -v step=$step -v initial=$initial '
	BEGIN {strain=initial+i*step;
	       printf("strain=%f;",strain)}'
	)
	case $orientation in
		"XX")
			Setstrain=( $strain 0.0 0.0 0.0 0.0 0.0 )
			col=3
			;;
		"YY")
			Setstrain=( 0.0 $strain 0.0 0.0 0.0 0.0 )
			col=4
			;;
		"ZZ")
			Setstrain=( 0.0 0.0 $strain 0.0 0.0 0.0 )
			col=5
			;;
		"XY")
			Setstrain=( 0.0 0.0 0.0 $strain 0.0 0.0 )
			col=6
			;;
		"XZ")
			Setstrain=( 0.0 0.0 0.0 0.0 $strain 0.0 )
			col=7
			;;
		"YZ")
			Setstrain=( 0.0 0.0 0.0 0.0 0.0 $strain )
			col=8
			;;
		*)
			echo "please rightly set your orientation value!!!"
			exit 1
			;;
	esac
    else
    eval $(awk -v arr1="${mystrain[*]}" -v i=$i '
	BEGIN {split(arr1, adds, " ");
          for(j=1;j<=6;j++){
          adds[j]=0.0+adds[j]*i;}
          printf("Setstrain=( %9.6f %9.6f %9.6f %9.6f %9.6f %9.6f );",adds[1],adds[2],adds[3],adds[4],adds[5],adds[6])}' )
    fi
	cp POSCAR.orig POSCAR
	args=`echo ${Setstrain[*]}`
	deform ${args}
	echo "iretation=$i, present strain is ${Setstrain[*]}"
	$mpiexec > /dev/null 2>&1
	if test -z "${mystrain[*]}";then
    grep " in kB" OUTCAR | tail -1 | awk -v col=$col -v strain=$strain '{print strain, -$col/10}' >> engineering_stress_strain.all
	grep " in kB" OUTCAR | tail -1 | awk -v col=$col -v strain=$strain '
	    {estress=-$col/10;
			tstress=estress*(1+strain);
			tstrain=log(1+strain);
			print tstrain, tstress}' >> true_stress_strain.all
		else
        grep " in kB" OUTCAR | tail -1 | awk -v num=$i -v arr1="${mystrain[*]}" '
		BEGIN{split(arr1, strain, " ");}
		{for(i=3;i<=8;i++){
			stress[i-2]=-$i/10}
		m=0;n=0;s=0;
		for(i=1;i<=6;i++){
			m+=stress[i]*strain[i];
			n+=strain[i];
		    s+=strain[i]^2;}
		stresstol=m/n;
		straintol=sqrt(s)*num;
        print straintol, stresstol;
	    }' >> engineering_stress_strain.all
        grep " in kB" OUTCAR | tail -1 | awk -v num=$i -v arr1="${mystrain[*]}" '
		BEGIN{split(arr1, strain, " ");}
		{for(i=3;i<=8;i++){
			stress[i-2]=-$i/10}
		m=0;n=0;s=0;
		for(i=1;i<=6;i++){
			m+=stress[i]*strain[i];
			n+=strain[i];
		    s+=strain[i]^2;}
		stresstol=m/n;
		straintol=sqrt(s)*num;
		tstress=stresstol*(1+straintol);
		tstrain=log(1+straintol);
        print tstrain, tstress;
	    }' >> true_stress_strain.all
	fi
    conver=`grep "reached required" OUTCAR `
    #check whether present iretation converge
	if [ -n "$conver" ]; then
		echo "present iretation converged"
	else
		echo "FBI warning: present iretation not converge, you may adjust your INCAR!"
		break
	fi
done
	
echo "all the iretation have finished"
#plot the curve, of course, just have a roughly look, maybe i will add a python script to have better curve
gnuplot -e "set term dumb; plot 'engineering_stress_strain.all'  w l"
#gnuplot -e "set term dumb; plot 'true_stress_strain.all' w l"
