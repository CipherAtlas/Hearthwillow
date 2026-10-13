extends PanelContainer

signal moment(kind: String)

@export var save_path := "user://journal-notes.json"
@onready var places: Node = get_parent().get_parent()
@onready var menus: Node = places.get_parent().get_node("HUD/Menus")
@onready var editor: TextEdit = $Content/Write/Note
var entries: Array = []
var read_failed := false
var view := "write"
var selected := -1
var removing := false
var list_scroll := 0
var last_language := -1
const HEADING := "Hearthwillow notes\n==================\n\n"
const NOTE_ROW := preload("res://scenes/journal_note_row.tscn")

func words(en: String, ja: String) -> String:
	return menus.tr_pair(en,ja)

func _ready() -> void:
	load_notes()
	$Content/Write/Save.set_key("⌘/Ctrl ↵")
	$Content/Write/Save/Row/Key.show()
	refresh()

func valid_entries(value: Variant) -> bool:
	if not value is Array: return false
	var ids := {}
	for entry: Variant in value:
		if not entry is Dictionary: return false
		for key: String in ["id","text","createdAt"]:
			if not entry.get(key) is String: return false
		if entry.id.is_empty() or ids.has(entry.id): return false
		ids[entry.id] = true
	return true

func load_notes() -> bool:
	if not FileAccess.file_exists(save_path):
		entries = []; read_failed = false; return true
	var file := FileAccess.open(save_path,FileAccess.READ)
	if file:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if file.get_error() in [OK,ERR_FILE_EOF] and valid_entries(parsed):
			entries = parsed; read_failed = false; return true
	read_failed = true
	status(words("Saved notes could not be read. Your stored data has not been changed.","保存済みのメモを読み込めませんでした。データは変更していません。"))
	return false

func store_notes(next: Array) -> bool:
	if read_failed: return false
	var file := FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(next,"\t")); file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return false
	if DirAccess.rename_absolute(save_path+".tmp",save_path) != OK: return false
	entries = next
	return true

func make_entry(text: String, date: String) -> Dictionary:
	return {"id":Crypto.new().generate_random_bytes(16).hex_encode(),"text":text,"createdAt":date}

func status(text: String) -> void:
	$Content/Status.text = text
	$Content/Status.visible = not text.is_empty()

func save_note() -> bool:
	var text := editor.text.strip_edges()
	if text.is_empty() or editor.has_ime_text(): return false
	var next := entries.duplicate(true)
	next.push_front(make_entry(text,Time.get_datetime_string_from_system(true)+".000Z"))
	if not store_notes(next):
		status(words("Could not save. Please copy your note. Stored notes were not changed.","保存できませんでした。文章をコピーしてください。保存済みのメモは変更していません。")); return false
	editor.text = ""
	status(words("Saved.","この端末に保存しました。"))
	moment.emit("save")
	refresh()
	return true

func text_changed() -> void:
	# Source limit is 10,000 characters; keep composed Japanese text intact.
	if editor.text.length()>10000 and not editor.has_ime_text():
		editor.text = editor.text.left(10000)
		editor.set_caret_line(editor.get_line_count()-1)
		editor.set_caret_column(editor.get_line(editor.get_line_count()-1).length())
	if not read_failed: status("")
	moment.emit("write")
	refresh_save()

func refresh_save() -> void:
	var enabled := not read_failed and not editor.text.strip_edges().is_empty()
	$Content/Write/Save.set_enabled(enabled)
	for label: Label in [$Content/Write/Save/Row/Text,$Content/Write/Save/Row/Key/Text]:
		label.add_theme_color_override("font_color",Color("fff8e8") if enabled else Color("476052"))

func show_list() -> void:
	view = "list"; removing = false; selected = -1
	refresh()
	$Content/Library/Back.grab_focus()
	$Content/Library/List.set_deferred("scroll_vertical",list_scroll)

func read_note(index: int) -> void:
	if index < 0 or index >= entries.size(): return
	list_scroll = $Content/Library/List.scroll_vertical
	selected = index; view = "note"; removing = false
	refresh()
	$Content/Library/Back.grab_focus()

