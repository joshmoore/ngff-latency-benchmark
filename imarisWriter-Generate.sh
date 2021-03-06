#!/usr/bin/env bash
#generate files

set -e
set -u

OUTPUT=${1:-ImarisFiles}
echo **********************************
echo Writing data to: $OUTPUT
echo **********************************

cd ImarisWriterTest/application
mkdir ${OUTPUT}
for (( x=1024; x<=16384; x=x*16))
do
  for (( z=1; z<=1024; z=z*16))
  do
    for (( t=1; t<=1024; t=t*16))
    do
      for (( c=1; c<=3; c++))
      do
        for (( xc=32; xc<=1024; xc=xc*8))
        do
          for (( zc=1; zc<=64 && zc <= z; zc=zc*8))
          do
            ./ImarisWriterTestRelease -sizex $x -sizey $x -sizez $z -sizet $t -sizec $c -chunkx $xc -chunky $xc -chunkz $zc -type 16bit -threads 8 -outputpath ${OUTPUT}  IMS_XY-$x-Z-$z-T-$t-C-$c-XYC-$xc-ZC-$zc.ims
          done
        done
      done
    done
  done
done
