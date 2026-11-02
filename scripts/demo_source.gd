class_name DemoSource
## Fake sessions for `-- --demo`: statuses cycle and teams appear, so every animation shows up within a minute.

## name, title, phase offset, model, subagents it spawns while busy
const AGENTS := [
	["e7", "Контейнер Applio", 0.0, "claude-opus-5-5", 0],
	["factd", "Продуктивність гри", 14.0, "claude-sonnet-5-5", 4],
	["bot", "Оновлення бота", 27.0, "claude-haiku-5-5", 0],
	["site", "Редизайн сайту", 8.0, "claude-fable-5-1", 0],
	["rust", "Рефакторинг парсера", 35.0, "claude-opus-5-5", 3],
	["docs", "Опис API", 20.0, "claude-sonnet-5-5", 0],
]
const SCRIPT := [["busy", 16.0], ["shell", 7.0], ["blocked", 4.0], ["busy", 9.0], ["idle", 34.0]]
const TOOLS := [["Bash", "Запуск тестів"], ["Edit", "src/main.rs"], ["Read", "README.md"],
		["Grep", "TODO"], ["Write", "docs/api.md"]]
const TEAM := [["Explore", "Шукає виклики API"], ["Plan", "Планує міграцію"],
		["general-purpose", "Пише тести"], ["code-reviewer", "Рев'ю diff"]]
## name, title, appears at, closes at, model: sessions that get closed, to call the TCK
const GUESTS := [
	["short", "Коротке завдання", 6.0, 22.0, "claude-haiku-5-5"],
	["tmp", "Одноразова сесія", 36.0, 52.0, "claude-sonnet-5-5"],
]


static func sessions(elapsed: float) -> Array:
	var result := []
	var now := Time.get_unix_time_from_system()
	for agent: Array in AGENTS:
		result.append(_session(agent[0], agent[1], agent[3], elapsed + agent[2], now, agent[4]))
	for guest: Array in GUESTS:
		if elapsed > guest[2] and elapsed < guest[3]:
			result.append(_session(guest[0], guest[1], guest[4], elapsed - guest[2], now, 0))
	return result


static func _session(id: String, title: String, model: String, time: float, now: float, team: int) -> Dictionary:
	var cycle := 0.0
	for step: Array in SCRIPT:
		cycle += step[1]
	var phase := fmod(time, cycle)
	var status := "busy"
	var since := now
	var start := 0.0
	for step: Array in SCRIPT:
		if phase < start + step[1]:
			status = step[0]
			since = now - (phase - start)
			break
		start += step[1]
	var subagents := []
	for k in team:  # the team shows up during the first stretch of work
		if phase >= 1.5 + 1.5 * k and phase < 14.0 - 0.5 * k:
			subagents.append({"id": "%s-%d" % [id, k], "type": TEAM[k][0], "desc": TEAM[k][1]})
	var tool: Array = TOOLS[int(time / 5.0) % TOOLS.size()]
	return {
		"sessionId": "demo-" + id, "name": id, "title": title, "status": status,
		"statusSince": since, "cwd": "~/projects/" + id, "model": model, "context": 120000,
		"outputTokens": 40000, "turns": 3, "toolCalls": 20, "lastPrompt": "Демо-запит",
		"commands": ["cargo test"] if status == "shell" else [],
		"feed": [{"kind": "tool", "tool": tool[0], "text": tool[1]}],
		"subagents": subagents,
	}
