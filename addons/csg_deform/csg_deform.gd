@tool
@icon("icon.png")
extends CSGShape3D
class_name CSGDeform3D

# TODO:
# - support changing the lattice resolution without throwing out the lattice

@export var lattice := PackedVector3Array() :
    set(value):
        lattice = value
        dirty = true
@export var lattice_size := Vector3(2, 2, 2) :
    set(value):
        lattice_size = value
        dirty = true
@export var lattice_res := Vector3i(9, 9, 9) :
    set(value):
        lattice_res = value.clamp(Vector3i.ONE, Vector3i.ONE * 64)
        dirty = true

@export var fix_normals := true :
    set(value):
        fix_normals = value
        dirty = true
@export var smooth := false :
    set(value):
        smooth = value
        dirty = true

func lattice_get_fast(coord : Vector3) -> Vector3:
    var res := lattice_res
    var resm1 := lattice_res-Vector3i.ONE
    coord = (coord/lattice_size + Vector3(0.5, 0.5, 0.5)) * Vector3(resm1)
    var cf := coord.floor()
    var a := Vector3i(cf).clamp(Vector3i(), resm1) * Vector3i(1, res.x, res.x*res.y)
    var b := Vector3i(cf + Vector3.ONE).clamp(Vector3i(), resm1) * Vector3i(1, res.x, res.x*res.y)
    var t := (coord - cf).clamp(Vector3(), Vector3.ONE)
    
    var aaa = lattice[a.z + a.y + a.x]
    var baa = lattice[a.z + a.y + b.x]
    var aba = lattice[a.z + b.y + a.x]
    var bba = lattice[a.z + b.y + b.x]
    var aab = lattice[b.z + a.y + a.x]
    var bab = lattice[b.z + a.y + b.x]
    var abb = lattice[b.z + b.y + a.x]
    var bbb = lattice[b.z + b.y + b.x]
    
    var _aa = aaa.lerp(baa, t.x)
    var _ba = aba.lerp(bba, t.x)
    var _ab = aab.lerp(bab, t.x)
    var _bb = abb.lerp(bbb, t.x)
    
    var __a = _aa.lerp(_ba, t.y)
    var __b = _ab.lerp(_bb, t.y)

    return __a.lerp(__b, t.z)

func lattice_get_smooth(coord : Vector3) -> Vector3:
    var resm1 := lattice_res-Vector3i.ONE
    coord = (coord/lattice_size + Vector3(0.5, 0.5, 0.5)) * Vector3(resm1)
    var cf := coord.floor()
    var a := Vector3i(cf).clamp(Vector3i(), resm1)
    var b := Vector3i(cf + Vector3.ONE).clamp(Vector3i(), resm1)
    var t := (coord - Vector3(a)).clamp(Vector3(), Vector3.ONE)

    return lattice_get_i_interp_3d(a, b, t)

func lattice_get_weights(coord : Vector3, amount : float, weights : Dictionary, counts : Dictionary):
    var resm1 := lattice_res-Vector3i.ONE
    coord = (coord/lattice_size) * Vector3(resm1) + Vector3(resm1)*0.5
    var cf := coord.floor()
    var a := Vector3i(cf).clamp(Vector3i(), resm1)
    var b := Vector3i(cf + Vector3.ONE).clamp(Vector3i(), resm1)
    var t := (coord - Vector3(a)).clamp(Vector3(), Vector3.ONE)
    
    for z in range(a.z, b.z+1):
        # t.z=0.0 : a -> 1.0, b -> 0.0
        # t.z=0.5 : a -> 0.5, b -> 0.5
        # t.z=1.0 : a -> 0.0, b -> 1.0
        var w_z = lerp(a.z-z+1, z-a.z, t.z)
        for y in range(a.y, b.y+1):
            var w_y = lerp(a.y-y+1, y-a.y, t.y) * w_z
            for x in range(a.x, b.x+1):
                var w = lerp(a.x-x+1, x-a.x, t.x) * w_y
                var vec := Vector3i(x, y, z)
                if not vec in weights:
                    weights[vec] = 0.0
                    counts[vec] = 0
                #weights[vec] = max(weights[vec], w * amount)
                #counts[vec] = 1
                weights[vec] += w * amount
                counts[vec] += 1

func lattice_get_i_interp_1d(c1 : Vector3i, c2 : Vector3i, t : float) -> Vector3:
    var res := lattice_res
    var a := lattice[c1.z*res.x*res.y + c1.y*res.x + c1.x]
    var b := lattice[c2.z*res.x*res.y + c2.y*res.x + c2.x]
    var d = c2-c1
    var c0 = (c1 - d).clamp(Vector3i(), res-Vector3i.ONE)
    var c3 = (c2 + d).clamp(Vector3i(), res-Vector3i.ONE)
    var pre  := lattice[c0.z*res.x*res.y + c0.y*res.x + c0.x]
    var post := lattice[c3.z*res.x*res.y + c3.y*res.x + c3.x]
    return a.cubic_interpolate(b, pre, post, t)

