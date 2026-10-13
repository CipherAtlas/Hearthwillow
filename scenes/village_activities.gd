extends Node3D

signal activity_sound(kind: String, point: Vector3)

# Local simulation preserves the production growth/recipe rules and authored anchors.
const CROPS := {"carrot":"carrots","radish":"radishes","mint":"mint","daisy":"daisies","sunflower":"sunflowers"}
const GROW_SECONDS := {"carrot":300.0,"radish":120.0,"mint":180.0,"daisy":180.0,"sunflower":300.0}
const RECIPES := [
	{"id":"gardenSoup","name":"Garden soup","ja":"畑のスープ","ingredients":{"carrots":1,"mushrooms":1}},
	{"id":"crispSalad","name":"Mint & radish salad","ja":"ミントとラディッシュのサラダ","ingredients":{"radishes":1,"mint":1}},
	{"id":"bakedApples","name":"Baked apples","ja":"焼きリンゴ","ingredients":{"apples":1}},
	{"id":"roastRoots","name":"Roasted vegetables","ja":"畑の焼き野菜","ingredients":{"carrots":1,"radishes":1}}
]
const SAVE := "user://village-activities.json"
const GIFTS := ["carrot","radish","mint","daisy","sunflower"]
const HARVEST_COMPLIMENTS := {
	"carrot":["You grew this? What a lovely little carrot. You have such a gentle touch!","育てたの？なんてかわいいニンジン。あなたの優しさが伝わるね！"],
	"radish":["A rosy little radish! You make this garden feel loved. Thank you.","ばら色のラディッシュ！あなたのおかげで、庭が幸せそう。ありがとう。"],
	"mint":["It smells wonderful! You grew a little cup of happiness. This special mint tea is for you.","いい香り！小さな幸せを育ててくれたね。特別なミントティーをどうぞ。"],
	"daisy":["A daisy for me? What a lovely little piece of your garden. Thank you!","デイジーをくれるの？あなたの庭から届いた、小さな宝物だね。ありがとう！"],
	"sunflower":["A sunflower! It's like a little bit of sunshine from your garden. Thank you!","ひまわり！あなたの庭のお日さまみたい。ありがとう！"]
}
@onready var world: Node = get_parent()
@onready var surface: Node = world.get_node("WorldSurface")
@onready var player: CharacterBody3D = world.get_node("Player")
@onready var life: Node = world.get_node("VillageLife")
@onready var menus: Node = world.get_node("HUD/Menus")
@onready var panel: PanelContainer = $UI/Context
@onready var cooking_hud: PanelContainer = $UI/Cooking
var beds: Dictionary = {}
var inventory := {"mushrooms":0,"carrots":0,"radishes":0,"mint":0,"daisies":0,"sunflowers":0,"mintTea":0,"gardenSoup":0,"crispSalad":0,"bakedApples":0,"roastRoots":0}
var cooking: Dictionary = {}
var dishes: Array = []
var nearby: Dictionary = {}
var scan_time := 0.0
var next_bite := 0.0
var action_until := 0.0
var forage_ready: Dictionary = {}
var save_time := 0.0
var last_counts := ""
var last_visuals := ""
var selected_garden := 0
var garden_page := false
var garden_tab := 0
var save_error := false

func now() -> float:
	return Time.get_unix_time_from_system()

func count_item(key: String) -> int:
	return life.apples if key == "apples" else int(inventory.get(key,0))

func add_item(key: String, amount: int) -> void:
	if key == "apples": life.apples = clampi(life.apples+amount,0,9999)
	else: inventory[key] = clampi(count_item(key)+amount,0,9999)

func harvest_count() -> int:
	return count_item("carrots")+count_item("radishes")+count_item("mint")+count_item("daisies")+count_item("sunflowers")

