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


# create line
printf '00' | xxd -r -p >> ball.v0.avv
# start instantly
printf '00000000' | xxd -r -p >> ball.v0.avv
# number of bytes minus one (4 curves each with 4 points)
printf '00D5' | xxd -r -p >> ball.v0.avv

# drawing lines from https://spencermortensen.com/articles/bezier-circle/ for circle
printf '0000000000000000' | xxd -r -p >> ball.v0.avv
printf '3FC00039C0E8D654' | xxd -r -p >> ball.v0.avv
printf '3FB1B5B146205835' | xxd -r -p >> ball.v0.avv
printf '3FBFF59F7D356C3D' | xxd -r -p >> ball.v0.avv
printf '3FBFF59F7D356C3D' | xxd -r -p >> ball.v0.avv
printf '3FB1B5B146205835' | xxd -r -p >> ball.v0.avv
printf '3FC00039C0E8D654' | xxd -r -p >> ball.v0.avv
printf '0000000000000000' | xxd -r -p >> ball.v0.avv
printf '7FF0' | xxd -r -p >> ball.v0.avv
printf '3FBFF59F7D356C3D' | xxd -r -p >> ball.v0.avv
printf 'BFB1B5B146205835' | xxd -r -p >> ball.v0.avv
printf '3FB1B5B146205835' | xxd -r -p >> ball.v0.avv
printf 'BFBFF59F7D356C3D' | xxd -r -p >> ball.v0.avv
printf '0000000000000000' | xxd -r -p >> ball.v0.avv
printf 'BFC00039C0E8D654' | xxd -r -p >> ball.v0.avv
printf '7FF0' | xxd -r -p >> ball.v0.avv
printf 'BFB1B5B146205835' | xxd -r -p >> ball.v0.avv
printf 'BFBFF59F7D356C3D' | xxd -r -p >> ball.v0.avv
printf 'BFBFF59F7D356C3D' | xxd -r -p >> ball.v0.avv
printf 'BFB1B5B146205835' | xxd -r -p >> ball.v0.avv
printf 'BFC00039C0E8D654' | xxd -r -p >> ball.v0.avv
printf '0000000000000000' | xxd -r -p >> ball.v0.avv
printf '7FF0' | xxd -r -p >> ball.v0.avv
printf 'BFBFF59F7D356C3D' | xxd -r -p >> ball.v0.avv
printf '3FB1B5B146205835' | xxd -r -p >> ball.v0.avv
printf 'BFB1B5B146205835' | xxd -r -p >> ball.v0.avv
printf '3FBFF59F7D356C3D' | xxd -r -p >> ball.v0.avv
printf '0000000000000000' | xxd -r -p >> ball.v0.avv
printf '3FC00039C0E8D654' | xxd -r -p >> ball.v0.avv

# set the ball to blue
printf '04' | xxd -r -p >> ball.v0.avv
# start instantly
printf '00000000' | xxd -r -p >> ball.v0.avv
# number of bytes
printf '000A' | xxd -r -p >> ball.v0.avv
# blue and alpha and 1 point set to 1
printf '5000' | xxd -r -p >> ball.v0.avv
printf '3FF0000000000000' | xxd -r -p >> ball.v0.avv

# have ball fall
printf '02' | xxd -r -p >> ball.v0.avv
# start instantly
printf '00000000' | xxd -r -p >> ball.v0.avv
# number of bytes
printf '0024' | xxd -r -p >> ball.v0.avv

# effects only x and 3 points
printf '8002' | xxd -r -p >> ball.v0.avv
# (0,0)
printf '0000000000000000' | xxd -r -p >> ball.v0.avv
# (2^31, 0)
printf '80000000' | xxd -r -p >> ball.v0.avv
printf '0000000000000000' | xxd -r -p >> ball.v0.avv
# (2^31, -1)
printf '80000000' | xxd -r -p >> ball.v0.avv
printf 'BFF0000000000000' | xxd -r -p >> ball.v0.avv
# only effect our first line
printf '00000001' | xxd -r -p >> ball.v0.avv

# have ball bounce back
printf '02' | xxd -r -p >> ball.v0.avv
# start instantly
printf '00000000' | xxd -r -p >> ball.v0.avv
# number of bytes
printf '0024' | xxd -r -p >> ball.v0.avv

# effects only x and 3 points
printf '8003' | xxd -r -p >> ball.v0.avv
# (0,0)
printf '0000000000000000' | xxd -r -p >> ball.v0.avv
# (2^31, 0)
printf '80000000' | xxd -r -p >> ball.v0.avv
printf '0000000000000000' | xxd -r -p >> ball.v0.avv
# (2^31, 1)
printf '80000000' | xxd -r -p >> ball.v0.avv
printf '3FF0000000000000' | xxd -r -p >> ball.v0.avv
# only effect our first line
printf '00000001' | xxd -r -p >> ball.v0.avv
