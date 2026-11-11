package model

PROFILE_COUNT :: 3
TRACE_CAPACITY :: 32
Values :: struct {
	show_help, enabled: bool,
	intensity:          i64,
	mode:               string,
}
Profile :: struct {
	id:      string,
	initial: Values,
}
Dialog :: enum {
	None,
	Dirty_Departure,
	Reset,
}
Action_Kind :: enum {
	Show_Help,
	Enabled,
	Intensity,
	Mode,
	Select_Profile,
	Tab,
	Apply,
	Cancel,
	Request_Reset,
	Dialog_Result,
	Escape,
	Unavailable,
}
Source :: enum {
	Application,
	Mouse,
	Keyboard,
	Gamepad,
	Agent,
}
Action :: struct {
	kind:               Action_Kind,
	id:                 string,
	checked:            bool,
	value:              i64,
	source:             Source,
	sequence, frame_id: u64,
}
Error :: enum {
	None,
	Invalid_State,
	Invalid_ID,
	Invalid_Value,
	Unavailable,
	Blocked_By_Dialog,
	Duplicate_Intent,
}
Trace :: struct {
	kind:                         Action_Kind,
	source:                       Source,
	profile_id:                   string,
	sequence, frame_id, revision: u64,
}
State :: struct {
	applied:                 [PROFILE_COUNT]Values,
	selected_id:             string,
	draft:                   Values,
	active_tab:              string,
	pending_id:              string,
	dialog:                  Dialog,
	revision, last_sequence: u64,
	trace:                   [TRACE_CAPACITY]Trace,
	trace_count, trace_next: int,
}
Result :: struct {
	error:   Error,
	changed: bool,
}
// All retained IDs refer to static fixtures, never an incoming/temp string.
fixture :: proc(index: int) -> Profile {
	switch index {
	case 0:
		return {"aurora", {true, true, 40, "normal"}}
	case 1:
		return {"borealis", {false, true, 70, "vivid"}}
	case 2:
		return {"cirrus", {true, false, 20, "calm"}}
	}
	return {}
}
create :: proc() -> State {
	s := State {
		selected_id = fixture(0).id,
		draft       = fixture(0).initial,
		active_tab  = "general",
	}
	for i in 0 ..< PROFILE_COUNT {s.applied[i] = fixture(i).initial}
	return s
}
@(private)
profile_index :: proc(id: string) -> int {
	for i in 0 ..< PROFILE_COUNT {if fixture(i).id == id {return i}}
	return -1
}
dirty :: proc(s: ^State) -> bool {
	i := profile_index(s.selected_id)
	return i >= 0 && s.draft != s.applied[i]
}
reduce :: proc(s: ^State, a: Action) -> Result {
	i := profile_index(s.selected_id)
	if i < 0 ||
	   !valid_values(s.draft) ||
	   (s.active_tab != "general" && s.active_tab != "appearance") ||
	   s.dialog < .None ||
	   s.dialog > .Reset ||
	   s.trace_count < 0 ||
	   s.trace_count > TRACE_CAPACITY ||
	   s.trace_next < 0 ||
	   s.trace_next >= TRACE_CAPACITY ||
	   s.revision == max(u64) {return {error = .Invalid_State}}
	for v in s.applied {if !valid_values(v) {return {error = .Invalid_State}}}
	if s.dialog == .Dirty_Departure {
		if profile_index(s.pending_id) < 0 ||
		   s.pending_id == s.selected_id {return {error = .Invalid_State}}
	} else if s.pending_id != "" {return {error = .Invalid_State}}
	if a.sequence != 0 && a.sequence <= s.last_sequence {return {error = .Duplicate_Intent}}
	if s.dialog != .None &&
	   a.kind != .Dialog_Result &&
	   a.kind != .Escape {return {error = .Blocked_By_Dialog}}
	next := s^
	#partial switch a.kind {
	case .Show_Help:
		next.draft.show_help = a.checked
	case .Enabled:
		next.draft.enabled = a.checked
	case .Mode:
		mode, ok := canonical_mode(a.id); if !ok {return {error = .Invalid_ID}}
		next.draft.mode = mode
	case .Tab:
		if a.id ==
		   "general" {next.active_tab = "general"} else if a.id == "appearance" {next.active_tab = "appearance"} else {return {error = .Invalid_ID}}
	case .Intensity:
		if a.value < 0 || a.value > 100 {return {error = .Invalid_Value}}
		next.draft.intensity = a.value
	case .Apply:
		next.applied[i] = next.draft
	case .Cancel:
		next.draft = next.applied[i]
	case .Select_Profile:
		j := profile_index(a.id)
		if j < 0 {return {error = .Invalid_ID}}
		if i == j {return {}}
		if dirty(s) {
			next.dialog = .Dirty_Departure; next.pending_id = fixture(j).id
		} else {next.selected_id = fixture(j).id; next.draft = next.applied[j]}
	case .Request_Reset:
		next.dialog = .Reset
	case .Escape, .Dialog_Result:
		if s.dialog == .None {return {error = .Unavailable}}
		if s.dialog == .Dirty_Departure {
			if a.kind == .Escape || a.id == "stay" {
				// Preserve selected/draft/applied.
			} else if a.id == "apply-and-go" || a.id == "discard-and-go" {
				if a.id == "apply-and-go" {next.applied[i] = next.draft}
				j := profile_index(next.pending_id)
				next.selected_id = fixture(j).id; next.draft = next.applied[j]
			} else {return {error = .Invalid_ID}}
		} else {
			if a.kind == .Escape || a.id == "cancel" {
			} else if a.id == "reset" {next.draft = fixture(i).initial
			} else {return {error = .Invalid_ID}}
		}
		next.dialog = .None; next.pending_id = ""
	case:
		return {error = .Unavailable}
	}
	if next == s^ && a.sequence == 0 {return {}}
	next.revision += 1
	if a.sequence != 0 {next.last_sequence = a.sequence}
	next.trace[next.trace_next] = {
		a.kind,
		a.source,
		next.selected_id,
		a.sequence,
		a.frame_id,
		next.revision,
	}
	next.trace_next = (next.trace_next + 1) % TRACE_CAPACITY
	next.trace_count = min(next.trace_count + 1, TRACE_CAPACITY)
	s^ = next
	return {changed = true}
}

@(private)
canonical_mode :: proc(id: string) -> (string, bool) {
	if id == "calm" {return "calm", true}
	if id == "normal" {return "normal", true}
	if id == "vivid" {return "vivid", true}
	return "", false
}
@(private)
valid_values :: proc(v: Values) -> bool {
	_, ok := canonical_mode(v.mode)
	return ok && v.intensity >= 0 && v.intensity <= 100
}
