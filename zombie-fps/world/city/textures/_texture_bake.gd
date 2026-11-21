extends Node
## One-shot editor tool: generates every city texture as an original work
## (FastNoiseLite + Image API; poster decals rendered through a SubViewport
## with a serif system font). Run the sibling _texture_bake.tscn once from
## the editor to (re)bake res://world/city/textures/*.png — the game never
## loads this script. Kept in-repo so the art pass is reproducible and the
## textures' provenance is documented (see CREDITS.md).

const OUT := "res://world/city/textures/"
const S := 512


func _ready() -> void:
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	_cobbles()
	_flagstone()
	_brick()
	_portland()
	_plaster()
	_wallpaper()
	_dado()
	_floorboards()
	_checker()
	_boards()
	_slate()
	_windows()
	await _posters()
	print("[bake] all textures written in %d ms" % (Time.get_ticks_msec() - t0))
	get_tree().quit()


# ---------- helpers ----------

func _cell_noise(seed_v: int, freq: float, ret: int) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = freq
	n.cellular_return_type = ret
	n.cellular_jitter = 0.9
	return n.get_seamless_image(S, S, false, false, 0.1, true)


func _fbm_noise(seed_v: int, freq: float, octaves: int = 4) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = freq
	n.fractal_octaves = octaves
	return n.get_seamless_image(S, S, false, false, 0.1, true)


func _hash2(ix: int, iy: int) -> float:
	return fposmod(sin(float(ix) * 127.1 + float(iy) * 311.7) * 43758.5453, 1.0)


func _save(img: Image, name_v: String) -> void:
	img.save_png(OUT + name_v)
	print("[bake] ", name_v)


## Multiplies img by a low-frequency grime field remapped to [lo..1].
func _grime(img: Image, seed_v: int, freq: float, lo: float) -> void:
	var g := _fbm_noise(seed_v, freq)
	for y in S:
		for x in S:
			var m: float = lerpf(lo, 1.0, g.get_pixel(x % g.get_width(), y % g.get_height()).r)
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r * m, c.g * m, c.b * m))


# ---------- street ----------

func _cobbles() -> void:
	var edges := _cell_noise(11, 0.055, FastNoiseLite.RETURN_DISTANCE2_SUB)
	var cells := _cell_noise(11, 0.055, FastNoiseLite.RETURN_CELL_VALUE)
	var fine := _fbm_noise(12, 0.03, 5)
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	for y in S:
		for x in S:
			var e := edges.get_pixel(x, y).r
			var tint := cells.get_pixel(x, y).r
			var f := fine.get_pixel(x, y).r
			var base := Color(0.30, 0.295, 0.28) * (0.78 + 0.4 * tint)
			base = base.lerp(Color(0.24, 0.26, 0.25), f * 0.5)
			if e < 0.14:
				base = Color(0.10, 0.10, 0.10).lerp(base, e / 0.14 * 0.4)
			img.set_pixel(x, y, base)
	_grime(img, 13, 0.008, 0.55)
	_save(img, "cobbles.png")


func _flagstone() -> void:
	var edges := _cell_noise(21, 0.028, FastNoiseLite.RETURN_DISTANCE2_SUB)
	var cells := _cell_noise(21, 0.028, FastNoiseLite.RETURN_CELL_VALUE)
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	for y in S:
		for x in S:
			var e := edges.get_pixel(x, y).r
			var tint := cells.get_pixel(x, y).r
			var base := Color(0.37, 0.36, 0.34) * (0.85 + 0.3 * tint)
			if e < 0.08:
				base = Color(0.12, 0.12, 0.12).lerp(base, e / 0.08 * 0.5)
			img.set_pixel(x, y, base)
	_grime(img, 22, 0.01, 0.6)
	_save(img, "flagstone.png")


# ---------- walls ----------

