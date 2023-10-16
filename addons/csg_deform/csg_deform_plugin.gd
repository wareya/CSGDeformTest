@tool
extends EditorPlugin

var radius = 0.25

var gridmesh : ArrayMesh = null
var gridmesh_inst : RID = RID()
var mesh : Mesh = null
var mesh_inst : RID = RID()

var input_position = null
var input_normal = null
var input_m1 = false
var input_m2 = false

class CSGDeformControls extends HBoxContainer:
    var radius : Range = null
    var strength : Range = null
    var mode : OptionButton = null
    var direction : OptionButton = null
    var local_normal : CheckButton = null
    var edit_enabled : CheckButton = null
    var panel : PopupPanel = null
    var menu_button : Button = null
    
    func button_toggled(button_pressed : bool) -> void:
        if button_pressed:
            var r := menu_button.get_global_rect()
            r.position.y += r.size.y
            r.size.x = 0
            panel.popup_on_parent(r)
        else:
            panel.hide()
    
    func _init():
        menu_button = Button.new()
        menu_button.action_mode = Button.ACTION_MODE_BUTTON_PRESS
        menu_button.flat = true
        menu_button.toggle_mode = true
        menu_button.text = "Deform Options"
        menu_button.toggled.connect(self.button_toggled)
        
        edit_enabled = CheckButton.new()
        edit_enabled.text = "Do Deform"
        edit_enabled.button_pressed = true
        add_child(edit_enabled)
        
        var list := VBoxContainer.new()
        
        anchor_left = 0
        anchor_right = 0
        anchor_top = 0
        anchor_bottom = 0
        offset_left = 12
        offset_top = 48
        name = "CSGDeformControls"
        
        mode = OptionButton.new()
        mode.add_item("Grow")
        mode.add_item("Erase")
        mode.add_item("Smooth")
        mode.add_item("Relax")
        mode.add_item("Average")
        #mode.add_item("Drag") # TODO
        mode.flat = true
        add_child(mode)
        
        radius = EditorSpinSlider.new()
        radius.rounded = false
        radius.step = 0.01
        radius.min_value = 0.01
        radius.max_value = 8.0
        radius.value = 0.25
        radius.exp_edit = true
        #radius.flat = true
        radius.custom_minimum_size.x = 104
        radius.label = "Radius"
        add_child(radius)
        
        strength = EditorSpinSlider.new()
        strength.rounded = false
        strength.step = 0.05
        strength.min_value = 0.05
        strength.max_value = 20.0
        strength.value = 1.0
        strength.exp_edit = true
        #strength.flat = true
        strength.custom_minimum_size.x = 104
        strength.label = "Strength"
        add_child(strength)
        
        var label := Label.new()
        label.text = "Direction:"
        list.add_child(label)
        
        direction = OptionButton.new()
        direction.add_item("Face")
        direction.add_item("Camera")
        direction.add_item("Up")
        direction.add_item("Down")
        direction.add_item("X+")
        direction.add_item("X-")
        direction.add_item("Z+")
        direction.add_item("Z-")
        direction.flat = true
        list.add_child(direction)
        
        local_normal = CheckButton.new()
        local_normal.text = "Apply Locally"
        list.add_child(local_normal)
        
        panel = PopupPanel.new()
        panel.add_child(list)
        add_child(panel)
        add_child(menu_button)
        
    
var main_screen : Node = null
var viewport_container : Node = null
var controls : CSGDeformControls = null

func set_up_controls():
    controls = CSGDeformControls.new()
    #main_screen = get_editor_interface().get_editor_main_screen()
    #viewport_container = main_screen.get_child(1).get_child(1).get_child(0).get_child(0).get_child(0)
    #viewport_container.get_child(0).add_child(controls)
    add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, controls)

func clean_up_controls():
    #main_screen = null
    #viewport_container = null
    remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, controls)
    controls.queue_free()

func _enter_tree():
    set_up_controls()
    
    set_input_event_forwarding_always_enabled()
    
    mesh = make_radius_mesh()
    mesh_inst = RenderingServer.instance_create2(mesh.get_rid(), get_tree().root.find_world_3d().scenario)
    
    gridmesh = make_grid_mesh(Vector3i(16, 16, 16)) # placeholder grid size, will be replaced in process
    gridmesh_inst = RenderingServer.instance_create2(gridmesh.get_rid(), get_tree().root.find_world_3d().scenario)
    
    add_custom_type("CSGDeform3D", "CSGShape3D", preload("res://addons/csg_deform/csg_deform.gd"), preload("res://addons/csg_deform/icon.png"))

