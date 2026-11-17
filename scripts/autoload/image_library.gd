extends Node
## ImageLibrary (autoload) – finds bundled puzzle pictures and loads them.
##
## Pictures live in res://assets/images/<category>/ and may be SVG, PNG, JPG
## or WEBP. Drop new files into a category folder and they are picked up
## automatically – no code changes needed. Non-square pictures are
## centre-cropped to a square, and big ones are scaled down to save memory.

const ROOT := "res://assets/images/"
const CATEGORIES := ["nature", "animals", "landscapes", "architecture", "vehicles", "technology"]
const EXTENSIONS := ["svg", "png", "jpg", "jpeg", "webp"]
const MAX_SIZE := 1024

## Each entry: {"path": String, "category": String, "name": String}
var images: Array = []
## Campaign order: categories interleaved, see _build_level_order().
var _level_order: Array = []


func _ready() -> void:
	_scan()


func _scan() -> void:
	images.clear()
	var seen := {}
	for cat in CATEGORIES:
		var dir := DirAccess.open(ROOT + cat)
		if dir == null:
			continue
		for f in dir.get_files():
			var file := f
			# In exported builds only "<name>.<ext>.import" files are listed.
			if file.ends_with(".import"):
				file = file.trim_suffix(".import")
			elif file.ends_with(".remap"):
				file = file.trim_suffix(".remap")
			if not EXTENSIONS.has(file.get_extension().to_lower()):
				continue
			var path: String = ROOT + cat + "/" + file
			if seen.has(path):
				continue
			seen[path] = true
			images.append({
				"path": path,
				"category": cat,
				"name": file.get_basename().replace("_", " ").capitalize(),
			})
	# Stable order on every platform → the daily seed picks the same image.
	images.sort_custom(func(a, b): return str(a["path"]) < str(b["path"]))
	_build_level_order()
	if images.is_empty():
		push_warning("No puzzle images found in %s – using generated pictures." % ROOT)


## Random picture, avoiding the recently used ones when possible.
func pick_random(recent: Array) -> Dictionary:
	if images.is_empty():
		return _generated_entry(randi())
	var pool: Array = images.filter(func(i): return not recent.has(i["path"]))
	if pool.is_empty():
		pool = images.duplicate()
	return pool[randi() % pool.size()]


## Fixed picture for a campaign level, so each level always shows the same
## image. With 50+ pictures every level is unique; with fewer they cycle.
func pick_for_level(level: int) -> Dictionary:
	if _level_order.is_empty():
		return _generated_entry(level * 7919)
	return _level_order[(maxi(level, 1) - 1) % _level_order.size()]


## Round-robin across categories (animals, nature, landscapes, …) so
## neighbouring levels show different kinds of pictures.
func _build_level_order() -> void:
	_level_order.clear()
	var buckets: Array = []
	for cat in CATEGORIES:
		buckets.append(images.filter(func(i): return i["category"] == cat))
	var added := true
	var idx := 0
	while added:
		added = false
		for b in buckets:
			if idx < b.size():
				_level_order.append(b[idx])
				added = true
		idx += 1


## Deterministic picture for a seed (used by the daily challenge).
func pick_seeded(seed_value: int) -> Dictionary:
	if images.is_empty():
		return _generated_entry(seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return images[rng.randi_range(0, images.size() - 1)]


## Loads the texture for an entry, guaranteeing a square image.
func load_texture(entry: Dictionary) -> Texture2D:
	if entry.get("generated", false):
		return _generate_picture(int(entry["seed"]))
	var tex := load(str(entry["path"])) as Texture2D
	if tex == null:
		return _generate_picture(str(entry["path"]).hash())
	var w := tex.get_width()
	var h := tex.get_height()
	if w == h and w <= MAX_SIZE:
		return tex
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	var side := mini(w, h)
	img = img.get_region(Rect2i((w - side) / 2, (h - side) / 2, side, side))
	if side > MAX_SIZE:
		img.resize(MAX_SIZE, MAX_SIZE, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


func category_title(cat: String) -> String:
	return cat.capitalize()


func _generated_entry(seed_value: int) -> Dictionary:
	return {"path": "generated://%d" % seed_value, "category": "abstract", "name": "Abstract", "generated": true, "seed": seed_value}


## Safety net so the game never breaks if the images folder is missing:
## paints a colourful abstract picture procedurally.
func _generate_picture(seed_value: int) -> Texture2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var size := 512
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c1 := Color.from_hsv(rng.randf(), 0.55, 0.95)
	var c2 := Color.from_hsv(rng.randf(), 0.75, 0.55)
	for y in size:
		img.fill_rect(Rect2i(0, y, size, 1), c1.lerp(c2, float(y) / size))
	for i in 26:
		var w := rng.randi_range(30, 180)
		var h := rng.randi_range(30, 180)
		var col := Color.from_hsv(rng.randf(), rng.randf_range(0.4, 0.9), rng.randf_range(0.6, 1.0))
		img.fill_rect(Rect2i(rng.randi_range(0, size - w), rng.randi_range(0, size - h), w, h), col)
	return ImageTexture.create_from_image(img)
