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

image_get :: proc(img: TGAImage, x: int, y: int) -> TGAColor{
    ret := TGAColor {{0, 0, 0, 0}, u8(img.bpp)}
    base := (x+y*img.width)*img.bpp
    for i := img.bpp - 1; i >= 0; i -= 1 {
        ret.bgra[i] = img.data[base + i]
    } 
    return ret
}

image_destroy :: proc(image: ^TGAImage) {
    delete(image.data)
}

set_u16 :: proc(dst: ^[dynamic]u8, v: u16) {
    append(dst, u8(v & 0x00ff))
    append(dst, u8((v >> 8) & 0x00ff))
}

get_u16 :: proc(src: []u8, idx: int) -> u16 {
    return u16(src[idx]) | u16(src[idx + 1] << 8)
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
        if !unload_rle_data(img, &out) do return false 
    
    }
    append(&out, ..DEVELOPER_AREA_REF[:])
    append(&out, ..EXTENSION_AREA_REF[:])
    append(&out, ..FOOTER[:])
    
    if !os.write_entire_file(name, out[:]) do return false 
    return true

}

read_tga_file :: proc(filename: string) -> (img: TGAImage, ok: bool) {
    bytes, read_ok := os.read_entire_file(filename)
    if !read_ok {
        fmt.eprintln("can't open file:", filename)
        return {}, false
    }
    defer delete(bytes)

    if len(bytes) < 18 {
        fmt.eprintln("file too small")
        return {}, false
    }

    idlength := bytes[0]
    datatypecode := bytes[2]
    w := get_u16(bytes, 12)
    h := get_u16(bytes, 14)
    bpp := int(bytes[16]) >> 3
    imagedescriptor := bytes[17]

    if w <= 0 || h <= 0 || (bpp != 1 && bpp != 3 && bpp != 4) {
        fmt.eprintln("bad bpp (or width/height) value:", w, h, bpp)
        return {}, false
    }

    img.width = int(w)
    img.height = int(h)
    img.bpp = bpp
    nbytes := int(w * h) * bpp
    
    img.data = make([]u8, nbytes) 

    cursor := 18 + int(idlength)

    if datatypecode == 2 || datatypecode == 3 {
        if cursor + nbytes > len(bytes) {
            fmt.eprintln("file truncated (missing data)")
            delete(img.data)
            return {}, false
        }
        copy(img.data, bytes[cursor : cursor + nbytes])
        
    } else if datatypecode == 10 || datatypecode == 11 {
        if !load_rle_data(&img, bytes, &cursor) {
            fmt.eprintln("an error occurred while reading the RLE data")
            delete(img.data)
            return {}, false
        }
    } else {
        fmt.eprintf("unknown file format %d\n", datatypecode)
        delete(img.data)
        return {}, false
    }

    if (imagedescriptor & 0x20) == 0 {
        flip_vertically(&img) 
    }
    if (imagedescriptor & 0x10) != 0 {
        flip_horizontally(&img)
    }

    return img, true
}

load_rle_data :: proc(img: ^TGAImage, bytes: []u8, cursor: ^int) -> bool {
    npixels := img.width * img.height
    curpix := 0
    curbyte := 0
    bpp := img.bpp

    for curpix < npixels {
        if cursor^ >= len(bytes) do return false
        
        chunkheader := bytes[cursor^]
        cursor^ += 1

        if chunkheader < 128 {
            count := int(chunkheader) + 1
            for _ in 0..<count {
                if cursor^ + bpp > len(bytes) do return false
                if curbyte + bpp > len(img.data) do return false
                
                for i in 0..<bpp {
                    img.data[curbyte + i] = bytes[cursor^ + i]
                }
                cursor^ += bpp
                curbyte += bpp
                curpix += 1
            }
        } else {
            count := int(chunkheader) - 127
            if cursor^ + bpp > len(bytes) do return false
            
            pixel := bytes[cursor^ : cursor^ + bpp]
            cursor^ += bpp

            for _ in 0..<count {
                if curbyte + bpp > len(img.data) do return false
                
                for i in 0..<bpp {
                    img.data[curbyte + i] = pixel[i]
                }
                curbyte += bpp
                curpix += 1
            }
        }
    }
    return true
}



unload_rle_data :: proc(img: TGAImage, out: ^[dynamic]u8) -> bool {
    max_chunk_length := 128
    npixels := img.width * img.height
    curpix := 0
    for curpix < npixels {
        chunk_start := curpix*img.bpp
        curbyte := curpix*img.bpp
        run_length := 1
        raw := true
        for curpix+run_length < npixels && run_length < max_chunk_length {
            succ_eq := true
            for i in 0..<img.bpp {
                if img.data[curbyte + i] != img.data[curbyte + img.bpp + i] {
                    succ_eq = false
                    break
                }
            }
            curbyte += img.bpp
            if run_length == 1 {
                raw = !succ_eq
            }
            if raw && succ_eq {
                run_length -= 1
                break
            }
            if !raw && !succ_eq {
                break
            }

            run_length += 1
        }
        curpix += run_length
        header_byte := raw ? (run_length - 1) : (run_length + 127)
        append(out, u8(header_byte))
        write_len := raw ? int(run_length) * img.bpp : img.bpp
        append_elems(out, ..img.data[chunk_start : chunk_start + write_len])
    } 
    return true
}

flip_horizontally :: proc(img: ^TGAImage) {
    for i in 0..<img.width/2 {
        for j in 0..<img.height {
            for b in 0..<img.bpp {
                lidx := (i+j*img.width)*img.bpp+b
                ridx := (img.width-1-i+j*img.width)*img.bpp+b
                tmp := img.data[lidx] 
                img.data[lidx] = img.data[ridx]
                img.data[ridx] = tmp
            }
        }
    }
}

flip_vertically :: proc(img: ^TGAImage) {
    for i in 0..<img.width {
        for j in 0..<img.height/2 {
            for b in 0..<img.bpp {
                uidx := (i+j*img.width)*img.bpp+b
                didx := (i+(img.height-1-j)*img.width)*img.bpp+b
                tmp := img.data[uidx] 
                img.data[uidx] = img.data[didx]
                img.data[didx] = tmp
            }
        }
    }
}


