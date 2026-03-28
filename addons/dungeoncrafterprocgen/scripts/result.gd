extends Resource
class_name Result

var graph: Graph
var root: BspNode

func _init(_graph: Graph, _root: BspNode):
	graph = _graph
	root = _root