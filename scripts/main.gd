extends Node2D
## Turns the session list from the monitor into bugs: working at desks, resting in the lounge,
## leading teams of subagents, and being caught by the TCK when the session is closed.

const URL := "http://127.0.0.1:8765/api/sessions"
const POLL_SECONDS := 2.0
## An idle session often gets its next prompt within seconds; only then does the bug go to the lounge.
const REST_AFTER_IDLE := 8.0
## The van waits this long after the last catch, so one trip can take several prisoners.
const DEPART_DELAY := 1.4
const OFFICER_COUNT := 3
const PET_RADIUS := 38.0

## Labels and bubbles; bugs read this in their constructors.
var overlay := CanvasLayer.new()
var agents := {}  # session id -> Agent
var minions := {}  # "session:subagent" -> Minion
var slots: Array = []  # desks first, then lounge seats; value is an Agent or null
var selected_id := ""
var taken_total := 0
var pets_total := 0

var _world := SubViewport.new()
var _office := Office.new()
var _decor := Decor.new()
var _traffic := Traffic.new()
var _screens := Screens.new()
var _van := Van.new()
var _sidebar := Sidebar.new()
var _officers: Array[Officer] = []
var _waiting: Array[Agent] = []  # no free seat: they stay outside until one opens
var _http := HTTPRequest.new()
var _demo := false
var _demo_time := 0.0
var _clock := 0.0
var _last_load := -10.0
var _first_update := true
var _was_parked := false
var _parked_at := 0.0
var _stroking := false


func _ready() -> void:
	get_window().title = "Офіс жуків"
	_demo = "--demo" in OS.get_cmdline_user_args()
	slots.resize(Layout.slot_count())
	_screens.occupants = slots
	_setup_world()
	add_child(overlay)
	add_child(_sidebar)
	_van.loaded.connect(_on_loaded)
	_sidebar.picked.connect(_select)
	for i in OFFICER_COUNT:
		var officer := Officer.new(_van, self)
		_officers.append(officer)
		_world.add_child(officer)
	add_child(_http)
	_http.timeout = 3.0
	_http.request_completed.connect(_on_response)

	var timer := Timer.new()
	timer.wait_time = POLL_SECONDS
	timer.timeout.connect(_poll)
	add_child(timer)
	timer.start()
	_poll()


## The world renders at 1/4 scale and is shown with nearest filtering, so every shape
## lands on the same grid as the sprites. Game code keeps using 1600x900 coordinates.
func _setup_world() -> void:
	_world.size = Vector2i(Vector2(Layout.OFFICE_W, 900) / Layout.PIXEL)
	_world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_world)
	_world.canvas_transform = Transform2D.IDENTITY.scaled(Vector2.ONE / Layout.PIXEL)
	for node: Node in [_office, _decor, _traffic, _screens, _van]:
		_world.add_child(node)
	var view := TextureRect.new()
	view.texture = _world.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.size = Vector2(Layout.OFFICE_W, 900)
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)


func spawn_effect(effect: Node2D) -> void:
	_world.add_child(effect)


func spawn_heart(at: Vector2) -> void:
	var heart := Heart.new()
	heart.position = at
	_world.add_child(heart)


func _poll() -> void:
	if _demo:
		_apply(DemoSource.sessions(_demo_time), Time.get_unix_time_from_system())
	elif _http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_http.request(URL)


func _on_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not parsed is Dictionary:
		_sidebar.set_alert("Немає даних від монітора на порту 8765. Запустіть застосунок через run.sh.")
		return
	_sidebar.set_alert("")
	_apply(parsed.get("sessions", []), float(parsed.get("now", 0.0)))


func _apply(sessions: Array, now: float) -> void:
	var seen := {}
	for session: Dictionary in sessions:
		var id := Agent.text_of(session, "sessionId", "")
		seen[id] = true
		var since = session.get("statusSince")
		var idle_for := now - float(since) if since != null else 0.0
		var rest: bool = session.get("status") == "idle" and idle_for >= REST_AFTER_IDLE
		var agent: Agent = agents.get(id)
		if agent == null:
			agent = _add_agent(id, session, rest)
		agent.apply(session)
		agent.wants_rest = rest
		_sync_team(agent, session.get("subagents", []))
	for agent: Agent in agents.values():
		if not seen.has(agent.id) and not agent.ended:
			agent.ended = true  # closed: it is walked out of the office and caught
			_dismiss_team(agent)
	_first_update = false
	_refresh_sidebar()


func _add_agent(id: String, session: Dictionary, rest: bool) -> Agent:
	var agent := Agent.new(self, id)
	agents[id] = agent
	_world.add_child(agent)
	agent.data = session
	var slot := claim_slot(agent, rest)
	if slot < 0:
		slot = claim_slot(agent, not rest)
	if slot < 0:
		agent.wait_outside()
		_waiting.append(agent)
	elif _first_update:
		agent.place_at(slot)
	else:
		agent.walk_in(slot, Layout.STREET_ENTRY)
	if selected_id == "":
		_select(id)
	return agent


## Gives the agent a free seat of the wanted kind and frees its old one; -1 if none is free.
func claim_slot(agent: Agent, lounge: bool) -> int:
	var preferred := agent.home_lounge if lounge else agent.home_desk
	var free := -1
	if preferred >= 0 and slots[preferred] == null:
		free = preferred
	else:
		for i in slots.size():
			if Layout.is_lounge(i) == lounge and slots[i] == null:
				free = i
				break
	if free < 0:
		return -1
	release_slot(agent)
	slots[free] = agent
	agent.slot = free
	if lounge:
		agent.home_lounge = free
	else:
		agent.home_desk = free
	return free


func release_slot(agent: Agent) -> void:
	var taken := slots.find(agent)
	if taken >= 0:
		slots[taken] = null
	agent.slot = -1