func _ready() -> void:
	for bed: Node3D in $Crops.get_children():
		var id := str(bed.name)
		var crop := str(bed.get_meta("initial_crop",""))
		var stage := str(bed.get_meta("initial_stage","empty"))
		beds[id] = {"crop":crop,"stage":stage,"watered":0.0}
		var item_id := str(bed.get_meta("item_id",id))
		for item: Dictionary in surface.data.items:
			if item.id == item_id:
				bed.transform = surface.item_transform(item)*bed.transform
				bed.set_meta("base_scale_y",item.scale[1])
				break
	for anchor: Node3D in $Kitchens.get_children()+$Served.get_children():
		for item: Dictionary in surface.data.items:
			if item.id == str(anchor.name): anchor.transform = surface.item_transform(item); break
	for clock: Node3D in $Clocks.get_children():
		var bed: Node3D = $Crops.get_node(clock.bed_id)
		clock.transform = bed.transform * clock.transform
	load_state()
	update_visuals()
	panel.hide()
	cooking_hud.hide()

func grow() -> void:
	for id: String in beds:
		var bed: Dictionary = beds[id]
		if bed.stage == "growing" and now() >= float(bed.watered)+growth_duration(id,bed.crop): bed.stage = "grown"

func growth_duration(id: String, crop: String) -> float:
	return float(GROW_SECONDS[crop]) if id.begins_with("garden-") else 180.0

func _process(delta: float) -> void:
	scan_time -= delta
	save_time -= delta
	if player.controls_blocked: world.get_node("VillageSeating").picnic_basket_open = false
	if scan_time <= 0:
		scan_time = .1
		grow()
		update_visuals()
		nearby = find_context()
		refresh_context()
		refresh_cooking()
		if garden_page: refresh_garden()
	if save_time <= 0:
		save_time = 2
		var counts := str(inventory)+str(life.apples)
		if counts != last_counts: save_state(); last_counts = counts
	animate_action()
	animate_cooking()

func find_context() -> Dictionary:
	if player.controls_blocked or player.mount or get_parent().get_node("FocusCottage").inside: return {}
	var seating: Node = get_parent().get_node("VillageSeating")
	if player.activity_locked and not str(seating.seated.get("id","")).begins_with("picnic"): return {}
	if seating.owns_context() and not str(seating.seated.get("id",seating.near_bench.get("id",""))).begins_with("picnic"): return {}
	# A nearby animal owns E for petting; broad farm-row areas must not steal it.
	if life.nearest and life.nearest.actor_kind != "resident" and player.position.distance_to(life.nearest.position)<2.5: return {}
	var point := Vector2(player.position.x,player.position.z)
	var nearest := INF
	var result := {}
	for bed: Node3D in $Crops.get_children():
		var local: Vector3 = bed.to_local(player.position)
		var half_width: float = bed.get_meta("half_width",1.6)
		var gap := Vector2(maxf(0,absf(local.x)-half_width)*bed.scale.x,maxf(0,absf(local.z)-.6)*bed.scale.z).length()
		if gap <= 2.4 and gap < nearest:
			nearest = gap
			result = {"kind":"bed","id":str(bed.name)}
	for item: Dictionary in surface.placements.get("garden-kitchen",[])+surface.placements.get("picnic-mat",[])+surface.placements.get("mushroom-patch",[]):
		var kitchen: bool = item.asset == "garden-kitchen"
		var gap := point.distance_to(surface.world_point(item,Vector2(0,1.9) if kitchen else Vector2.ZERO))
		if gap <= (3.0 if kitchen else 4.0)*maxf(item.scale[0],item.scale[2]) and gap < nearest:
			nearest = gap
			result = {"kind":"kitchen" if kitchen else "picnic" if item.asset == "picnic-mat" else "mushroom","id":item.id,"item":item}
	var garden_items: Array = surface.placements.get("kitchen-garden",[])
	if not garden_items.is_empty():
		var item: Dictionary = garden_items[0]
		if point.distance_to(surface.world_point(item,Vector2(-6.7,2.8))) < 2.3: result = {"kind":"basket","id":"basket"}
		if point.distance_to(surface.world_point(item,Vector2(6.1,-1.3))) < 2.4: result = {"kind":"flowers","id":"flowers"}
	if life.nearest and life.nearest.actor_id == "luma" and player.position.distance_to(life.nearest.position) < 3 and harvest_count()+count_item("mintTea")>0:
		result = {"kind":"luma","id":"luma"}
	return result

