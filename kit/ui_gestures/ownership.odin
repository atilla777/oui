package ui_gestures
import "core:mem"
import "core:strings"
@(private)
destroy_description :: proc(d: ^Description, a: mem.Allocator) {
	for v in ([]string{d.id, d.node_id, d.scope_id, d.payload_id, d.payload_type, d.scroll_id}) {delete(v, a)}
	for v in d.accept_types {delete(v, a)}; delete(d.accept_types, a); d^ = {}
}
@(private)
copy_description :: proc(d: Description, a: mem.Allocator) -> (Description, bool) {
	r :=
		d; r.id, r.node_id, r.scope_id, r.payload_id, r.payload_type, r.scroll_id = "", "", "", "", "", ""; r.accept_types = nil
	ok := false; defer {if !ok {destroy_description(&r, a)}}
	e: mem.Allocator_Error
	for pair in ([]struct {
			v:   string,
			dst: ^string,
		}{{d.id, &r.id}, {d.node_id, &r.node_id}, {d.scope_id, &r.scope_id}, {d.payload_id, &r.payload_id}, {d.payload_type, &r.payload_type}, {d.scroll_id, &r.scroll_id}}) {pair.dst^, e = strings.clone(pair.v, a); if e != nil {return {}, false}}
	r.accept_types, e = make([]string, len(d.accept_types), a); if e != nil {return {}, false}
	for v, j in d.accept_types {r.accept_types[j], e = strings.clone(v, a); if e != nil {return {}, false}}
	ok = true; return r, true
}
@(private)
destroy_live :: proc(l: ^Live, fallback: mem.Allocator) {
	a := l.allocator; if a.procedure == nil {a = fallback}
	destroy_description(&l.owner, a); delete(l.target_id, a)
	l^ = {}}
@(private)
copy_live :: proc(l: Live, a: mem.Allocator) -> (Live, bool) {
	r := l; r.owner, r.target_id = {}, ""; r.allocator = a
	ok: bool
	r.owner, ok = copy_description(l.owner, a); if !ok {return {}, false}
	id, e := strings.clone(
		l.target_id,
		a,
	); if e != nil {destroy_live(&r, a); return {}, false}; r.target_id = id
	return r, true
}
@(private)
rebind :: proc(r: ^Result, l: Live) {
	for j in 0 ..< r.count {r.signals[j].owner_id, r.signals[j].target_id = l.owner.id, l.target_id}
	if r.has_proposal {r.proposal.source_id, r.proposal.target_id, r.proposal.payload_id, r.proposal.payload_type = l.owner.id, l.target_id, l.owner.payload_id, l.owner.payload_type}
}
@(private)
compatible :: proc(a, b: Description) -> bool {
	if a.id != b.id ||
	   a.node_id != b.node_id ||
	   a.scope_id != b.scope_id ||
	   a.kind != b.kind ||
	   a.payload_id != b.payload_id ||
	   a.payload_type != b.payload_type ||
	   a.scroll_id != b.scroll_id ||
	   a.step != b.step ||
	   a.delay_ms != b.delay_ms ||
	   a.interval_ms != b.interval_ms ||
	   len(a.accept_types) != len(b.accept_types) {return false}
	for v, j in a.accept_types {if v != b.accept_types[j] {return false}}; return true
}
