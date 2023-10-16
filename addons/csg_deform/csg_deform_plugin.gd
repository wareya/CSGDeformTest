@tool
extends EditorPlugin

#const Editor = preload("res://addons/csg_deform/csg_deform_gizmo.gd")
#var editor = Editor.new()

const radius = 0.25

func make_radius_mesh() -> Mesh:
    var mat := StandardMaterial3D.new()
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color = Color(0.0, 0.25, 1.0, 0.35)
    mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
    mat.roughness = 0.5
    var mesh := SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = mesh.radius * 2.0
    mesh.material = mat
    return mesh

func make_grid_verts(subdivs : Vector3i) -> Array:
    gridmesh_size = subdivs
    subdivs -= Vector3i.ONE
    var m := Vector3(subdivs).clamp(Vector3(), Vector3.ONE)
    var verts := PackedVector3Array()
    for _info in [Vector3i(0, 1, 2), Vector3i(1, 2, 0), Vector3i(2, 0, 1)]:
        var info : Vector3 = _info
        var zi = info.max_axis_index()
        var xi = (zi+1)%3
        var yi = (xi+1)%3
        for _z in range(-subdivs[zi], subdivs[zi]+1, 2):
            var z = float(_z)/subdivs[zi]
            for y in range(-1, 2, 2):
                for x in range(-1, 2, 2):
                    var vec = Vector3()
                    vec[xi] = x
                    vec[yi] = y
                    vec[zi] = z
                    verts.push_back(vec * m)
            for x in range(-1, 2, 2):
                for y in range(-1, 2, 2):
                    var vec = Vector3()
                    vec[xi] = x
                    vec[yi] = y
                    vec[zi] = z
                    verts.push_back(vec * m)
    
    var arrays = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    return arrays

var gridmesh_size := Vector3i()
func make_grid_mesh(subdivs : Vector3i) -> Mesh:
    var mat := StandardMaterial3D.new()
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(0.5, 0.75, 1.0, 0.1)
    var mesh := ArrayMesh.new()
    var arrays := make_grid_verts(subdivs)
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
    mesh.surface_set_material(0, mat)
    return mesh

var gridmesh : ArrayMesh = null
var gridmesh_inst : RID = RID()
var mesh : Mesh = null
var mesh_inst : RID = RID()

func _enter_tree():
    set_input_event_forwarding_always_enabled()
    mesh = make_radius_mesh()
    mesh_inst = RenderingServer.instance_create2(mesh.get_rid(), get_tree().root.find_world_3d().scenario)
    
    gridmesh = make_grid_mesh(Vector3i(16, 16, 16))
    gridmesh_inst = RenderingServer.instance_create2(gridmesh.get_rid(), get_tree().root.find_world_3d().scenario)
    
    add_custom_type("CSGDeform3D", "CSGShape3D", preload("res://addons/csg_deform/csg_deform.gd"), preload("res://addons/csg_deform/icon.png"))

func _exit_tree():
    mesh = null
    RenderingServer.free_rid(mesh_inst)
    remove_custom_type("CSGDeform3D")

var edit_node : CSGDeform3D = null
func edit(node : CSGDeform3D) -> void:
    edit_node = node

#func _forward_3d_draw_over_viewport(viewport_control: Control) -> void:
    # Draw a circle at cursor position.
    #viewport_control.draw_circle(viewport_control.get_local_mouse_position(), 64, Color.RED)
    #pass

var input_position = null
var input_normal = null
var input_m1 = false
var input_m2 = false

func update_raycast():
    var start := camera.project_ray_origin(mouse_pos)
    var end := start + camera.project_ray_normal(mouse_pos) * camera.far
    var space := PhysicsServer3D.space_get_direct_state(edit_node.dummy_space)
    var info := space.intersect_ray(PhysicsRayQueryParameters3D.create(start, end))
    if info.size() > 0:
        RenderingServer.instance_set_visible(mesh_inst, true)
        RenderingServer.instance_set_transform(mesh_inst, Transform3D(Basis(), info.position))
        input_position = info.position
        input_normal = info.normal
    else:
        RenderingServer.instance_set_visible(mesh_inst, false)
        input_position = null
        input_normal = null

var camera : Camera3D = null
var mouse_pos := Vector2()
func _forward_3d_gui_input(viewport_camera : Camera3D, event : InputEvent) -> int:
    camera = viewport_camera
    if edit_node:
        if event is InputEventMouseMotion:
            mouse_pos = event.position
            update_raycast()
            return EditorPlugin.AFTER_GUI_INPUT_PASS
        elif event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
            if event.button_index == MOUSE_BUTTON_LEFT:
                input_m1 = event.pressed
            if event.button_index == MOUSE_BUTTON_RIGHT:
                input_m2 = event.pressed
            return EditorPlugin.AFTER_GUI_INPUT_STOP
    else:
        input_position = null
        input_normal = null
        input_m1 = false
        input_m2 = false
    return EditorPlugin.AFTER_GUI_INPUT_PASS

func _process(delta : float) -> void:
    mesh.radius = radius
    mesh.height = radius*2.0
    
    if edit_node and !is_instance_valid(edit_node):
        edit_node = null
    
    if gridmesh_inst and edit_node:
        if gridmesh_size != edit_node.lattice_res:
            var mesh := ArrayMesh.new()
            var arrays := make_grid_verts(edit_node.lattice_res)
            var mat := gridmesh.surface_get_material(0)
            gridmesh.clear_surfaces()
            gridmesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
            gridmesh.surface_set_material(0, mat)
        
        RenderingServer.instance_set_visible(gridmesh_inst, true)
        RenderingServer.instance_set_transform(gridmesh_inst, edit_node.global_transform.scaled_local(edit_node.lattice_size/2.0))
    else:
        RenderingServer.instance_set_visible(gridmesh_inst, false)
    
    if edit_node:
        if input_m1 or input_m2:
            update_raycast()
        if input_position != null:
            if input_m1:
                var start = Time.get_ticks_usec()
                if Input.is_key_pressed(KEY_SHIFT): 
                    edit_node.affect_lattice(input_position, radius, input_normal, delta, 0.0, 0.5)
                else:
                    edit_node.affect_lattice(input_position, radius, input_normal, delta, 1.0, 1.0)
                var end = Time.get_ticks_usec()
                print("deform time: ", (end-start)/1000000.0)
            elif input_m2:
                edit_node.affect_lattice(input_position, radius, -input_normal, delta, 1.0, 1.0)
        else:
            RenderingServer.instance_set_visible(mesh_inst, false)
    else:
        RenderingServer.instance_set_visible(mesh_inst, false)

func _edit(object : Object) -> void:
    if object is CSGDeform3D:
        edit(object)
    else:
        edit_node = null

func _handles(object : Object) -> bool:
    return object is CSGDeform3D