func words(en: String, ja: String) -> String:
	return menus.tr_pair(en,ja)

func crop_name(crop: String) -> String:
	return words({"carrot":"Carrots","radish":"Radishes","mint":"Mint","daisy":"Daisies","sunflower":"Sunflowers"}.get(crop,crop),{"carrot":"ニンジン","radish":"ラディッシュ","mint":"ミント","daisy":"デイジー","sunflower":"ひまわり"}.get(crop,crop))

var visible_actions: Array[int] = []

func set_action(slot: int, label: String, key: String, enabled := true) -> void:
	visible_actions.append(slot)
	var button := panel.get_node("Content/Actions/Action%d"%slot) as Button
	button.show()
	button.get_node("Row/Text").text = label
	button.action = "activity_"+key if key.is_valid_int() else key
	button.set_key(menus.key_name(button.action) if menus.defaults.has(button.action) else OS.get_keycode_string(InputMap.action_get_events(button.action)[0].physical_keycode) if InputMap.has_action(button.action) else key)
	button.get_node("Row/Key").visible = not key.is_empty()
	button.set_enabled(enabled)

func refresh_context() -> void:
	panel.visible = not nearby.is_empty() and not garden_page and (nearby.kind!="picnic" or world.get_node("VillageSeating").picnic_basket_open)
	visible_actions.clear()
	if nearby.is_empty(): return
	life.context.hide()
	var title := panel.get_node("Content/Title") as Label
	var status := panel.get_node("Content/Status") as Label
	status.text = ""
	panel.position = Vector2(get_viewport().get_visible_rect().size.x-398,get_viewport().get_visible_rect().size.y-86-panel.size.y)
	if nearby.kind == "bed":
		var bed: Dictionary = beds[nearby.id]
		var node: Node3D = $Crops.get_node(nearby.id)
		title.text = words("Kitchen garden","菜園")+" · "+words("Bed","花壇")+" "+str(int(str(nearby.id).trim_prefix("garden-"))+1) if str(nearby.id).begins_with("garden-") else str(node.get_meta("title","Farm row"))
		if bed.stage == "empty":
			var choices: Array = node.get_meta("choices")
			for i in choices.size(): set_action(i,words("Plant ","植える：")+crop_name(choices[i]),"interact" if i == 0 else str(i+1))
		elif bed.stage == "sprout": status.text = words("Needs water","水が必要"); set_action(0,words("Water","水をあげる"),"interact")
		elif bed.stage == "grown": status.text = words("Ready to pick","収穫できます"); set_action(0,words("Harvest","収穫する"),"interact")
		else:
			var seconds := maxi(0,ceili(float(bed.watered)+growth_duration(nearby.id,bed.crop)-now()))
			status.text = crop_name(bed.crop)+" · "+words("Growing","成長中")+"   %d:%02d"%[floori(seconds/60.0),seconds%60]
			set_action(0,words("Harvest","収穫する"),"interact",false)
	elif nearby.kind in ["kitchen","picnic"]:
		title.text = words("Garden kitchen","キッチン") if nearby.kind == "kitchen" else words("Picnic mat","ピクニックマット")
		status.text = words("Choose a recipe. Each dish serves 3.","料理を選んでください。各料理は3人分です。") if nearby.kind == "kitchen" else words("Place a dish on the mat, then eat a portion.","料理をマットに置いて食べる。")
		for i in RECIPES.size():
			var recipe: Dictionary = RECIPES[i]
			var label: String = recipe.ja if menus.language == 1 else recipe.name
			if nearby.kind == "kitchen":
				var ingredients := []
				for key: String in recipe.ingredients: ingredients.append("%s %d/%d"%[key.capitalize(),count_item(key),recipe.ingredients[key]])
				label += "\n"+", ".join(ingredients)
				set_action(i,words("Cook ","作る：")+label,str(i+1),cooking.is_empty() and can_cook(i))
			else: set_action(i,words("Place ","置く：")+label+" · "+str(count_item(recipe.id)),str(i+1),count_item(recipe.id)>0 and dishes.filter(func(d: Dictionary): return d.mat == nearby.id).size()<4)
		if nearby.kind == "kitchen" and not cooking.is_empty(): set_action(4,words("Pack into basket","かごに入れる"),"interact",cooking.kitchen == nearby.id and now()>=cooking.ready)
		elif nearby.kind == "picnic":
			var served: Array = dishes.filter(func(d: Dictionary): return d.mat == nearby.id)
			for i in served.size(): set_action(4+i,words("Eat ","食べる：")+recipe_title(served[i].recipe)+" · "+str(served[i].portions),"interact" if i==0 else str(i+5),now() >= next_bite)
	elif nearby.kind == "mushroom":
		title.text = words("Mushroom patch","キノコの群生")
		set_action(0,words("Pick a mushroom","キノコを摘む"),"interact",now() >= float(forage_ready.get(nearby.id,0)))
	elif nearby.kind == "basket":
		title.text = words("Harvest basket","収穫かご")
		status.text = inventory_text()
		set_action(0,words("Open kitchen garden","菜園を見る"),"interact")
	elif nearby.kind == "flowers":
		title.text = words("Irises","アイリス")
		set_action(0,words("Water the irises","アイリスに水をあげる"),"interact")
	elif nearby.kind == "luma":
		title.text = words("Bring your harvest to Luma","収穫をルマに届ける")
		for index in GIFTS.size():
			var crop: String = GIFTS[index]
			if count_item(CROPS[crop])>0: set_action(index,words("Give ","渡す：")+crop_name(crop),"bread" if index == 3 else "companion" if index == 4 else str(index+1))
		if count_item("mintTea")>0: set_action(5,words("Drink your special mint tea","特別なミントティーを飲む"),"interact")
	for index in 8:
		if index not in visible_actions: panel.get_node("Content/Actions/Action%d"%index).hide()
	if save_error: status.text += "\n"+words("Your progress could not be saved.","進行状況を保存できませんでした。")
	panel.size.y = panel.get_combined_minimum_size().y

