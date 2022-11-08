# Road Point Gizmo.
## Created largely while following:
## https://docs.godotengine.org/en/stable/tutorials/plugins/editor/spatial_gizmos.html
extends EditorSpatialGizmoPlugin

var _editor_plugin: EditorPlugin

# Either value, or null if not mid action (magnitude handle mid action).
var init_handle

func get_name():
	return "RoadPoint"


func _init(editor_plugin: EditorPlugin):
	_editor_plugin = editor_plugin
	create_material("main", Color(0,1,0))
	create_handle_material("handles")
	init_handle = null


func has_gizmo(spatial) -> bool:
	return spatial is RoadPoint


func redraw(gizmo) -> void:
	gizmo.clear()
	var point = gizmo.get_spatial_node() as RoadPoint
	var lines = PoolVector3Array()

	lines.push_back(Vector3(0, 1, 0))
	lines.push_back(Vector3(0, 1, 0))

	var handles = PoolVector3Array()
	handles.push_back(Vector3(0, 0, -point.prior_mag))
	handles.push_back(Vector3(0, 0, point.next_mag))
	gizmo.add_lines(lines, get_material("main", gizmo), false)
	gizmo.add_handles(handles, get_material("handles", gizmo))


func get_handle_name(gizmo: EditorSpatialGizmo, index: int) -> String:
	var point = gizmo.get_spatial_node() as RoadPoint
	if index == 0:
		return "RoadPoint %s backwards handle" % point.name
	else:
		return "RoadPoint %s forward handle" % point.name


func get_handle_value(gizmo: EditorSpatialGizmo, index: int) -> float:
	var point = gizmo.get_spatial_node() as RoadPoint
	if index == 0:
		return point.prior_mag
	else:
		return point.next_mag


# Function called when user drags the roadpoint in/out magnitude handle.
func set_handle(gizmo: EditorSpatialGizmo, index: int, camera: Camera, point: Vector2) -> void:
	# Calculate intersection between screen point clicked and a plane aligned to
    # the handle's vector. Then, calculate new handle magnitude.
	var roadpoint = gizmo.get_spatial_node() as RoadPoint
	var src = camera.project_ray_origin(point) # Camera initial position.
	var nrm = camera.project_ray_normal(point) # Normal camera is facing
	var old_mag_vector # Handle's old local position.
	
	if index == 0:
		old_mag_vector = Vector3(0, 0, -roadpoint.prior_mag)
	else:
		old_mag_vector = Vector3(0, 0, roadpoint.next_mag)
	
	var plane_vector : Vector3 = roadpoint.to_global(old_mag_vector)
	var camera_basis : Basis = camera.get_transform().basis
	var plane := Plane(plane_vector, plane_vector + camera_basis.x, plane_vector + camera_basis.y)
	var intersect = plane.intersects_ray(src, nrm)
	
	# Then isolate to just the magnitude of the z component.
	var new_mag = abs(roadpoint.to_local(intersect).z)	
	if init_handle == null:
		init_handle = new_mag
	if index == 0:
		roadpoint.prior_mag = new_mag
	else:
		roadpoint.next_mag = new_mag
	redraw(gizmo)


func commit_handle(gizmo: EditorSpatialGizmo, index: int, restore, cancel: bool = false) -> void:
	var point = gizmo.get_spatial_node() as RoadPoint
	var current_value = get_handle_value(gizmo, index)
	
	if (cancel):
		print("Cancel")
	else:
		if init_handle == null:
			init_handle = current_value
		
		var undo_redo = _editor_plugin.get_undo_redo()
		if index == 0:
			undo_redo.create_action("RoadPoint %s in handle" % point.name)
			undo_redo.add_do_property(point, "prior_mag", current_value)
			undo_redo.add_undo_property(point, "prior_mag", init_handle)
			print("This commit ", current_value, "-", init_handle)
		else:

			undo_redo.create_action("RoadPoint %s out handle" % point.name)
			undo_redo.add_do_property(point, "next_mag", current_value)
			undo_redo.add_undo_property(point, "next_mag", init_handle)

		# Either way, force gizmo redraw with do/undo (otherwise waits till hover)
		undo_redo.add_do_method(self, "redraw", gizmo)
		undo_redo.add_undo_method(self, "redraw", gizmo)
		
		undo_redo.commit_action()
		point._notification(Spatial.NOTIFICATION_TRANSFORM_CHANGED)
		init_handle = null