func _brick() -> void:
	# Tile represents ~1.5 m: course 26 px, brick 78 px, mortar 3 px.
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var course := 26
	var blen := 78
	for y in S:
		var row := y / course
		var iny := y % course
		for x in S:
			var off := (row % 2) * (blen / 2)
			var bx := (x + off) / blen
			var inx := (x + off) % blen
			var col: Color
			if iny < 3 or inx < 3:
				col = Color(0.28, 0.25, 0.22)  # mortar
			else:
				var h := _hash2(bx, row)
				col = Color(0.34, 0.185, 0.14).lerp(Color(0.24, 0.14, 0.115), h)
				var h2 := _hash2(bx * 7 + 3, row * 5 + 1)
				if h2 > 0.85:
					col = Color(0.18, 0.15, 0.14)  # the odd blackened brick
			img.set_pixel(x, y, col)
	_grime(img, 31, 0.012, 0.42)  # heavy soot
	_save(img, "brick.png")


func _portland() -> void:
	# Ashlar blocks ~256x128 px on a 512 tile.
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var bh := 128
	var bw := 256
	for y in S:
		var row := y / bh
		var iny := y % bh
		for x in S:
			var off := (row % 2) * (bw / 2)
			var bx := (x + off) / bw
			var inx := (x + off) % bw
			var col: Color
			if iny < 4 or inx < 4:
				col = Color(0.38, 0.37, 0.34)
			else:
				var h := _hash2(bx, row)
				col = Color(0.55, 0.53, 0.48) * (0.92 + 0.12 * h)
			img.set_pixel(x, y, col)
	# Vertical rain-streak grime: stretch noise along Y.
	var streak := _fbm_noise(41, 0.02, 3)
	for y in S:
		for x in S:
			var m: float = lerpf(0.62, 1.0, streak.get_pixel(x, int(y * 0.15) % S).r)
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, c * m)
	_grime(img, 42, 0.009, 0.72)
	_save(img, "portland.png")


# ---------- interiors ----------

func _plaster() -> void:
	var blotch := _fbm_noise(51, 0.012, 4)
	var damp := _fbm_noise(52, 0.006, 3)
	var speck := _fbm_noise(53, 0.09, 2)
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	for y in S:
		for x in S:
			var base := Color(0.55, 0.50, 0.40)
			base = base.lerp(Color(0.42, 0.38, 0.32), blotch.get_pixel(x, y).r)
			var d := damp.get_pixel(x, y).r
			if d > 0.62:
				base = base.lerp(Color(0.30, 0.26, 0.20), (d - 0.62) * 2.2)
			base *= 0.9 + 0.2 * speck.get_pixel(x, y).r
			img.set_pixel(x, y, base)
	_save(img, "plaster_int.png")


func _wallpaper() -> void:
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	for y in S:
		for x in S:
			var stripe := int(x / 32) % 2 == 0
			var col := Color(0.50, 0.44, 0.34) if stripe else Color(0.43, 0.36, 0.28)
			if int(x / 8) % 8 == 3:
				col = col.lerp(Color(0.36, 0.30, 0.24), 0.5)  # thin accent stripe
			img.set_pixel(x, y, col)
	_grime(img, 61, 0.01, 0.45)
	_save(img, "wallpaper.png")


func _dado() -> void:
	var grain := _fbm_noise(71, 0.02, 4)
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	for y in S:
		for x in S:
			var plank := x / 86
			var inx := x % 86
			var h := _hash2(plank, 0)
			var col := Color(0.24, 0.16, 0.10) * (0.85 + 0.3 * h)
			col *= 0.85 + 0.3 * grain.get_pixel(int(x * 0.2) % S, y).r
			if inx < 3:
				col *= 0.55
			img.set_pixel(x, y, col)
	_save(img, "dado_wood.png")