func inventory_text(include_empty := false) -> String:
	var lines := PackedStringArray()
	for key: String in ["apples"]+inventory.keys():
		if include_empty or count_item(key)>0: lines.append(item_name(key)+"   "+str(count_item(key)))
	return "\n".join(lines) if not lines.is_empty() else words("Your basket is empty.","かごは空です。")

func item_name(key: String) -> String:
	for crop: String in CROPS:
		if CROPS[crop] == key: return crop_name(crop)
	if key == "apples": return words("Apples","りんご")
	if key == "mushrooms": return words("Mushrooms","キノコ")
	if key == "mintTea": return words("Mint tea","ミントティー")
	return recipe_title(key)

func recipe_title(id: String) -> String:
	for recipe: Dictionary in RECIPES:
		if recipe.id == id: return recipe.ja if menus.language == 1 else recipe.name
	return id

func can_cook(index: int) -> bool:
	for key: String in RECIPES[index].ingredients:
		if count_item(key)<int(RECIPES[index].ingredients[key]): return false
	return true

func _input(event: InputEvent) -> void:
	if garden_page and (event.is_action_pressed("release_mouse") or event.is_action_pressed("menu_back")):
		close_garden(); get_viewport().set_input_as_handled(); return
	if event.is_echo() or player.controls_blocked or player.mount or nearby.is_empty(): return
	var slot := -1
	if event.is_action_pressed("interact"): slot = 4 if nearby.kind == "kitchen" else 4 if nearby.kind == "picnic" else 5 if nearby.kind == "luma" else 0
	if nearby.kind == "luma":
		if event.is_action_pressed("bread"): slot = 3
		elif event.is_action_pressed("companion"): slot = 4
	for index in 8:
		if event.is_action_pressed("activity_%d"%(index+1)): slot = index
	if slot < 0: return
	var button := panel.get_node("Content/Actions/Action%d"%slot) as Button
	if button.visible:
		if not button.disabled: activate(slot)
		get_viewport().set_input_as_handled()

