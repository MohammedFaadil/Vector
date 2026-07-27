class_name Pieces
extends RefCounted
## Static factories for every physical thing the generator spawns.
## All visuals are silhouettes drawn in code — zero texture VRAM.
## Physics layers: 1 world · 2 player · 4 hazard · 8 collectible · 16 wall · 32 vaultable

const SILHOUETTE := Color(0.02, 0.02, 0.035)

## A rooftop/platform slab. Extends visually to the bottom of the screen so
## every platform reads as a building. Rim-lit top edge + random roof props.
static func platform(x: float, y: float, w: float, rim: Color, props: bool = true) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = Vector2(x, y)
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, 900)   # collision matches the full building visual
	shape.shape = rect
	shape.position = Vector2(w * 0.5, 450)
	body.add_child(shape)
	var vis := PlatformVisual.new()
	vis.setup(w, 900.0, rim, props)
	body.add_child(vis)
	return body

## A tall wall: solid ground on top, wall-runnable face (layer 16) on the side.
static func wall(x: float, ground_y: float, height: float, w: float, rim: Color) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = Vector2(x, ground_y - height)
	body.collision_layer = 1 | 16
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, height + 900.0)
	shape.shape = rect
	shape.position = Vector2(w * 0.5, (height + 900.0) * 0.5)
	body.add_child(shape)
	var vis := PlatformVisual.new()
	vis.setup(w, height + 900.0, rim, false)
	body.add_child(vis)
	return body

## A low crate/AC-unit the player auto-vaults. Solid + on the vault-ray layer.
static func vault_box(x: float, ground_y: float, rim: Color) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = Vector2(x, ground_y - 52)
	body.collision_layer = 1 | 32
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(64, 52)
	shape.shape = rect
	shape.position = Vector2(32, 26)
	body.add_child(shape)
	var vis := PlatformVisual.new()
	vis.setup(64, 52, rim, false)
	body.add_child(vis)
	return body

## Overhead laser fence — lethal unless you slide under it. Glows for readability.
static func slide_barrier(x: float, ground_y: float, ray_color: Color) -> Node2D:
	var root := Node2D.new()
	root.position = Vector2(x, ground_y)
	# Two silhouette posts.
	for px in [0.0, 120.0]:
		var post := PlatformVisual.new()
		post.setup(10, 130, Color(ray_color, 0.4), false)
		post.position = Vector2(px, -130)
		root.add_child(post)
	# Lethal beam spanning the posts, hip-height and above — sliding clears it.
	var hz := Hazard.new()
	hz.lethal = true
	hz.position = Vector2(60, -78)
	hz.beam_size = Vector2(120, 62)
	hz.beam_color = ray_color
	root.add_child(hz)
	return root

## Ground spikes / live cable — lethal floor hazard inside some chunks.
static func floor_hazard(x: float, ground_y: float, w: float, ray_color: Color) -> Node2D:
	var root := Node2D.new()
	root.position = Vector2(x, ground_y)
	var hz := Hazard.new()
	hz.lethal = true
	hz.position = Vector2(w * 0.5, -14)
	hz.beam_size = Vector2(w, 24)
	hz.beam_color = ray_color
	hz.spikes = true
	root.add_child(hz)
	return root

static func coin(x: float, y: float, glow: Color) -> Area2D:
	var c := Coin.new()
	c.position = Vector2(x, y)
	c.glow_color = glow
	return c
