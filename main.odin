package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:time"
import "core:os"

White := TGAColor {{255, 255, 255, 255}, 4}
Black := TGAColor {{0, 0, 0, 255}, 4}
Green := TGAColor {{  0, 255,   0, 255}, 4}
Red := TGAColor {{  0,   0, 255, 255}, 4}
Blue := TGAColor {{255, 128,  64, 255}, 4}
Yellow := TGAColor {{  0, 200, 255, 255}, 4}

//width, height := 256, 256
width, height := 1024, 1024

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

// Scanline rasterization
old_triangle :: proc(x0, y0, x1, y1, x2, y2: int, framebuffer: ^TGAImage, color: TGAColor) {
    // sort the vertices, a,b,c in ascending y order
    ax, ay, bx, by, cx, cy := x0, y0, x1, y1, x2, y2
    if ay > by { ax, bx = bx, ax; ay, by = by, ay }
    if ay > cy { ax, cx = cx, ax; ay, cy = cy, ay }
    if by > cy { bx, cx = cx, bx; by, cy = cy, by}
    total_height := cy - ay
    // if the bottom half is not degenerate
    if ay != by { 
        segment_height := by - ay
        // sweep the horizontal line from ay to by
        for y in ay..=by { 
            x1 := ax + ((cx - ax)*(y - ay)) / total_height
            x2 := ax + ((bx - ax)*(y - ay)) / segment_height
            // draw a horizontal line
            for x in math.min(x1,x2)..<math.max(x1,x2) do image_set(framebuffer, x, y, color)
        }
    }
    // if the upper half is not degenerate
    if by != cy { 
        segment_height := cy - by
        for y in by..=cy { 
            x1 := ax + ((cx - ax)*(y - ay)) / total_height
            x2 := bx + ((cx - bx)*(y - by)) / segment_height 
            for x in math.min(x1,x2)..<math.max(x1,x2) do image_set(framebuffer, x, y, color)
        }
    }
}

signed_triangle_area :: proc(ax, ay, bx, by, cx, cy: int) -> f64 {
    return 0.5 * f64((bx - ax) * (cy - ay) - (by - ay) * (cx - ax))
}

// Bounding box rasterization
triangle :: proc(ax, ay, az, bx, by, bz, cx, cy, cz: int, zbuffer: ^TGAImage, framebuffer: ^TGAImage, color: TGAColor) {
    bbminx := math.min(math.min(ax, bx), cx)
    bbminy := math.min(math.min(ay, by), cy)
    bbmaxx := math.max(math.max(ax, bx), cx)
    bbmaxy := math.max(math.max(ay, by), cy)
    total_area := signed_triangle_area(ax, ay, bx, by, cx, cy)
    // backface culling + discarding triangles that cover less than a pixel
    if (total_area<1) do return    

    for x in bbminx..=bbmaxx {
        for y in bbminy..=bbmaxy {
            alpha := signed_triangle_area(x, y, bx, by, cx, cy) / total_area
            beta := signed_triangle_area(x, y, cx, cy, ax, ay) / total_area
            gamma := signed_triangle_area(x, y, ax, ay, bx, by) / total_area
            // negative barycentric coordinate => the pixel is outside the triangle
            if alpha<0 || beta<0 || gamma<0 do continue
            z := u8(alpha * f64(az) + beta * f64(bz) + gamma * f64(cz))
            image_set(zbuffer, x, y, {{z, 0, 0, 0}, 4});
            image_set(framebuffer, x, y, color);
        } 
    }
}

project :: proc(v: Vec3) -> (int, int, int) {
    return int((v.x + 1.) * f64(width)/2), int((v.y + 1.) * f64(height)/2), int((v.z + 1.) * 255./2)
}

main :: proc() {
    args := os.args
    if len(args) != 2 {
        fmt.eprintf("Usage: %d obj/model.obj\n", args[0])
        return
    }

    model, ok := model_load(args[1]) 
    if !ok {
        fmt.println("Failed to load model.")
        return
    }

    framebuffer := image_init(width, height, TGAFormat.RGB, Black)
    zbuffer := image_init(width, height, TGAFormat.GrayScale, Black)

    seed := u64(time.to_unix_nanoseconds(time.now()))
    rand.reset(seed)

    for i in 0..<nfaces(model) {
        ax, ay, az := project(vert(model, i, 0))
        bx, by, bz := project(vert(model, i, 1))
        cx, cy, cz := project(vert(model, i, 2))
        rnd: TGAColor
        rnd.bytespp = 4
        for c in 0..<3 {
            rnd.bgra[c] = u8(rand.uint32() % 255)
            triangle(ax, ay, az, bx, by, bz, cx, cy, cz, &zbuffer, &framebuffer, rnd)
        }
    }
    if !write_tga_file(framebuffer, "framebuffer.tga", true, true) {
        fmt.println("Failed to write tga file.")
    }
    if !write_tga_file(zbuffer, "zbuffer.tga", true, true) {
        fmt.println("Failed to write tga file.")
    }

}