func lattice_get_i_interp_2d(c1 : Vector3i, c2 : Vector3i, tx : float, ty : float) -> Vector3:
    var res := lattice_res
    var dy := (c2-c1) * Vector3i(0, 1, 0)
    var a := lattice_get_i_interp_1d(c1, c2 - dy, tx)
    var b := lattice_get_i_interp_1d(c1 + dy, c2, tx)
    var c0_a = (c1 - dy     ).clamp(Vector3i(), res-Vector3i.ONE)
    var c0_b = (c2 - dy - dy).clamp(Vector3i(), res-Vector3i.ONE)
    var c1_a = (c1 + dy + dy).clamp(Vector3i(), res-Vector3i.ONE)
    var c1_b = (c2 + dy     ).clamp(Vector3i(), res-Vector3i.ONE)
    var pre  := lattice_get_i_interp_1d(c0_a, c0_b, tx)
    var post := lattice_get_i_interp_1d(c1_a, c1_b, tx)
    return a.cubic_interpolate(b, pre, post, ty)

func lattice_get_i_interp_3d(c1 : Vector3i, c2 : Vector3i, tv : Vector3) -> Vector3:
    var res := lattice_res
    var dz := (c2-c1) * Vector3i(0, 0, 1)
    var a := lattice_get_i_interp_2d(c1, c2 - dz, tv.x, tv.y)
    var b := lattice_get_i_interp_2d(c1 + dz, c2, tv.x, tv.y)
    var c0_a = (c1 - dz     ).clamp(Vector3i(), res-Vector3i.ONE)
    var c0_b = (c2 - dz - dz).clamp(Vector3i(), res-Vector3i.ONE)
    var c1_a = (c1 + dz + dz).clamp(Vector3i(), res-Vector3i.ONE)
    var c1_b = (c2 + dz     ).clamp(Vector3i(), res-Vector3i.ONE)
    var pre  := lattice_get_i_interp_2d(c0_a, c0_b, tv.x, tv.y)
    var post := lattice_get_i_interp_2d(c1_a, c1_b, tv.x, tv.y)
    return a.cubic_interpolate(b, pre, post, tv.z)

func build_lattice():
    lattice = []
    lattice.resize(lattice_res.x * lattice_res.y * lattice_res.z)
    for i in lattice.size():
        lattice[i] = Vector3()

var start_lattice : PackedVector3Array
func begin_operation():
    start_lattice = lattice.duplicate()

func end_operation():
    start_lattice.resize(0)

func affect_lattice(where : Vector3, radius : float, normal : Vector3, delta : float, mode : String):
    var mesh : ArrayMesh = get_meshes()[1]
    var hit_lattice_weights := {}
    var hit_lattice_counts := {}
    
    var closest_id = -1
    var closest_i = -1
    var closest_dist = 10000000000.0
    
    for id in mesh.get_surface_count():
        var arrays := mesh.surface_get_arrays(id)
        var verts = arrays[ArrayMesh.ARRAY_VERTEX]
        
        var original_arrays := original_mesh.surface_get_arrays(id)
        var original_verts = original_arrays[ArrayMesh.ARRAY_VERTEX]
        
        for i in verts.size():
            var vert := verts[i] as Vector3
            var diff := (vert - where) / radius
            var dist := diff.length_squared()
            if dist < closest_dist:
                closest_dist = dist
                closest_id = id
                closest_i = i
            var l := 1.0 - dist
            l = max(0, l)
            l *= l
            if l > 0.0:
                var original_vert := original_verts[i] as Vector3
                lattice_get_weights(original_vert, l, hit_lattice_weights, hit_lattice_counts)
    
    # ensure the minimum weight is at least 1.0
    var max_weight = 0.0
    for coord in hit_lattice_weights:
        max_weight = max(max_weight, (hit_lattice_weights[coord] / hit_lattice_counts[coord]))
    if max_weight > 0.0:
        max_weight = 1.0 / min(max_weight, 1.0)
    else:
        if closest_i >= 0:
            var original_arrays := original_mesh.surface_get_arrays(closest_id)
            var original_verts = original_arrays[ArrayMesh.ARRAY_VERTEX]
            lattice_get_weights(original_verts[closest_i], 1.0, hit_lattice_weights, hit_lattice_counts)
        
        max_weight = 1.0
    
    var res := lattice_res
    
    var avg_deform = Vector3()
    var avg_deform_weight = 0.0
    for coord in hit_lattice_weights:
        hit_lattice_weights[coord] *= max_weight
        if mode == "Smooth" or mode == "Relax" or mode == "Average":
            var weight = hit_lattice_weights[coord]
            avg_deform_weight += weight
            var index : int = coord.z*res.x*res.y + coord.y*res.x + coord.x
            avg_deform += lattice[index] * weight
    
    if avg_deform_weight > 0.0:
        avg_deform /= avg_deform_weight
    
    for coord in hit_lattice_weights:
        var weight : float = hit_lattice_weights[coord] / hit_lattice_counts[coord] 
        var index : int = coord.z*res.x*res.y + coord.y*res.x + coord.x
        if mode == "Grow":
            lattice[index] += normal * weight * delta
        elif mode == "Erase":
            #var erased = lattice[index] * pow(0.5, abs(delta) * weight * 10.0)
            var erased = lattice[index].lerp(Vector3(), 1.0 - pow(0.5, abs(delta) * weight * 10.0))
            if delta > 0.0:
                lattice[index] = erased
            else:
                lattice[index] = lerp(lattice[index], erased, -1.0)
        elif mode == "Smooth" or mode == "Relax" or mode == "Average":
            var smoothed = lattice[index].lerp(avg_deform, 1.0 - pow(0.5, abs(delta) * weight * 10.0))
            var diff = smoothed - lattice[index]
            if mode == "Smooth":
                diff = diff.project(normal)
            elif mode == "Relax":
                diff = diff.slide(normal)
            if delta > 0.0:
                lattice[index] += diff
            else:
                lattice[index] -= diff
    
    dirty = true


