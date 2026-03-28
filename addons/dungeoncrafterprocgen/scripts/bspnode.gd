extends Resource
class_name BspNode

var box: Rect2i
var left: BspNode = null
var right: BspNode = null
var vertex: Vertex = null

func _init(_box: Rect2i):
	box = _box