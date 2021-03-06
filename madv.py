#!/usr/bin/python3
#minimum atom displacement vector (madv) method by ponychen
#just use!
#author:ponychen
#20190819
#email:18709821294@outlook.com
#20190820:add support for Cartesian format POSCAR, and add a XDATCAR output for visualizing the movie. remeber, all output
#images are in Cartesian format! by ponychen
#20190822:add support for reading initial transition path, be carefaul, all the images should have the same coordination 
#format, this option is controled by value readfromexits, default False. by ponychen

import numpy as np
import os
import re
import sys

#some default values, you may change it depend on you condition
step_init = 0.3 #step size
dmin = 2.3  #below which the atoms are thought to be close, unit angstrom
maxitr = 100 #the maximum iteration for each cycle in optimization
amp = 2 #the amptitude of weight function A/d^-N
power = 4 #the power of weight function A/d^-N
readfromexits = False #read transition path from user bulit, default False

#read from user input
images = int(input("please input number of images: "))
if not readfromexits:
    ininame = input("please input name of initial structure: ")
    finname = input("please input name of final structure: ")

#read initial structures
if readfromexits:
    fileopen = open("00/POSCAR", 'r') #read from the initial structure of exsting transition path
else:
    fileopen = open(ininame,'r')
ini_data = fileopen.readlines()
fileopen.close()

#check whether atom are being frozen
if re.search('sel', ini_data[7], re.I):
    head = ini_data[:9]
    atom_num = sum(map(int, head[6].split()))
    ini_data = ini_data[9:9+atom_num]
    frozen = 1
    #check whether the coordination are in Cartesian format or direct format
    if re.search('dir', head[8], re.I):
        head[8] = "Cartesian \n"
        direct = 1
    else:
        direct = 0
else:
    head = ini_data[:8]
    atom_num = sum(map(int, head[6].split()))
    ini_data = ini_data[8:8+atom_num]
    frozen = 0
    #check whether the coordination are in cartesian format or direct format
    if re.search('dir', head[7], re.I):
        head[7] = "Cartesian \n"
        direct = 1
    else:
        direct = 0

tmp = []
fix = []
fixx = [0, 0, 0]
for i in range(atom_num):
    tmp.append(list(map(float, ini_data[i].split()[0:3])))
    if frozen == 1:
        for j in range(3):
            if ini_data[i].split()[j+3] == "F":
                fixx[j] = "F"
            else:
                fixx[j] = "T"
        fix.append([fixx[0], fixx[1], fixx[2]])

pos_a = np.array(tmp)

#read the coordition matrix of three bias axis, not support for the case of ssNEB
tmp = []
for i in range(2,5):
    tmp.append(list(map(float, head[i].split())))
axis = np.array(tmp)

#read final structure
if readfromexits:
    if images < 9:
        filename = "0"+str(images+1)+"/POSCAR"
    else:
        filename = str(images+1)+"/POSCAR"
    fileopen = open(filename, "r")
else:
    fileopen = open(finname, "r")
fin_data = fileopen.readlines()
fileopen.close()

#keep frozen condition same with initial structure
if frozen == 1:
    fin_data = fin_data[9:9+atom_num]
else:
    fin_data = fin_data[8:8+atom_num]

tmp = []
for i in fin_data:
    tmp.append(list(map(float, i.split()[0:3])))
pos_b = np.array(tmp)

#if read from exsting path, then read all the images to pos_im
if readfromexits:
    pos_im = np.zeros([images, atom_num, 3])
    for i in range(images):
        if i+1 < 10:
            filename = "0"+str(i+1)+"/POSCAR"
        else:
            filename = str(i+1)+"/POSCAR"
        fileopen = open(filename, "r")
        image_data = fileopen.readlines()
        fileopen.close()
        if frozen == 1:
            image_data = image_data[9:9+atom_num]
        else:
            image_data = image_data[8:8+atom_num]
        tmp = []
        for j in image_data:
            tmp.append(list(map(float, j.split()[0:3])))
        pos_im[i] = np.array(tmp)

#if the input POSCARs are in cartesian format, transfer them into direct format
if not direct:
    inverse_axis = np.linalg.inv(axis) #get the inverse matrix of axis
    if not readfromexits:
        for i in range(atom_num):
            pos_a[i] = np.dot(pos_a[i], inverse_axis)
            pos_b[i] = np.dot(pos_b[i], inverse_axis)
else:
    if readfromexits:
        for i in range(atom_num):
            pos_a[i] = np.dot(pos_a[i], axis)
            pos_b[i] = np.dot(pos_b[i], axis)
        for i in range(images):
            for j in range(atom_num):
                pos_im[i,j] = np.dot(pos_im[i,j], axis)

#correction of periodic boundary condition only support direct format
if not readfromexits:
    for i in range(atom_num):
        for j in range(3):
            if pos_a[i,j] - pos_b[i,j] > 0.5:
                pos_a[i,j] -= 1
            if pos_a[i,j] - pos_b[i,j] < -0.5:
                pos_b[i,j] -= 1

