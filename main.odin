package main

import "core:fmt"
import "core:math"

White := TGAColor {{255, 255, 255, 255}, 4}
Black := TGAColor {{0, 0, 0, 255}, 4}
Green := TGAColor {{  0, 255,   0, 255}, 4}
Red := TGAColor {{  0,   0, 255, 255}, 4}
Blue := TGAColor {{255, 128,  64, 255}, 4}
Yellow := TGAColor {{  0, 200, 255, 255}, 4}

line :: proc(ax, ay, bx, by: int, framebuffer: ^TGAImage, color: TGAColor) {
    for t := 0.; t < 1.; t += .02 {
        x := math.round(f64(ax) + f64(bx - ax) * t)
        y := math.round(f64(ay) + f64(by - ay) * t)
        image_set(framebuffer, int(x), int(y), color)
    }
}

main :: proc() {
    width, height := 64, 64
    framebuffer := image_init(width, height, TGAFormat.RGB, Black)

    ax, ay := 7, 3
    bx, by := 12, 37
    cx, cy := 62, 53
    image_set(&framebuffer, ax, ay, White)
    image_set(&framebuffer, bx, by, White)
    image_set(&framebuffer, cx, cy, White)

    line(ax, ay, bx, by, &framebuffer, Blue);
    line(cx, cy, bx, by, &framebuffer, Green);
    line(cx, cy, ax, ay, &framebuffer, Yellow);
    line(ax, ay, cx, cy, &framebuffer, Red);

    if write_tga_file(framebuffer, "output.tga", false, true) {
        fmt.println("File saved successfully!")
    }
}





