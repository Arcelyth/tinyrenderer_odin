package main

import "core:fmt"

White := TGAColor {{255, 255, 255, 255}, 4}
Black := TGAColor {{0, 0, 0, 255}, 4}
Green := TGAColor {{  0, 255,   0, 255}, 4}
Red := TGAColor {{  0,   0, 255, 255}, 4}
Blue := TGAColor {{255, 128,  64, 255}, 4}
Yellow := TGAColor {{  0, 200, 255, 255}, 4}

main :: proc() {
    width, height := 64, 64
    framebuffer := image_init(width, height, TGAFormat.RGB, Black)

    image_set(&framebuffer, 7, 3, White)
    image_set(&framebuffer, 12, 37, White)
    image_set(&framebuffer, 62, 53, White)

    if write_tga_file(framebuffer, "output.tga", false, false) {
        fmt.println("File saved successfully!")
    }
}

