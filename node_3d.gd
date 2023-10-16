extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    #RenderingServer.viewport_set_debug_draw(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_DEBUG_DRAW_NORMAL_BUFFER)
    pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    $CameraHolder.rotation.y += delta*0.5
    $CSGDeform3D.rotation.y += delta
