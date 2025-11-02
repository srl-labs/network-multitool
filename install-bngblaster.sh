#!/bin/sh
mkdir /bngblaster
cd /bngblaster
wget https://github.com/rtbrick/libdict/archive/refs/tags/1.0.4.zip
unzip 1.0.4.zip
mkdir libdict-1.0.4/build
cd /bngblaster/libdict-1.0.4/build
cmake ..
make -j16 install
cd /bngblaster
wget https://github.com/rtbrick/bngblaster/archive/refs/tags/0.9.26.zip
unzip 0.9.26.zip
mkdir bngblaster-0.9.26/build
cd /bngblaster/bngblaster-0.9.26/build
#remove redundant include to avoid preprocessor redirect warning and consequent compilation failure
sed -i '/#include <sys\/signal.h>/d' ../code/lwip/contrib/ports/unix/port/netif/sio.c
#typedef for uint to avoid compilation error on alpine musl libc
sed -i '$i typedef unsigned int uint;' ../code/common/src/common.h
# add include to support be32toh and htobe32 on alpine musl libc
sed -i '/#include <stdlib.h>/i #include <endian.h>' ../code/common/src/common.h 
#replace __time_t with time_t to make it compatible with alpine musl libc
find /bngblaster/bngblaster-0.9.26/code/ -type f \( -name "*.c" -o -name "*.h" \) -exec sed -i 's/\b__time_t\b/time_t/g' {} +
#Don't error on sequence-point errors to allow build to complete on musl libc. Ideally code should be fixed on upstream repo.
sed -i 's/APPEND CMAKE_C_FLAGS "-pthread"/APPEND CMAKE_C_FLAGS "-pthread -Wno-error=sequence-point"/' ../code/bngblaster/CMakeLists.txt
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBNGBLASTER_VERSION=0.9.26 ..
make install