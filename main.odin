package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:time"

White := TGAColor {{255, 255, 255, 255}, 4}
Black := TGAColor {{0, 0, 0, 255}, 4}
Green := TGAColor {{  0, 255,   0, 255}, 4}
Red := TGAColor {{  0,   0, 255, 255}, 4}
Blue := TGAColor {{255, 128,  64, 255}, 4}
Yellow := TGAColor {{  0, 200, 255, 255}, 4}

// Bresenham's line algorithm
line :: proc(x0, y0, x1, y1: int, framebuffer: ^TGAImage, color: TGAColor) {
    ax, ay, bx, by := x0, y0, x1, y1
    steep := false
    // if line is steep, transpose the image
    if abs(ax - bx) < abs(ay - by) {
        ax, ay = ay, ax
        bx, by = by, bx
        steep = true
    }
    if ax > bx {
        ax, bx = bx, ax
        ay, by = by, ay
    }
    dx := bx - ax
    dy := abs(ay - by)
    error := 0
    y := ay
    ystep := ay < by ? 1 : -1

    for x in ax..=bx {
        // if transposed, de−transpose
        if steep {
            image_set(framebuffer, y, x, color)
        } else {
            image_set(framebuffer, x, y, color)
        }
        error += dy
        if error * 2 >= dx {
            y += ystep
            error -= dx
        }
    }
}

random_u8 :: proc() -> u8 {
    return u8(rand.uint32() % 256)
}

main :: proc() {
    width, height := 64, 64
    framebuffer := image_init(width, height, TGAFormat.RGB, Black)

    seed := u64(time.to_unix_nanoseconds(time.now()))
    rand.reset(seed)
    for i in 0..<(1<<24) {
        ax := int(rand.uint32()) % framebuffer.width
        ay := int(rand.uint32()) % framebuffer.height
        bx := int(rand.uint32()) % framebuffer.width
        by := int(rand.uint32()) % framebuffer.height
        c := TGAColor{
            bgra = {random_u8(), random_u8(), random_u8(), 255},
            bytespp = 4,
        }
        line(ax, ay, bx, by, &framebuffer, c)
    }

    if !write_tga_file(framebuffer, "output.tga", true, true) {
        fmt.println("Failed to write tga file.")
    }
}