var dummy_space : RID = PhysicsServer3D.space_create()
var dummy_body : RID = PhysicsServer3D.body_create()

func _init():
    dummy_space = PhysicsServer3D.space_create()
    dummy_body = PhysicsServer3D.body_create()
    PhysicsServer3D.body_set_space(dummy_body, dummy_space)
    build_lattice()

func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        PhysicsServer3D.free_rid(dummy_body)
        PhysicsServer3D.free_rid(dummy_space)

func translate_coord(coord : Vector3, force_fast := false) -> Vector3:
    if smooth and !force_fast:
        return coord + lattice_get_smooth(coord)
    else:
        return coord + lattice_get_fast(coord)

func get_normal_at_coord(c : Vector3, n : Vector3) -> Vector3:
    var y := n.cross(Vector3(n.y, n.z, -n.x))
    var x := n.cross(y)
    var s := lattice_size/Vector3(lattice_res)/2.0# * (0.5 if smooth else 1.0)
    var s2 := s * 2.0
    var tan := (translate_coord(c + x * s, true) - translate_coord(c - x * s, true))
    var bitan := (translate_coord(c + y * s, true) - translate_coord(c - y * s, true))
    return -tan.cross(bitan).normalized()

func _validate_property():
    pass

var used_mesh : ArrayMesh = null
var original_mesh : ArrayMesh = null
var dirty = false

var timer = 0.0

func randomize_lattice():
    var s = 0.1
    for i in lattice.size():
        seed(hash(i) + Time.get_ticks_usec())
        lattice[i] = Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s))
    dirty = true

#var mapping := {}

var collision : Shape3D = null

func _process(delta : float) -> void:
    var capacity = lattice_res.x * lattice_res.y * lattice_res.z
    if lattice.size() != capacity:
        build_lattice()
        dirty = true
    
    var mesh : ArrayMesh = get_meshes()[1]
    if used_mesh != mesh:
        used_mesh = mesh
        original_mesh = mesh.duplicate()
        dirty = true
    
    #timer += delta
    if timer > 2.0:
        timer = 0.0
        randomize_lattice()
    
    if dirty:
        dirty = false
        var new_surfaces = []
        var seen_coords = {} # meshes contain duplicated verts on smooth surfaces, so we cache them
        for id in original_mesh.get_surface_count():
            var type := original_mesh.surface_get_primitive_type(id)
            var arrays := original_mesh.surface_get_arrays(id)
            var blend := original_mesh.surface_get_blend_shape_arrays(id)
            var mat := original_mesh.surface_get_material(id)
            var verts : PackedVector3Array = arrays[ArrayMesh.ARRAY_VERTEX]
            var normals : PackedVector3Array = arrays[ArrayMesh.ARRAY_NORMAL]
            for i in verts.size():
                var old_vert := verts[i]
                var old_normal := normals[i]
                var key = [old_vert, old_normal]
                if key in seen_coords:
                    normals[i] = normals[seen_coords[key]]
                    verts[i] = verts[seen_coords[key]]
                else:
                    var new_vert := translate_coord(verts[i])
                    if fix_normals:
                        normals[i] = get_normal_at_coord(old_vert, normals[i])
                    verts[i] = new_vert
                    seen_coords[key] = i
            new_surfaces.push_back([type, arrays, blend, mat])
        
        mesh.clear_surfaces()
        for info in new_surfaces:
            mesh.add_surface_from_arrays(info[0], info[1], info[2])
            mesh.surface_set_material(mesh.get_surface_count()-1, info[3])
        
        collision = mesh.create_trimesh_shape()
        PhysicsServer3D.body_clear_shapes(dummy_body)
        PhysicsServer3D.body_add_shape(dummy_body, collision.get_rid())
        
        # force broadphase update
        PhysicsServer3D.body_set_space(dummy_body, get_tree().root.find_world_3d().space)
        PhysicsServer3D.body_set_space(dummy_body, dummy_space)
    
    force_update_transform()
    var state := PhysicsServer3D.body_get_direct_state(dummy_body)
    state.transform = global_transform
