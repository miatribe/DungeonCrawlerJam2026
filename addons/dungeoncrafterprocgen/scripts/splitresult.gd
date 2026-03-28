extends Resource
class_name SplitResult

var left: BspNode = null
var right: BspNode = null

func _init(_left: BspNode, _right: BspNode):
    left = _left
    right = _right