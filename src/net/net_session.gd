## Rede para duas pessoas (anfitriao com autoridade). Transporte = MultiplayerPeer (hoje ENet por IP;
## Steam depois). RPCs: setup, comandos, confirmacao com hash do estado.
class_name NetSession
extends Node




signal setup_received(match_seed: int, team0: Array, team1: Array)
signal command_from_client(cmd: Dictionary)
signal command_applied(cmd: Dictionary, state_hash: int)
signal command_rejected
signal client_joined
signal lost_connection
signal connection_failed

const DEFAULT_PORT := 24577

var is_host := false
var active := false
var local_team_dicts: Array = []
var forced_seed := -1


func _ready() -> void :
    multiplayer.peer_connected.connect( func(_id): if is_host: client_joined.emit())
    multiplayer.peer_disconnected.connect( func(_id): _lost())
    multiplayer.connected_to_server.connect( func(): _c_hello.rpc_id(1, local_team_dicts))
    multiplayer.connection_failed.connect( func(): connection_failed.emit())
    multiplayer.server_disconnected.connect( func(): _lost())


func _lost() -> void :
    if active:
        active = false
        lost_connection.emit()


func host_game(port: int, team_dicts: Array) -> int:
    close()
    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_server(port, 1)
    if err != OK:
        return err
    multiplayer.multiplayer_peer = peer
    is_host = true
    active = true
    local_team_dicts = team_dicts
    return OK


func join_game(address: String, port: int, team_dicts: Array) -> int:
    close()
    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_client(address, port)
    if err != OK:
        return err
    multiplayer.multiplayer_peer = peer
    is_host = false
    active = true
    local_team_dicts = team_dicts
    return OK


func close() -> void :
    active = false
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()
        multiplayer.multiplayer_peer = null


func submit(cmd: Dictionary) -> void :
    _c_cmd.rpc_id(1, cmd)


func broadcast(cmd: Dictionary, state_hash: int) -> void :
    _s_cmd.rpc(cmd, state_hash)


func reject() -> void :
    _s_reject.rpc()


static func local_ip() -> String:
    for a in IP.get_local_addresses():
        if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
            return a
    return "127.0.0.1"


@rpc("any_peer", "call_remote", "reliable")
func _c_hello(team: Array) -> void :
    if not is_host:
        return
    var sender := multiplayer.get_remote_sender_id()
    var s := forced_seed if forced_seed >= 0 else randi() % 100000
    _s_begin.rpc_id(sender, s, local_team_dicts, team)
    setup_received.emit(s, local_team_dicts, team)


@rpc("authority", "call_remote", "reliable")
func _s_begin(s: int, team0: Array, team1: Array) -> void :
    setup_received.emit(s, team0, team1)


@rpc("any_peer", "call_remote", "reliable")
func _c_cmd(cmd: Dictionary) -> void :
    if is_host:
        command_from_client.emit(cmd)


@rpc("authority", "call_remote", "reliable")
func _s_cmd(cmd: Dictionary, state_hash: int) -> void :
    command_applied.emit(cmd, state_hash)


@rpc("authority", "call_remote", "reliable")
func _s_reject() -> void :
    command_rejected.emit()