func back() -> void:
	if view == "note": show_list()
	else:
		list_scroll = $Content/Library/List.scroll_vertical
		view = "write"; refresh(); $Content/Write/History.grab_focus()

func ask_remove() -> void:
	removing = true; refresh(); $Content/Library/Confirm/Delete.grab_focus()

func keep_note() -> void:
	removing = false; refresh(); $Content/Library/Remove.grab_focus()

func delete_note() -> bool:
	if not removing or selected < 0 or selected >= entries.size(): return false
	var next := entries.duplicate(true); next.remove_at(selected)
	if not store_notes(next):
		status(words("Could not delete this note. Stored notes were not changed.","メモを削除できませんでした。保存済みのメモは変更していません。")); return false
	show_list(); status(words("Note deleted.","メモを削除しました。")); return true

func backup_text() -> String:
	var notes := PackedStringArray()
	for entry: Dictionary in entries:
		var lines := PackedStringArray()
		for line: String in str(entry.text).replace("\r\n","\n").replace("\r","\n").split("\n"): lines.append("  "+line)
		notes.append("["+entry.createdAt+"]\n"+"\n".join(lines))
	return HEADING+("\n\n".join(notes)+"\n" if not notes.is_empty() else "")

func import_text(raw: String) -> bool:
	if read_failed or not raw.replace("\r\n","\n").begins_with(HEADING): return import_failed()
	var lines := raw.replace("\r\n","\n").split("\n")
	var imported: Array = []; var index := 3
	var date_pattern := RegEx.new()
	date_pattern.compile("^\\[([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\\.[0-9]+)?Z)\\]$")
	while index < lines.size():
		if index == lines.size()-1 and lines[index].is_empty(): break
		var date_match := date_pattern.search(lines[index])
		if not date_match: return import_failed()
		var date := date_match.get_string(1)
		var calendar := Time.get_datetime_dict_from_datetime_string(date.left(19),false)
		if calendar.is_empty() or int(calendar.month) not in range(1,13) or int(calendar.day) not in range(1,32) or int(calendar.hour)>23 or int(calendar.minute)>59 or int(calendar.second)>59: return import_failed()
		var year := int(calendar.year)
		var leap_year := year%4==0 and (year%100!=0 or year%400==0)
		var days := [31,29 if leap_year else 28,31,30,31,30,31,31,30,31,30,31]
		if int(calendar.day)>int(days[int(calendar.month)-1]): return import_failed()
		var timestamp := Time.get_unix_time_from_datetime_string(date)
		if Time.get_datetime_string_from_unix_time(timestamp).left(19)!=date.left(19): return import_failed()
		index += 1
		var text_lines := PackedStringArray()
		while index < lines.size() and lines[index].begins_with("  "):
			text_lines.append(lines[index].substr(2)); index += 1
		if text_lines.is_empty() or "\n".join(text_lines).strip_edges().is_empty() or index>=lines.size() or not lines[index].is_empty(): return import_failed()
		imported.append({"text":"\n".join(text_lines),"createdAt":date}); index += 1
	var existing_counts := {}; var imported_counts := {}; var next := entries.duplicate(true)
	for entry: Dictionary in entries:
		var key := JSON.stringify([entry.createdAt,entry.text]); existing_counts[key] = int(existing_counts.get(key,0))+1
	for entry: Dictionary in imported:
		var key := JSON.stringify([entry.createdAt,entry.text]); imported_counts[key] = int(imported_counts.get(key,0))+1
		if imported_counts[key]>int(existing_counts.get(key,0)): next.append(make_entry(entry.text,entry.createdAt))
	if not store_notes(next): return import_failed()
	show_list(); status(words("Notes restored.","メモを復元しました。")); return true

func import_failed() -> bool:
	status(words("Could not restore this notes file. Stored notes were not changed.","メモを復元できませんでした。保存済みのメモは変更していません。")); return false