func _floorboards() -> void:
	var grain := _fbm_noise(81, 0.02, 4)
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	for y in S:
		var plank := y / 64
		var iny := y % 64
		for x in S:
			var joint := (int(_hash2(plank, 0) * 512.0) + plank * 217) % 512
			var h := _hash2(plank, x / 256)
			var col := Color(0.30, 0.22, 0.14) * (0.82 + 0.3 * h)
			col *= 0.85 + 0.3 * grain.get_pixel(x, int(y * 0.2) % S).r
			if iny < 3 or absi(x - joint) < 2:
				col *= 0.5
			img.set_pixel(x, y, col)
	_grime(img, 82, 0.01, 0.6)
	_save(img, "floorboards.png")


func _checker() -> void:
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	for y in S:
		for x in S:
			var cx := x / 64
			var cy := y / 64
			var white := (cx + cy) % 2 == 0
			var col := Color(0.58, 0.56, 0.48) if white else Color(0.12, 0.12, 0.13)
			col *= 0.85 + 0.3 * _hash2(cx, cy)
			if x % 64 < 2 or y % 64 < 2:
				col *= 0.6
			img.set_pixel(x, y, col)
	_grime(img, 91, 0.012, 0.4)
	_save(img, "checker_tile.png")


func _boards() -> void:
	var grain := _fbm_noise(101, 0.025, 4)
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	for y in S:
		var plank := y / 72
		var iny := y % 72
		for x in S:
			var h := _hash2(plank, 0)
			var col := Color(0.35, 0.30, 0.24) * (0.75 + 0.4 * h)
			col *= 0.8 + 0.4 * grain.get_pixel(x, int(y * 0.3) % S).r
			if iny < 4:
				col *= 0.35  # gap between boards
			img.set_pixel(x, y, col)
	_grime(img, 102, 0.015, 0.55)
	_save(img, "boards.png")


func _slate() -> void:
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	for y in S:
		var row := y / 52
		var iny := y % 52
		for x in S:
			var off := (row % 2) * 42
			var sx := (x + off) / 84
			var col := Color(0.15, 0.16, 0.18) * (0.85 + 0.3 * _hash2(sx, row))
			if iny < 3 or (x + off) % 84 < 3:
				col *= 0.55
			img.set_pixel(x, y, col)
	_save(img, "slate.png")


# ---------- windows (single-quad decals, 256x384) ----------

func _window_base(img: Image, w: int, h: int) -> void:
	var sheen := _fbm_noise(111, 0.02, 3)
	for y in h:
		for x in w:
			var col := Color(0.05, 0.065, 0.085)
			col *= 0.8 + 0.5 * sheen.get_pixel(x % S, y % S).r
			# frame
			if x < 14 or x >= w - 14 or y < 14 or y >= h - 14:
				col = Color(0.16, 0.13, 0.10)
			# sash bars: one vertical center, two horizontal thirds
			elif absi(x - w / 2) < 4 or absi(y - h / 3) < 4 or absi(y - 2 * h / 3) < 4:
				col = Color(0.20, 0.17, 0.14)
			img.set_pixel(x, y, col)


func _windows() -> void:
	var w := 256
	var h := 384
	# plain blacked-out sash window
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	_window_base(img, w, h)
	img.save_png(OUT + "window_dark.png")
	print("[bake] window_dark.png")
	# blast-taped variant: white tape X per pane half
	var img2 := Image.create(w, h, false, Image.FORMAT_RGB8)
	_window_base(img2, w, h)
	for pane in 3:
		var y0 := 14 + pane * (h - 28) / 3
		var y1 := 14 + (pane + 1) * (h - 28) / 3
		for y in range(y0, y1):
			var t := float(y - y0) / float(y1 - y0)
			for xx in [int(lerpf(20.0, w - 20.0, t)), int(lerpf(w - 20.0, 20.0, t))]:
				for dx in range(-4, 5):
					var px: int = xx + dx
					if px >= 14 and px < w - 14:
						img2.set_pixel(px, y, Color(0.75, 0.73, 0.68))
	img2.save_png(OUT + "window_taped.png")
	print("[bake] window_taped.png")
	# boarded variant
	var img3 := Image.create(w, h, false, Image.FORMAT_RGB8)
	_window_base(img3, w, h)
	var grain := _fbm_noise(112, 0.03, 3)
	for y in range(14, h - 14):
		var plank := (y - 14) / 46
		if (y - 14) % 46 < 4:
			continue  # leave dark glass showing between boards
		for x in range(14, w - 14):
			var col := Color(0.34, 0.29, 0.23) * (0.7 + 0.5 * _hash2(plank, 7))
			col *= 0.8 + 0.4 * grain.get_pixel(x % S, y % S).r
			img3.set_pixel(x, y, col)
	img3.save_png(OUT + "window_boarded.png")
	print("[bake] window_boarded.png")


