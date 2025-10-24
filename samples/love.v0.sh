#!/usr/bin/env sh

# magic value
printf '415656' | xxd -r -p > love.v0.avv
# version number
printf '00' | xxd -r -p >> love.v0.avv
# aspect ratio, looping video, calculating y, and 1
printf 'FFF0000000000000' | xxd -r -p >> love.v0.avv
# 1 for max color, and without compression
printf '3F800000' | xxd -r -p >> love.v0.avv
# 1 frame packet
printf '0000000000000000' | xxd -r -p >> love.v0.avv
# skipping the packet offsets because we only have one packet
# a 2^32 ns video
printf '0000000100000000' | xxd -r -p >> love.v0.avv

# create line
packet="00"
# start instantly
packet+="00000000"
# number of bytes
packet+="0096"

# Lines for the heart
packet+="0000000000000000"
packet+="3FE0000000000000"
packet+="3FE0000000000000"
packet+="BFD0000000000000"
packet+="7FF0"
packet+="3FEA666666666666"
packet+="BFE8000000000000"
packet+="0000000000000000"
packet+="BFE8000000000000"
packet+="0000000000000000"
packet+="BFD0000000000000"
packet+="7FF0"
packet+="0000000000000000"
packet+="BFE8000000000000"
packet+="BFEA666666666666"
packet+="BFE8000000000000"
packet+="BFE0000000000000"
packet+="BFD0000000000000"
packet+="7FF0"
packet+="0000000000000000"
packet+="3FE0000000000000"

# grow
packet+="09"
# start instantly
packet+="00000000"
# number of bytes
packet+="0036"

# 3 points
packet+="0002"
# start from orgign
packet+="0000000000000000"
packet+="0000000000000000"
# (0,1)
packet+="3FF0000000000000"
# (2^31, 1)
packet+="80000000"
packet+="3FF0000000000000"
# (2^31, 1.5)
packet+="80000000"
packet+="3FF8000000000000"
# only effect our first line
packet+="00000000"

# grow back
packet+="09"
# start after love is at the lowest
packet+="80000000"
# number of bytes
packet+="0036"

# 3 points
packet+="0002"
# start from orgign
packet+="0000000000000000"
packet+="0000000000000000"
# (0,1)
packet+="3FF0000000000000"
# (2^31, 2/3)
packet+="80000000"
packet+="3FE5555555555555"
# (2^31, 2/3)
packet+="80000000"
packet+="3FE5555555555555"
# only effect our first line
packet+="00000000"

printf "%s" "$packet" | xxd -r -p | lzma -9 >> love.v0.avv