func activate(slot: int) -> bool:
	var context := find_context()
	if context.is_empty() or context != nearby: return false
	if nearby.kind == "bed":
		if not change_bed(nearby.id,slot): return false
	elif nearby.kind == "kitchen":
		if slot == 4:
			if cooking.is_empty() or cooking.kitchen != nearby.id or now() < cooking.ready or count_item(cooking.recipe)>=9999: return false
			add_item(cooking.recipe,1); cooking = {}
		elif slot < RECIPES.size():
			if not cooking.is_empty() or not can_cook(slot): return false
			var recipe: Dictionary = RECIPES[slot]
			for key: String in recipe.ingredients: add_item(key,-int(recipe.ingredients[key]))
			cooking = {"kitchen":nearby.id,"recipe":recipe.id,"started":now(),"ready":now()+4.5}
		else: return false
	elif nearby.kind == "picnic":
		var served: Array = dishes.filter(func(d: Dictionary): return d.mat == nearby.id)
		if slot < 4:
			var recipe: Dictionary = RECIPES[slot]
			if count_item(recipe.id)<1 or served.size()>=4: return false
			var position_index := 0
			while served.any(func(d: Dictionary): return d.slot == position_index): position_index += 1
			add_item(recipe.id,-1)
			dishes.append({"mat":nearby.id,"slot":position_index,"recipe":recipe.id,"portions":3})
		elif slot-4<served.size() and now()>=next_bite:
			var dish: Dictionary = served[slot-4]
			dish.portions -= 1; next_bite = now()+3
			if dish.portions <= 0: dishes.erase(dish)
			life.say("",words("Enjoying ","食べています：")+recipe_title(dish.recipe),3)
		else: return false
	elif nearby.kind == "mushroom":
		if now()<float(forage_ready.get(nearby.id,0)): return false
		add_item("mushrooms",1); forage_ready[nearby.id] = now()+30
	elif nearby.kind == "flowers": start_water(player.position+Vector3(0,0,-1))
	elif nearby.kind == "basket":
		open_garden()
	elif nearby.kind == "luma":
		return give_luma(slot)
	else: return false
	save_state()
	last_visuals = ""
	update_visuals(); refresh_context(); refresh_cooking()
	return true

func give_luma(slot: int) -> bool:
	var luma: CharacterBody3D
	for actor: CharacterBody3D in life.actors.get_children():
		if actor.actor_id == "luma": luma = actor; break
	if luma == null: return false
	var places: Node = world.get_node("QuietPlaces")
	if places.active != "mood" and (life.nearest != luma or player.position.distance_to(luma.position)>3): return false
	if slot == 5:
		if count_item("mintTea")<=0: return false
		add_item("mintTea",-1)
	else:
		if slot<0 or slot>=GIFTS.size(): return false
		var crop: String = GIFTS[slot]
		if count_item(CROPS[crop])<=0 or crop=="mint" and count_item("mintTea")>=9999: return false
		add_item(CROPS[crop],-1)
		if crop == "mint": add_item("mintTea",1)
		luma.chatting = 6
		life.say(life.actor_name(luma),words(HARVEST_COMPLIMENTS[crop][0],HARVEST_COMPLIMENTS[crop][1]),6)
	activity_sound.emit("pour" if slot == 5 or slot == 2 else "pluck",player.position)
	save_state()
	last_visuals = ""
	update_visuals(); refresh_context(); refresh_cooking()
	return true