# ---------- posters (SubViewport text render, fictional period brands) ----------

func _posters() -> void:
	var specs := [
		{"file": "poster_bovrin.png", "bg": Color(0.55, 0.12, 0.10), "fg": Color(0.92, 0.88, 0.78),
			"title": "BOVRIN", "sub": "HOT BEEF TEA\nWARMS THE WATCH"},
		{"file": "poster_tea.png", "bg": Color(0.16, 0.32, 0.22), "fg": Color(0.9, 0.87, 0.74),
			"title": "PENNYWHISTLE\nTEA", "sub": "THE NATION'S CUP"},
		{"file": "poster_cigs.png", "bg": Color(0.12, 0.16, 0.3), "fg": Color(0.85, 0.74, 0.45),
			"title": "OAKHURST", "sub": "CIGARETTES\nSMOOTH AS OAK"},
		{"file": "poster_blackout.png", "bg": Color(0.08, 0.08, 0.08), "fg": Color(0.85, 0.83, 0.78),
			"title": "BLACKOUT\nIN FORCE", "sub": "LIGHTS OUT AT DUSK\nA.R.P. NOTICE"},
		{"file": "poster_soap.png", "bg": Color(0.2, 0.3, 0.42), "fg": Color(0.92, 0.9, 0.84),
			"title": "MERRIWEATHER'S\nSOAP", "sub": "WHITER THAN WHITE"},
		{"file": "poster_grow.png", "bg": Color(0.3, 0.34, 0.16), "fg": Color(0.9, 0.88, 0.75),
			"title": "GROW & SAVE", "sub": "EVERY GARDEN\nA LARDER"},
	]
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "Times New Roman", "Serif"])
	var grime_img := _fbm_noise(121, 0.015, 4)
	for spec in specs:
		var vp := SubViewport.new()
		vp.size = Vector2i(256, 384)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var bg := ColorRect.new()
		bg.color = spec["bg"]
		bg.size = Vector2(256, 384)
		vp.add_child(bg)
		var frame := ColorRect.new()
		frame.color = spec["fg"]
		frame.size = Vector2(232, 360)
		frame.position = Vector2(12, 12)
		vp.add_child(frame)
		var inner := ColorRect.new()
		inner.color = spec["bg"]
		inner.size = Vector2(220, 348)
		inner.position = Vector2(18, 18)
		vp.add_child(inner)
		var title := Label.new()
		title.text = spec["title"]
		title.add_theme_font_override("font", font)
		title.add_theme_font_size_override("font_size", 34)
		title.add_theme_color_override("font_color", spec["fg"])
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.size = Vector2(220, 160)
		title.position = Vector2(18, 40)
		vp.add_child(title)
		var sub := Label.new()
		sub.text = spec["sub"]
		sub.add_theme_font_override("font", font)
		sub.add_theme_font_size_override("font_size", 18)
		sub.add_theme_color_override("font_color", spec["fg"])
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.size = Vector2(220, 120)
		sub.position = Vector2(18, 230)
		vp.add_child(sub)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		for y in img.get_height():
			for x in img.get_width():
				var m: float = lerpf(0.5, 1.0, grime_img.get_pixel(x % S, y % S).r)
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, c * m)
		img.save_png(OUT + spec["file"])
		print("[bake] ", spec["file"])
		vp.queue_free()