func _exit_tree():
    mesh = null
    RenderingServer.free_rid(mesh_inst)
    gridmesh = null
    RenderingServer.free_rid(gridmesh_inst)
    clean_up_controls()
    remove_custom_type("CSGDeform3D")

var camera : Camera3D = null
var mouse_pos := Vector2()
var have_affected_lattice := false
func _forward_3d_gui_input(viewport_camera : Camera3D, event : InputEvent) -> int:
    if !controls.edit_enabled.button_pressed:
        return EditorPlugin.AFTER_GUI_INPUT_PASS
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
            if event.pressed:
                edit_node.begin_operation()
                have_affected_lattice = false
            else:
                var diff := edit_node.get_lattice_diff()
                if have_affected_lattice:
                    var uncompressed := var_to_bytes(diff)
                    var compressed := uncompressed.compress(FileAccess.COMPRESSION_GZIP)
                    var undo_redo := get_undo_redo()
                    undo_redo.create_action("CSGDeform Lattice Edit")
                    undo_redo.add_do_method(edit_node, "add_compressed_lattice", compressed, 1.0)
                    undo_redo.add_undo_method(edit_node, "add_compressed_lattice", compressed, -1.0)
                    undo_redo.commit_action(false)
                
                edit_node.end_operation()
                have_affected_lattice = false
            
            return EditorPlugin.AFTER_GUI_INPUT_STOP
    else:
        input_position = null
        input_normal = null
        input_m1 = false
        input_m2 = false
    return EditorPlugin.AFTER_GUI_INPUT_PASS

func _process(delta : float) -> void:
    radius = controls.radius.value
    
    mesh.radius = radius
    mesh.height = radius*2.0
    
    if edit_node and !is_instance_valid(edit_node):
        edit_node = null
    
    if gridmesh_inst and edit_node:
        if gridmesh_size != edit_node.lattice_res:
            var mesh := ArrayMesh.new()
            var arrays := make_grid_arrays(edit_node.lattice_res)
            var mat := gridmesh.surface_get_material(0)
            gridmesh.clear_surfaces()
            gridmesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
            gridmesh.surface_set_material(0, mat)
        
        RenderingServer.instance_set_visible(gridmesh_inst, true)
        RenderingServer.instance_set_transform(gridmesh_inst, edit_node.global_transform.scaled_local(edit_node.lattice_size/2.0))
    else:
        RenderingServer.instance_set_visible(gridmesh_inst, false)
    
    if edit_node:
        controls.visible = true
        if input_m1 or input_m2:
            update_raycast()
        if input_position != null:
            var mode_name = controls.mode.get_item_text(controls.mode.selected)
            var dir_name = controls.direction.get_item_text(controls.direction.selected)
            var position = input_position
            var normal = input_normal
            if dir_name == "Camera":
                normal = (camera.global_transform * Vector3.FORWARD).normalized()
            elif dir_name == "Up":
                normal = Vector3.UP
            elif dir_name == "Down":
                normal = Vector3.DOWN
            elif dir_name == "X+":
                normal = Vector3(1, 0, 0)
            elif dir_name == "X-":
                normal = Vector3(-1, 0, 0)
            elif dir_name == "Z+":
                normal = Vector3(0, 0, 1)
            elif dir_name == "Z-":
                normal = Vector3(0, 0, -1)
            
            position = edit_node.global_transform.affine_inverse() * position
            
            if !controls.local_normal.button_pressed or dir_name == "Camera" or dir_name == "Face":
                normal = (edit_node.global_transform.basis.inverse() * normal).normalized()
            
            var strength = controls.strength.value * delta
            if input_m1 and !Input.is_key_pressed(KEY_SHIFT):
                edit_node.affect_lattice(position, radius, normal,  strength, mode_name)
                have_affected_lattice = true
            elif input_m2 or input_m1:
                edit_node.affect_lattice(position, radius, normal, -strength, mode_name)
                have_affected_lattice = true
        else:
            RenderingServer.instance_set_visible(mesh_inst, false)
    else:
        controls.visible = false
        RenderingServer.instance_set_visible(mesh_inst, false)

var edit_node : CSGDeform3D = null
func _edit(object : Object) -> void:
    if object is CSGDeform3D:
        edit_node = object
    else:
        edit_node = null

func _handles(object : Object) -> bool:
    return object is CSGDeform3D

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

func make_grid_arrays(subdivs : Vector3i) -> Array:
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
    var arrays := make_grid_arrays(subdivs)
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
    mesh.surface_set_material(0, mat)
    return mesh