func change_bed(id: String, choice: int) -> bool:
	var bed: Dictionary = beds[id]
	if bed.stage == "empty":
		var choices: Array = $Crops.get_node(id).get_meta("choices")
		if choice<0 or choice>=choices.size(): return false
		bed.crop = choices[choice]; bed.stage = "sprout"
		activity_sound.emit("plant",$Crops.get_node(id).global_position)
	elif bed.stage == "sprout":
		bed.stage = "growing"; bed.watered = now(); start_water($Crops.get_node(id).global_position)
	elif bed.stage == "grown":
		if count_item(CROPS[bed.crop])>=9999: return false
		add_item(CROPS[bed.crop],1); bed.stage = "empty"
		activity_sound.emit("pluck",$Crops.get_node(id).global_position)
	else: return false
	return true

func refresh_cooking() -> void:
	cooking_hud.visible = not cooking.is_empty() and not menus.is_open() and not world.get_node("HUD/VillageMap").expanded
	if cooking.is_empty(): return
	var progress := clampf((now()-float(cooking.started))/4.5,0,1)
	cooking_hud.get_node("Content/Title").text = words("Ready to pack","受け取り可能") if progress >= 1 else words("Preparing","下ごしらえ") if progress<.32 else words("Cooking","調理中") if progress<.72 else words("Finishing","仕上げ中")
	cooking_hud.get_node("Content/Recipe").text = recipe_title(cooking.recipe)
	cooking_hud.get_node("Content/Progress").value = progress*100
	cooking_hud.get_node("Content/Pack").visible = progress>=1 and not nearby.is_empty() and nearby.kind == "kitchen" and nearby.id == cooking.kitchen

func update_visuals() -> void:
	var stamp := str(beds)+str(dishes)+str(cooking)
	if stamp != last_visuals:
		last_visuals = stamp
		for bed: Node3D in $Crops.get_children():
			var state: Dictionary = beds[str(bed.name)]
			for crop: MultiMeshInstance3D in bed.get_children(): crop.visible = state.stage != "empty" and str(crop.name) == ("sprout" if state.stage == "sprout" else str(state.crop))
		for mat: Node3D in $Served.get_children():
			for slot: Node3D in mat.get_children():
				var found: Array = dishes.filter(func(d: Dictionary): return d.mat == str(mat.name) and d.slot == slot.get_index())
				for dish: Node3D in slot.get_children(): dish.visible = not found.is_empty() and str(dish.name) == found[0].recipe
		for kitchen: Node3D in $Kitchens.get_children():
			for visual: Node3D in kitchen.get_children(): visual.visible = not cooking.is_empty() and cooking.kitchen == str(kitchen.name) and cooking.recipe == str(visual.name)
	for bed: Node3D in $Crops.get_children():
		var state: Dictionary = beds[str(bed.name)]
		var growth := .18+.82*clampf((now()-float(state.watered))/growth_duration(str(bed.name),state.crop),0,1) if state.stage == "growing" else 1.0
		bed.scale.y = float(bed.get_meta("base_scale_y",1))*growth

func start_water(point: Vector3) -> void:
	activity_sound.emit("water",point)
	action_until = now()+2.5
	$WateringCan.position = point+Vector3(-.4,1.45,0)
	$WaterDrops.position = point+Vector3(.16,1.3,0)
	$WaterDrops.restart(); $WaterDrops.emitting = true

func animate_action() -> void:
	$WateringCan.visible = now()<action_until
	$WaterDrops.emitting = $WateringCan.visible
	$WaterDrops.speed_scale = 0.0 if menus.reduced_motion else 1.0
	if $WateringCan.visible: $WateringCan.rotation.z = -.35 if menus.reduced_motion else -.35+sin(now()*3)*.08