## Subagents of a session stand next to its desk; the session itself wears the crown.
func _sync_team(agent: Agent, subs: Array) -> void:
	var live := {}
	var lines := PackedStringArray()
	var shown := 0
	for sub in subs:
		var info: Dictionary = sub
		lines.append("%s: %s" % [Agent.text_of(info, "type", "?"), Agent.text_of(info, "desc", "")])
		if shown >= Layout.MAX_TEAM:
			continue
		var key := agent.id + ":" + Agent.text_of(info, "id", str(shown))
		live[key] = true
		var minion: Minion = minions.get(key)
		if minion == null:
			minion = Minion.new(self, agent, key)
			minions[key] = minion
			_world.add_child(minion)
			agent.order(info)
		minion.apply(info, shown)
		shown += 1
	for key: String in minions.keys():
		var minion: Minion = minions[key]
		if minion.lead == agent and not live.has(key):
			minion.dismiss()
			minions.erase(key)
	agent.set_team(shown, maxi(0, subs.size() - shown), lines)


func _dismiss_team(agent: Agent) -> void:
	for key: String in minions.keys():
		var minion: Minion = minions[key]
		if minion.lead == agent:
			minion.dismiss()
			minions.erase(key)
	agent.set_team(0, 0, PackedStringArray())


func _process(delta: float) -> void:
	_clock += delta
	_demo_time += delta
	_call_tck()
	_dispatch_patrol()
	_serve_van()
	_serve_waiting()
	_screens.walkers = agents.values()


## The TCK only come when a session was closed: then the van drives in.
func _call_tck() -> void:
	if _van.state != Van.State.AWAY:
		return
	for agent: Agent in agents.values():
		if agent.ended:
			_van.summon()
			return


func _dispatch_patrol() -> void:
	if not _van.is_parked():
		return  # still on the way
	for agent: Agent in agents.values():
		if agent.state != Agent.State.FLEEING or _is_chased(agent):
			continue
		var best: Officer = null
		for officer in _officers:
			if officer.is_free() and (best == null or officer.position.distance_to(agent.position)
					< best.position.distance_to(agent.position)):
				best = officer
		if best != null:
			best.chase(agent)


func _is_chased(agent: Agent) -> bool:
	for officer in _officers:
		if officer.target == agent:
			return true
	return false


## The van leaves once every closed session is caught and all officers are back inside.
func _serve_van() -> void:
	if not _van.is_parked():
		_was_parked = false
		return
	if not _was_parked:
		_was_parked = true
		_parked_at = _clock
	if _clock - maxf(_last_load, _parked_at) < DEPART_DELAY:
		return
	for agent: Agent in agents.values():
		if agent.ended:
			return
	for officer in _officers:
		if officer.state != Officer.State.HIDDEN:
			return
	_van.depart()


func _serve_waiting() -> void:
	for agent in _waiting.duplicate():
		if agent.ended:
			_waiting.erase(agent)
			_remove(agent)
			continue
		var slot := claim_slot(agent, agent.wants_rest)
		if slot < 0:
			slot = claim_slot(agent, not agent.wants_rest)
		if slot >= 0:
			_waiting.erase(agent)
			agent.walk_in(slot, Layout.STREET_ENTRY)


func _on_loaded(agent: Agent) -> void:
	taken_total += 1
	_last_load = _clock
	_remove(agent)


func _remove(agent: Agent) -> void:
	_dismiss_team(agent)
	release_slot(agent)
	agents.erase(agent.id)
	if selected_id == agent.id:
		selected_id = ""
		if not agents.is_empty():
			_select(agents.keys()[0])
	agent.queue_free()
	_refresh_sidebar()


func _select(id: String) -> void:
	if agents.has(selected_id):
		agents[selected_id].selected = false
	selected_id = id
	if agents.has(id):
		agents[id].selected = true
	_refresh_sidebar()


## The bug under the cursor, if any: agents, subagents and officers can all be stroked.
func _bug_at(point: Vector2) -> Node2D:
	var best: Node2D = null
	var best_distance := PET_RADIUS
	var candidates: Array = agents.values() + minions.values() + _officers
	for bug: Node2D in candidates:
		if not bug.visible or (bug is Agent and bug.state == Agent.State.OUTSIDE):
			continue
		var distance := bug.position.distance_to(point + Vector2(0, 8))
		if distance < best_distance:
			best_distance = distance
			best = bug
	return best


func _stroke(bug: Node2D) -> void:
	if bug == null:
		return
	if bug is Agent:
		var agent := bug as Agent
		var before := agent.pets
		agent.pet()
		pets_total += agent.pets - before
	else:
		bug.call("pet")
	_refresh_stats()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_stroking = event.pressed
		if event.pressed:
			var bug := _bug_at(get_global_mouse_position())
			if bug is Agent:
				_select((bug as Agent).id)
			_stroke(bug)
	elif event is InputEventMouseMotion:
		var bug := _bug_at(get_global_mouse_position())
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if bug != null else Input.CURSOR_ARROW)
		if _stroking:  # hold the button and sweep over a bug to stroke it
			_stroke(bug)


func _refresh_stats() -> void:
	var working := 0
	var resting := 0
	for agent: Agent in agents.values():
		if agent.state == Agent.State.RESTING or (agent.state == Agent.State.WALKING and Layout.is_lounge(agent.slot)):
			resting += 1
		elif agent.state == Agent.State.WORKING or agent.state == Agent.State.WALKING:
			working += 1
	_sidebar.set_stats(working, resting, minions.size(), taken_total, pets_total)


func _refresh_sidebar() -> void:
	_refresh_stats()
	_sidebar.update_roster(agents.values())
	_sidebar.show_details(agents.get(selected_id))
