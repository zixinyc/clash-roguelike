extends Node

signal status_changed(message: String)
signal session_closed(message: String)
signal round_opened(state: Dictionary)
signal ready_changed(own_ready: bool, opponent_ready: bool)
signal plan_rejected(message: String)
signal round_resolved(state: Dictionary, events: Array)

const DEFAULT_IP := "127.0.0.1"
const DEFAULT_PORT := 7000
const HOST_ID := 1
const DuelRules = preload("res://scripts/pvp/pvp_battle_rules.gd")

var _opponent_id := 0
var _rules: DuelRules
var _locked := {}
var _played := {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_peer_joined)
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)

func host_game(port: int = DEFAULT_PORT) -> Error:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		return ERR_ALREADY_IN_USE
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, 1)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		status_changed.emit("房间已创建，等待对手 · UDP %d" % port)
	return error

func join_game(address: String = DEFAULT_IP, port: int = DEFAULT_PORT) -> Error:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		return ERR_ALREADY_IN_USE
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), port)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		status_changed.emit("正在连接 %s:%d…" % [address, port])
	return error

func leave_game(message: String = "已退出房间。") -> void:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	multiplayer.multiplayer_peer = null
	if peer != null:
		peer.close()
	_rules = null
	_opponent_id = 0
	_locked.clear()
	_played.clear()
	session_closed.emit(message)

func submit_plan(turn: int, plan: Array) -> void:
	if not multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		plan_rejected.emit("连接已断开，请重新建房或加入。")
	elif multiplayer.is_server():
		_accept_plan(HOST_ID, turn, plan)
	else:
		rpc_id(HOST_ID, "_submit_remote", turn, plan)

func playback_finished(turn: int) -> void:
	if not multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		return
	if multiplayer.is_server():
		_accept_playback(HOST_ID, turn)
	else:
		_playback_remote.rpc_id(HOST_ID, turn)

func _peer_joined(id: int) -> void:
	if not multiplayer.is_server():
		return
	_opponent_id = id
	_rules = DuelRules.new()
	_rules.start_duel(randi())
	_open_round()

func _peer_left(id: int) -> void:
	if multiplayer.is_server() and id == _opponent_id:
		leave_game("对手已退出，房间关闭。")

func _connection_failed() -> void:
	leave_game("连接失败。请确认房主已建房，IP 和 UDP 端口正确。")

func _server_disconnected() -> void:
	leave_game("房主已断开，房间关闭。")

func _open_round() -> void:
	_locked.clear()
	_played.clear()
	var state := _rules.snapshot()
	_receive_round.rpc_id(_opponent_id, DuelRules.view_state(state, true))
	_receive_round(DuelRules.view_state(state, false))

@rpc("any_peer", "call_remote", "reliable")
func _submit_remote(turn: int, plan: Array) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and sender == _opponent_id:
		_accept_plan(sender, turn, plan)

func _accept_plan(sender: int, turn: int, plan: Array) -> void:
	if _rules == null or _rules.phase != "response" or turn != _rules.turn or _locked.has(sender):
		return
	var is_guest := sender != HOST_ID
	var error := _rules.accept_plan(is_guest, plan)
	if not error.is_empty():
		if is_guest:
			_receive_rejection.rpc_id(sender, error)
		else:
			_receive_rejection(error)
		return
	_locked[sender] = true
	var host_ready := _locked.has(HOST_ID)
	var guest_ready := _locked.has(_opponent_id)
	_receive_ready.rpc_id(_opponent_id, guest_ready, host_ready)
	_receive_ready(host_ready, guest_ready)
	if not (host_ready and guest_ready):
		return
	var events := _rules.lock_and_resolve()
	var state := _rules.snapshot()
	_receive_result.rpc_id(_opponent_id, DuelRules.view_state(state, true), DuelRules.view_events(events, true))
	_receive_result(DuelRules.view_state(state, false), DuelRules.view_events(events, false))

@rpc("any_peer", "call_remote", "reliable")
func _playback_remote(turn: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and sender == _opponent_id:
		_accept_playback(sender, turn)

func _accept_playback(sender: int, turn: int) -> void:
	if _rules == null or turn != _rules.turn or _rules.phase != "finished":
		return
	_played[sender] = true
	if _played.has(HOST_ID) and _played.has(_opponent_id):
		_rules.next_round()
		_open_round()

@rpc("authority", "call_remote", "reliable")
func _receive_round(state: Dictionary) -> void:
	round_opened.emit(state)

@rpc("authority", "call_remote", "reliable")
func _receive_ready(own_ready: bool, opponent_ready: bool) -> void:
	ready_changed.emit(own_ready, opponent_ready)

@rpc("authority", "call_remote", "reliable")
func _receive_rejection(message: String) -> void:
	plan_rejected.emit(message)

@rpc("authority", "call_remote", "reliable")
func _receive_result(state: Dictionary, events: Array) -> void:
	round_resolved.emit(state, events)
