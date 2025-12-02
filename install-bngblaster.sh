#!/bin/sh
LIBDICT_VERSION="1.0.4"
BNGBLASTER_VERSION="0.9.27"
mkdir /bngblaster
cd /bngblaster
wget https://github.com/rtbrick/libdict/archive/refs/tags/$LIBDICT_VERSION.zip
unzip $LIBDICT_VERSION.zip
mkdir libdict-$LIBDICT_VERSION/build
cd /bngblaster/libdict-$LIBDICT_VERSION/build
cmake ..
make -j16 install
cd /bngblaster
wget https://github.com/rtbrick/bngblaster/archive/refs/tags/$BNGBLASTER_VERSION.zip
unzip $BNGBLASTER_VERSION.zip
mkdir bngblaster-$BNGBLASTER_VERSION/build
cd /bngblaster/bngblaster-$BNGBLASTER_VERSION/build
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBNGBLASTER_VERSION=$BNGBLASTER_VERSION ..
make install