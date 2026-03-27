package main

import "core:os"
import "core:mem"
import "core:slice"
import "core:fmt"

TGAHeader :: struct #packed {
    idlength: u8,
    colormaptype: u8,
    datatypecode: u8,
    colormaporigin: u16,
    colormaplength: u16,
    colormapdepth: u8,
    x_origin: u16,
    y_origin: u16,
    width: u16,
    height: u16,
    bitsperpixel: u8,
    imagedescriptor: u8,
}

TGAColor :: struct {
    bgra: [4]u8,
    bytespp: u8,    
}

TGAFormat :: enum {
    GrayScale = 1,
    RGB = 3,
    RGBA = 4,
}

TGAImage :: struct {
    width: int, 
    height: int,
    bpp: int,
    data: []u8,
}

image_init :: proc(x: int, y: int, bpp: TGAFormat, color: TGAColor) -> TGAImage {
    image := TGAImage {
        width = x, 
        height = y, 
        bpp = int(bpp), 
        data = make([]u8, x*y*int(bpp))
    }
    for j in 0..<y {
        for i in 0..<x {
            image_set(&image, i, j, color)
        }
    }
    return image
}

image_set :: proc(image: ^TGAImage, x: int, y: int, color: TGAColor) {
    if len(image.data) == 0 || x < 0 || y < 0 || x >= image.width || y >= image.height do return 
    index := (x+y*image.width)*image.bpp 
    for i in 0..<image.bpp {
        image.data[index+i] = color.bgra[i]
    }
}

image_destroy :: proc(image: ^TGAImage) {
    delete(image.data)
}

set_u16 :: proc(dst: ^[dynamic]u8, v: u16) {
    append(dst, u8(v & 0x00ff))
    append(dst, u8((v >> 8) & 0x00ff))
}

write_tga_file :: proc(img: TGAImage, name: string, vflip: bool, rle: bool) -> bool {
    DEVELOPER_AREA_REF := [4]u8{0, 0, 0, 0}
    EXTENSION_AREA_REF := [4]u8{0, 0, 0, 0}
    FOOTER := [18]u8{'T','R','U','E','V','I','S','I','O','N','-','X','F','I','L','E','.','\x00'} 
    fd, err := os.open(name, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, 0o644)
    if err != os.ERROR_NONE {
        fmt.eprintf("can't open file %s\n", name)
        return false
    }
    defer os.close(fd)

    datatypecode: u8 = 0
    is_grayscale := img.bpp == 1
    if is_grayscale {
        datatypecode = rle ? 11 : 3
    } else {
        datatypecode = rle ? 10 : 2
    }

    imagedescriptor: u8 = vflip ? 0x00 : 0x20

    out := make([dynamic]u8, 0)
    append(&out, 0) // idlength
    append(&out, 0) // colormaptype
    append(&out, datatypecode) // datatypecode
    set_u16(&out, 0) // colormaporigin
    set_u16(&out, 0) // colormaplength
    append(&out, 0) // colormapdepth
    set_u16(&out, 0) // x_origin
    set_u16(&out, 0) // y_origin 
    set_u16(&out, u16(img.width)) // width
    set_u16(&out, u16(img.height)) // height
    append(&out, u8(img.bpp) << 3) // bitsperpixel
    append(&out, imagedescriptor) // imagedescriptor

    if !rle {
        append(&out, ..img.data[:])
    } else {
        if !unload_rle_data(fd, img) do return false 
    
    }
    append(&out, ..DEVELOPER_AREA_REF[:])
    append(&out, ..EXTENSION_AREA_REF[:])
    append(&out, ..FOOTER[:])
    
    if !os.write_entire_file(name, out[:]) do return false 
    return true

}


unload_rle_data :: proc(fd: os.Handle, img: TGAImage) -> bool {
}