#get linear interpolation between initial and final structure
if not readfromexits:
    pos_im = np.zeros([images, atom_num, 3]) #3D position matrix
    for i in range(images):
        pos_im[i] = pos_a+(i+1)*(pos_b-pos_a)/(images+1.0)

#transfer the direct coordination to cartesian coordination
if not readfromexits:
    for i in range(images):
        for j in range(atom_num):
            pos_im[i,j] = np.dot(pos_im[i,j],axis)

    for i in range(atom_num):
        pos_a[i] = np.dot(pos_a[i],axis)
        pos_b[i] = np.dot(pos_b[i],axis)

#optimize the atoms that are too close based on hard sphere model
for i in range(images):
    flag = 1 #start the following loop
    itr = 0 #initilize the step number
    while flag:
        #initialize
        flag = 0 #agin initialize, this means this program default was there no atoms being closely
        advec = np.zeros([atom_num,3]) #a matrix to store the displacement vector of each atom
        itr += 1
        print("now calculating the "+str(i+1)+" image, iteration "+str(itr))

        for j in range(atom_num):
            for k in range(atom_num):
                if j != k:
                    tmp = pos_im[i,j]-pos_im[i,k]
                    ds = np.sqrt(sum(tmp**2))
                    #check whther this two atom meet too cloaely
                    if ds < dmin:
                        #apply weighting function
                        flag += 1
                        advec[j] += amp/ds**power*tmp
        #displace atoms by displacement vector
        if frozen == 1:
            for j in range(atom_num):
                for k in range(3):
                    if fix[j][k] == "T":
                        pos_im[i,j,k] += step_init*advec[j,k]
        else:
            for j in range(atom_num):
                pos_im[i,j] += step_init*advec[j]

        if flag == 0:
            print("the "+str(i+1)+" image has converged!")

        #if iteration steps reaching maxitr, break and you should check relative parameters
        if itr > maxitr:
            sys.exit("buddy, please check default parameters, maybe you should alter them, or you can try idpp.py write by me.")


#mkdir and generate poscar file for neb
if images + 1 < 10:
    num = "0" + str(images+1)
else:
    num = str(images+1)

if not readfromexits:
    os.system("mkdir 00")
    f = open("00/POSCAR", "a+")
    f.writelines(head)
    data = pos_a.tolist()
    for i in range(atom_num):
        line = map(str, data[i])
        line = " ".join(line)
        if frozen == 1:
            line = line + "    " +fix[i][0]+fix[i][1]+fix[i][2]+"\n"
        else:
            line += "\n"
        f.write(line)
    f.close()
    os.system("mkdir "+num)
    filename = str(num)+"/POSCAR"
    f = open(filename, "a+")
    f.writelines(head)
    data = pos_b.tolist()
    for i in range(atom_num):
        line = map(str, data[i])
        line = " ".join(line)
        if frozen == 1:
            line = line + "    " +fix[i][0]+fix[i][1]+fix[i][2]+"\n"
        else:
            line += "\n"
        f.write(line)
    f.close()
    for i in range(images):
        if i+1<10:
            num = "0"+str(i+1)
        else:
            num = str(i+1)
        os.system("mkdir "+num)
        data = pos_im[i].tolist()
        filename = num + "/POSCAR"
        f = open(filename, "a+")
        f.writelines(head)
        for j in range(atom_num):
            line = map(str, data[j])
            line = " ".join(line)
            if frozen == 1:
                line = line + "    " + fix[j][0] +fix[j][1] +fix[j][2] + "\n"
            else:
                line += "\n"
            f.write(line)
        f.close()
else:
    os.system("mkdir new")
    os.system("mkdir new/00")
    os.system("cp 00/POSCAR  new/00/POSCAR ")
    os.system("mkdir new/"+num)
    os.system("cp "+num+"/POSCAR"+" new/"+num+"/POSCAR")
    for i in range(images):
        if i+1<10:
            num = "new/"+"0"+str(i+1)
        else:
            num = "new/"+str(i+1)
        os.system("mkdir "+num)
        data = pos_im[i].tolist()
        filename = num + "/POSCAR"
        f = open(filename, "a+")
        f.writelines(head)
        for j in range(atom_num):
            line = map(str, data[j])
            line = " ".join(line)
            if frozen == 1:
                line = line + "    " + fix[j][0] +fix[j][1] +fix[j][2] + "\n"
            else:
                line += "\n"
            f.write(line)
        f.close()
#generate a XDATCAR watching the movie
f = open("XDATCAR", "a+")
f.writelines(head[:7])
f.write("Cartesian configuration=    1\n")
for i in range(atom_num):
    line = map(str, pos_a[i])
    line = " ".join(line)
    line += "\n"
    f.write(line)
for i in range(images):
    f.write("Cartesian configuration=     "+str(i+2)+"\n")
    for j in range(atom_num):
        line = map(str, pos_im[i,j])
        line =  " ".join(line)
        line += "\n"
        f.write(line)
f.write("Cartesian configuration=     "+str(images+2)+"\n")
for i in range(atom_num):
    line = map(str, pos_b[i])
    line = " ".join(line)
    line += "\n"
    f.write(line)
f.close()
