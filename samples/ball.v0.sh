#!/usr/bin/env sh

# magic value
printf '415656' | xxd -r -p > ball.v0.avv
# version number
printf '00' | xxd -r -p >> ball.v0.avv
# aspect ratio, looping video, calculating y, and 1
printf 'FFF0000000000000' | xxd -r -p >> ball.v0.avv
# 1 for max color, and without compression
printf '3F800000' | xxd -r -p >> ball.v0.avv
# 1 frame packet
printf '0000000000000000' | xxd -r -p >> ball.v0.avv
# skipping the packet offsets because we only have one packet
# a 2^32 ns video
printf '0000000100000000' | xxd -r -p >> ball.v0.avv


# create line
packet="00"
# start instantly
packet+="00000000"
# number of bytes (4 curves each with 4 points)
packet+="00D6"

# drawing lines from https://spencermortensen.com/articles/bezier-circle/ for circle
packet+="0000000000000000"
packet+="3FC00039C0E8D654"
packet+="3FB1B5B146205835"
packet+="3FBFF59F7D356C3D"
packet+="3FBFF59F7D356C3D"
packet+="3FB1B5B146205835"
packet+="3FC00039C0E8D654"
packet+="0000000000000000"
packet+="7FF0"
packet+="3FBFF59F7D356C3D"
packet+="BFB1B5B146205835"
packet+="3FB1B5B146205835"
packet+="BFBFF59F7D356C3D"
packet+="0000000000000000"
packet+="BFC00039C0E8D654"
packet+="7FF0"
packet+="BFB1B5B146205835"
packet+="BFBFF59F7D356C3D"
packet+="BFBFF59F7D356C3D"
packet+="BFB1B5B146205835"
packet+="BFC00039C0E8D654"
packet+="0000000000000000"
packet+="7FF0"
packet+="BFBFF59F7D356C3D"
packet+="3FB1B5B146205835"
packet+="BFB1B5B146205835"
packet+="3FBFF59F7D356C3D"
packet+="0000000000000000"
packet+="3FC00039C0E8D654"

# set the ball to blue
packet+="04"
# start instantly
packet+="00000000"
# number of bytes
packet+="000E"
# blue and alpha and 1 point set to 1
packet+="5000"
packet+="3FF0000000000000"
# only effect our first line
packet+="00000000"

# have ball fall
packet+="02"
# start instantly
packet+="00000000"
# number of bytes
packet+="0026"

# effects only x and 3 points
packet+="8002"
# (0,0)
packet+="0000000000000000"
# (2^31, 0)
packet+="80000000"
packet+="0000000000000000"
# (2^31, -1)
packet+="80000000"
packet+="BFF0000000000000"
# only effect our first line
packet+="00000000"

# have ball bounce back
packet+="02"
# start after ball is at the lowest
packet+="80000000"
# number of bytes
packet+="0026"

# effects only x and 3 points
packet+="8002"
# (0,0)
packet+="0000000000000000"
# (2^31, 0)
packet+="80000000"
packet+="0000000000000000"
# (2^31, 1)
packet+="80000000"
packet+="3FF0000000000000"
# only effect our first line
packet+="00000000"

printf "%s" "$packet" | xxd -r -p | lzma -9 >> ball.v0.avv