func choose_export() -> void:
	if read_failed: return
	$Export.current_file = "hearthwillow-notes.txt"; $Export.popup_centered(Vector2i(800,600))

func choose_import() -> void:
	$Import.popup_centered(Vector2i(800,600))

func export_file(path: String) -> bool:
	if read_failed: return false
	var file := FileAccess.open(path,FileAccess.WRITE)
	if not file:
		status(words("Could not download your notes.","メモをダウンロードできませんでした。")); return false
	file.store_string(backup_text()); file.flush()
	var success := file.get_error()==OK; file.close()
	status(words("Notes saved as a text file.","メモをテキストファイルに保存しました。") if success else words("Could not download your notes.","メモをダウンロードできませんでした。"))
	return success

func import_file(path: String) -> bool:
	var file := FileAccess.open(path,FileAccess.READ)
	if not file or file.get_length()>16*1024*1024: return import_failed()
	return import_text(file.get_as_text())

func format_date(date: String) -> String:
	var value := Time.get_datetime_dict_from_datetime_string(date.left(19),false)
	if value.is_empty(): return date.left(10)
	if menus.language==1: return "%d年%d月%d日"%[value.year,value.month,value.day]
	var months := ["January","February","March","April","May","June","July","August","September","October","November","December"]
	if int(value.month) not in range(1,13): return date.left(10)
	return "%d %s %d"%[value.day,months[int(value.month)-1],value.year]

func refresh() -> void:
	last_language = menus.language
	$Content/Heading.text = words("Journal","日記") if view=="write" else words("Past notes","これまでのメモ")+" · "+str(entries.size()) if view=="list" else words("A kept thought.","残したメモ")
	$Content/Write.visible = view=="write"; $Content/Library.visible = view!="write"
	$Content/Write/NoteLabel.text = words("Note","メモ")
	$Content/Write/Save.get_node("Row/Text").text = words("Keep this thought","残す")
	$Content/Write/History.text = words("Past notes","これまでのメモ")+" · "+str(entries.size())+"   →"
	$Content/Library/Back.text = "←   "+words("All notes","メモ一覧へ") if view=="note" else "←   "+words("Back to writing","書く画面へ")
	$Content/Library/List.visible = view=="list"; $Content/Library/Backup.visible = view=="list"
	$Content/Library/Empty.visible = view=="list" and entries.is_empty() and not read_failed
	$Content/Library/Empty.text = words("No saved notes.","保存されたメモはありません。")
	$Content/Library/Read.visible = view=="note"
	$Content/Library/Remove.visible = view=="note" and not removing
	$Content/Library/Confirm.visible = view=="note" and removing
	$Content/Library/Remove.text = words("Remove this note","このメモを削除")
	$Content/Library/Confirm/Prompt.text = words("Delete this note?","このメモを削除しますか？")
	$Content/Library/Confirm/Delete.text = words("Delete","削除する"); $Content/Library/Confirm/Keep.text = words("Keep","戻る")
	$Content/Library/Backup/Export.text = words("Download notes","メモをダウンロード")
	$Content/Library/Backup/Import.text = words("Restore notes","メモを復元")
	$Content/Library/Backup/Export.disabled = read_failed; $Content/Library/Backup/Import.disabled = read_failed
	if view=="note" and selected>=0 and selected<entries.size():
		$Content/Library/Read/Text.text = entries[selected].text+"\n\n"+format_date(str(entries[selected].createdAt))
	if view=="list":
		for child: Node in $Content/Library/List/Rows.get_children(): child.free()
		for i in entries.size():
			var row := NOTE_ROW.instantiate() as Button
			row.get_node("Content/Preview").text = str(entries[i].text).strip_edges().split("\n")[0]
			row.get_node("Content/Date").text = format_date(str(entries[i].createdAt))
			$Content/Library/List/Rows.add_child(row)
			row.pressed.connect(read_note.bind(i))
	refresh_save()

func _process(_delta: float) -> void:
	if visible and last_language!=menus.language: refresh()