func animate_cooking() -> void:
	if cooking.is_empty(): return
	var visual: Node3D = $Kitchens.get_node(NodePath(cooking.kitchen+"/"+cooking.recipe))
	var elapsed := maxf(0,now()-float(cooking.started))
	var progress := minf(1,elapsed/4.5)
	var motion_time := 0.0 if menus.reduced_motion else elapsed
	var salad: bool = cooking.recipe == "crispSalad"
	for name_text: String in ["Knife","Spoon","Heat","Liquid","Ingredients","Steam","KitchenFinishedDish"]:
		var part := visual.find_child(name_text,true,false) as Node3D
		if not part: continue
		part.visible = progress<.3 if name_text == "Knife" else progress>=.3 and progress<.82 if name_text == "Spoon" else progress>=.3 and progress<.82 and not salad if name_text in ["Heat","Steam"] else not salad and progress<.82 if name_text == "Liquid" else progress<.82 if name_text == "Ingredients" else progress>=.82
		if name_text == "Knife": part.position.y = 1.43+absf(sin(motion_time/.065))*.16
		elif name_text == "Spoon": part.position = Vector3((1.23 if salad else -1.2)+sin(motion_time/.165)*.16,1.61 if salad else 1.82,-.51+cos(motion_time/.165)*.14)
		elif name_text == "Steam":
			for puff: Node3D in part.get_children():
				var age := fmod(motion_time*.8+puff.get_index()/6.0,1)
				puff.position = Vector3(-1.2+sin(puff.get_index()*2.4)*.14,1.8+age*.75,-.55+cos(puff.get_index()*2.4)*.14)
				puff.scale = Vector3.ONE*(.5+age)

func refresh_garden() -> void:
	for i in 7:
		var state: Dictionary = beds["garden-%d"%i]
		var card: Control = $UI/Garden/Content/Beds.get_child(i)
		card.visible = i<4 if garden_tab==0 else i>=4
		card.get_node("Content/Heading/Details/Title").text = words("Mint · Tea leaves","ミント・お茶の葉") if i == 4 else crop_name(state.crop) if state.stage != "empty" or i>=4 else words("Empty bed","空の花壇")
		card.get_node("Content/Heading/Details/State").text = words("Needs water","水が必要") if state.stage == "sprout" else words("Ready to pick","収穫できます") if state.stage == "grown" else words("Growing","成長中") if state.stage == "growing" else ""
		card.get_node("Content/Actions/Primary").text = words("Plant ","植える：")+crop_name(state.crop if i>=4 else "carrot") if state.stage == "empty" else words("Water","水をあげる") if state.stage == "sprout" else words("Pick","摘む")
		card.get_node("Content/Actions/Primary").disabled = state.stage == "growing"
		card.get_node("Content/Actions").visible = state.stage != "growing"
		card.get_node("Content/Actions/Alternate").visible = i<4 and state.stage == "empty"
	$UI/Garden/Content/Inventory.text = words("Harvest basket","収穫かご")+" · "+str(harvest_count())
	$UI/Garden/Content/Irises.visible = garden_tab == 1
	$UI/Garden/Content/BringHarvest.visible = harvest_count()>0
	$UI/Garden.size.y = $UI/Garden.get_combined_minimum_size().y
	$UI/Garden.position.y = get_viewport().get_visible_rect().size.y-86-$UI/Garden.size.y

func set_garden_tab(index: int) -> void:
	garden_tab = index
	refresh_garden()

func select_garden(index: int, choice := 0) -> void:
	var node: Node3D = $Crops.get_node("garden-%d"%index)
	if player.mount or player.position.distance_to(node.global_position)>15: return
	if change_bed(str(node.name),choice):
		save_state(); last_visuals = ""; update_visuals(); refresh_garden()

func open_garden() -> void:
	if world.get_node("QuietPlaces").active!="garden" and not world.get_node("QuietPlaces").enter("garden"): return
	garden_page = true
	$UI/Garden.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh_garden()

