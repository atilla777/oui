package collections_demo_model

import "core:fmt"
import "core:strconv"

CAPACITY :: 10000
Mode :: enum {
	List,
	Grid,
}
State :: struct {
	order:                                [CAPACITY]int,
	count, selected:                      int,
	mode:                                 Mode,
	revision, reset_epoch, last_sequence: u64,
}
create :: proc() -> State {
	s := State {
		count       = CAPACITY,
		revision    = 1,
		reset_epoch = 1,
	}
	for i in 0 ..< CAPACITY {s.order[i] = i + 1}
	return s
}
Action_Kind :: enum {
	Select,
	Reverse,
	Delete,
	Restore,
	Switch,
}
Action :: struct {
	kind:     Action_Kind,
	id:       string,
	sequence: u64,
}
Result :: struct {
	ok, changed: bool,
}
// Returned fixture strings belong to the caller's temporary allocator. State
// retains numeric identity only, so copying State cannot alias transient text.
item_id :: proc(value: int) -> string {return fmt.tprintf("item-%05d", value)}
identity :: proc(id: string) -> int {
	if len(id) != 10 || id[:5] != "item-" {return 0}
	for digit in id[5:] {if digit < '0' || digit > '9' {return 0}}
	n, ok := strconv.parse_int(id[5:])
	if !ok || n < 1 || n > CAPACITY {return 0}
	return n
}
contains :: proc(s: ^State, value: int) -> bool {
	for v in s.order[:s.count] {if v == value {return true}}
	return false
}
reduce :: proc(s: ^State, a: Action) -> Result {
	if s.count < 0 ||
	   s.count > CAPACITY ||
	   s.revision == max(u64) ||
	   (a.sequence != 0 && a.sequence <= s.last_sequence) {return {}}
	changed := false
	#partial switch a.kind {
	case .Select:
		v := identity(a.id)
		if v == 0 || !contains(s, v) {return {}}
		changed = v != s.selected; s.selected = v
	case .Reverse:
		for i in 0 ..< s.count / 2 {j := s.count - i - 1; s.order[i], s.order[j] = s.order[j], s.order[i]}
		changed = s.count > 1
	case .Delete:
		if s.selected == 0 || !contains(s, s.selected) {return {}}
		for i in 0 ..< s.count {if s.order[i] == s.selected {
				copy(s.order[i:s.count - 1], s.order[i + 1:s.count]); break
			}}
		s.count -= 1; s.order[s.count] = 0; s.selected = 0; changed = true
	case .Restore:
		if s.reset_epoch == max(u64) {return {}}
		for i in 0 ..< CAPACITY {s.order[i] = i + 1}
		s.count = CAPACITY; s.selected = 0; s.reset_epoch += 1; changed = true
	case .Switch:
		s.mode = .Grid if s.mode == .List else .List; changed = true
	case:
		return {}
	}
	if a.sequence != 0 {s.last_sequence = a.sequence}
	if changed {s.revision += 1}
	return {ok = true, changed = changed}
}
