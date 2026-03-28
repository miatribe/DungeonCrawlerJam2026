@tool
extends Resource
class_name TileTexture

@export var texture: Texture2D
@export_range(0.0, 100.0, 0.1) var chance_percent: float = 100.0
