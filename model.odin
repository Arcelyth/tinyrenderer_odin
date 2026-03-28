package main

import "core:os"
import "core:strings"
import "core:strconv"
import "core:fmt"

Model :: struct {
    verts:     [dynamic]Vec3,
    facet_vrt: [dynamic]int,
}

nverts :: proc(m: Model) -> int {
    return len(m.verts)
}

nfaces :: proc(m: Model) -> int {
    return len(m.facet_vrt) / 3
}

get_vert :: proc(m: Model, i: int) -> Vec3 {
    return m.verts[i]
}

get_face_vert :: proc(m: Model, iface, nthvert: int) -> Vec3 {
    return m.verts[m.facet_vrt[iface * 3 + nthvert]]
}

vert :: proc {
    get_vert,
    get_face_vert
}

model_load :: proc(filename: string) -> (m: Model, ok: bool) {
    data, read_ok := os.read_entire_file(filename)
    if !read_ok do return {}, false
    defer delete(data)

    m.verts = make([dynamic]Vec3)
    m.facet_vrt = make([dynamic]int)

    content := string(data)
    for line in strings.split_lines_iterator(&content) {
        if len(line) < 2 do continue

        if strings.has_prefix(line, "v ") {
            fields := strings.fields(line[2:])
            if len(fields) >= 3 {
                v: Vec3
                v[0], _ = strconv.parse_f64(fields[0])
                v[1], _ = strconv.parse_f64(fields[1])
                v[2], _ = strconv.parse_f64(fields[2])
                append(&m.verts, v)
            }
        } else if strings.has_prefix(line, "f ") {
            fields := strings.fields(line[2:])
            cnt := 0
            for field in fields {
                parts := strings.split(field, "/")
                defer delete(parts)
                
                idx, parse_ok := strconv.parse_int(parts[0])
                if parse_ok {
                    append(&m.facet_vrt, idx - 1)
                    cnt += 1
                }
            }
            if cnt != 3 {
                fmt.eprintln("Error: the obj file is supposed to be triangulated")
            }
        }
    }

    fmt.printf("# v# %d f# %d\n", len(m.verts), len(m.facet_vrt)/3)
    return m, true
}

model_destroy :: proc(m: ^Model) {
    delete(m.verts)
    delete(m.facet_vrt)
}
