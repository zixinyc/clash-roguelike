extends Control

signal closed

const Planning = preload("res://scripts/pvp/pvp_planning_ui.gd")
const MapVisuals = preload("res://scripts/map_visuals.gd")

var _form: MarginContainer
var _address: LineEdit
var _port: SpinBox
var _status: Label
var _host: Button
var _join: Button
var _battle: Control

func _ready() -> void:
	theme = MapVisuals.create_ember_theme(16)
	var bg := ColorRect.new()
	bg.color = MapVisuals.WALNUT_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_form = MarginContainer.new()
	_form.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_form)

	var center := CenterContainer.new()
	_form.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 0)
	card.add_theme_stylebox_override("panel", MapVisuals.make_box(MapVisuals.WALNUT_BG, MapVisuals.BRASS_GOLD, 2, 10, 22, 20))
	center.add_child(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)

	var title := Label.new()
	title.text = "🌐 好友联机对战"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", MapVisuals.SUN_GOLD)
	column.add_child(title)

	var fields := HBoxContainer.new()
	fields.add_theme_constant_override("separation", 8)
	column.add_child(fields)

	_address = LineEdit.new()
	_address.text = NetworkManager.DEFAULT_IP
	_address.placeholder_text = "房主 IP"
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_child(_address)

	_port = SpinBox.new()
	_port.min_value = 1024
	_port.max_value = 65535
	_port.value = NetworkManager.DEFAULT_PORT
	_port.custom_minimum_size.x = 110
	fields.add_child(_port)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)
	_host = _button(actions, "🏠 创建房间", _host_game)
	_join = _button(actions, "🔗 加入房间", _join_game)
	_button(actions, "返回主菜单", _back)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", MapVisuals.CREAM_TEXT)
	_status.text = "双开测试可直接使用 127.0.0.1:7000。"
	column.add_child(_status)

	NetworkManager.status_changed.connect(_show_status)
	NetworkManager.session_closed.connect(_session_closed)
	NetworkManager.round_opened.connect(_open_round)

func _button(parent: HBoxContainer, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _host_game() -> void:
	var error := NetworkManager.host_game(int(_port.value))
	if error != OK:
		_status.text = "无法建房，请检查端口是否被占用（%s）。" % error_string(error)
		return
	var ips := _local_ipv4_addresses()
	if not ips.is_empty():
		_status.text += "\n本机可用 IPv4：%s（朋友在加入栏填写其中同一网段的 IP）" % ", ".join(ips)

func _local_ipv4_addresses() -> PackedStringArray:
	var result := PackedStringArray()
	for addr in IP.get_local_addresses():
		if addr.contains(":") or addr == "127.0.0.1" or addr.begins_with("169.254."):
			continue
		if not result.has(addr):
			result.append(addr)
	return result

func _join_game() -> void:
	var error := NetworkManager.join_game(_address.text, int(_port.value))
	if error != OK:
		_status.text = "无法加入，请检查房主 IP 和端口（%s）。" % error_string(error)

func _show_status(message: String) -> void:
	_status.text = message
	_host.disabled = true
	_join.disabled = true

func _open_round(state: Dictionary) -> void:
	if is_instance_valid(_battle):
		_battle.open_round(state)
		return
	_form.hide()
	_battle = Planning.new()
	_battle.initial_state = state
	_battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_battle)

func _session_closed(message: String) -> void:
	if is_instance_valid(_battle):
		remove_child(_battle)
		_battle.queue_free()
		_battle = null
	_host.disabled = false
	_join.disabled = false
	_status.text = message
	_form.show()

func _back() -> void:
	NetworkManager.leave_game()
	if closed.get_connections().is_empty():
		get_tree().change_scene_to_file("res://battle_setup.tscn")
	else:
		closed.emit()