func close_garden() -> void:
	garden_page = false
	if world.get_node("QuietPlaces").active=="garden": world.get_node("QuietPlaces").leave()
	$UI/Garden.hide()

func garden_extra(index: int) -> void:
	if not garden_page: return
	if index == 0:
		var item: Dictionary = surface.placements["kitchen-garden"][0]
		start_water(Vector3(surface.world_point(item,Vector2(6.1,-1.3)).x,.4,surface.world_point(item,Vector2(6.1,-1.3)).y))
	elif index == 1:
		close_garden()
		menus.open_inventory()
	elif index == 2:
		close_garden()
		var map: Node = world.get_node("HUD/VillageMap")
		var places: Node = world.get_node("QuietPlaces")
		var point: Vector3 = places.entry_point("mood")
		map.travel_point(Vector2(point.x,point.z))
		places.enter("mood")

func save_state() -> void:
	var content := {"version":1,"beds":beds,"inventory":inventory,"apples":life.apples,"cooking":cooking,"dishes":dishes,"forage":forage_ready}
	var file := FileAccess.open(SAVE+".tmp",FileAccess.WRITE)
	if not file:
		save_error = true
		return
	file.store_string(JSON.stringify(content))
	file.flush()
	var error := file.get_error()
	file.close()
	save_error = error != OK or DirAccess.rename_absolute(SAVE+".tmp",SAVE) != OK

func load_state() -> void:
	if not FileAccess.file_exists(SAVE): return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if not value is Dictionary or value.get("version") != 1: return
	cooking = {}
	dishes = []
	forage_ready = {}
	for key: String in inventory:
		var count_value: Variant = value.get("inventory",{}).get(key,0)
		if count_value is float or count_value is int: inventory[key] = clampi(int(count_value),0,9999)
	life.apples = clampi(int(value.get("apples",0)),0,9999)
	for id: String in beds:
		var saved: Variant = value.get("beds",{}).get(id)
		if not saved is Dictionary: continue
		var choices: Array = $Crops.get_node(id).get_meta("choices")
		if saved.get("crop") not in choices or saved.get("stage") not in ["empty","sprout","growing","grown"]: continue
		var watered: Variant = saved.get("watered",0)
		if not (watered is int or watered is float): watered = 0
		beds[id] = {"crop":saved.crop,"stage":saved.stage,"watered":clampf(float(watered),0,now())}
		if saved.stage == "growing" and float(watered)<=0: beds[id].stage = "sprout"
	var saved_forage: Variant = value.get("forage",{})
	if saved_forage is Dictionary:
		for key: String in saved_forage:
			if saved_forage[key] is float or saved_forage[key] is int: forage_ready[key] = clampf(float(saved_forage[key]),0,now()+30)
	var saved_job: Variant = value.get("cooking",{})
	if saved_job is Dictionary and not saved_job.is_empty():
		if $Kitchens.has_node(str(saved_job.get("kitchen",""))+"/"+str(saved_job.get("recipe",""))) and (saved_job.get("started") is float or saved_job.get("started") is int) and (saved_job.get("ready") is float or saved_job.get("ready") is int) and float(saved_job.ready)>=float(saved_job.started) and float(saved_job.ready)-float(saved_job.started)<=4.51: cooking = saved_job
	var saved_dishes: Variant = value.get("dishes",[])
	if saved_dishes is Array:
		for dish: Variant in saved_dishes:
			if dish is Dictionary and $Served.has_node(str(dish.get("mat",""))) and dish.get("slot",-1) in [0,1,2,3] and dish.get("portions",0) in [1,2,3] and RECIPES.any(func(recipe: Dictionary): return recipe.id == dish.get("recipe")):
				if not dishes.any(func(existing: Dictionary): return existing.mat == dish.mat and existing.slot == dish.slot): dishes.append(dish)
	grow()
