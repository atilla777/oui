package ui_base

import "core:math"
import "core:mem"

ID :: string
Extent :: struct {
	w, h: f64,
}
Rect :: struct {
	x, y, w, h: f64,
}
Color :: [4]u8
finite :: proc(v: f64) -> bool {return !math.is_nan(v) && !math.is_inf(v)}
finite_nonnegative :: proc(v: f64) -> bool {return finite(v) && v >= 0}
snap :: proc(r: Rect, scale: f64) -> Rect {
	x, y := math.round(r.x * scale) / scale, math.round(r.y * scale) / scale
	return {
		x,
		y,
		math.round((r.x + r.w) * scale) / scale - x,
		math.round((r.y + r.h) * scale) / scale - y,
	}
}
intersection :: proc(a, b: Rect) -> Rect {
	x, y := max(a.x, b.x), max(a.y, b.y)
	return {x, y, max(0, min(a.x + a.w, b.x + b.w) - x), max(0, min(a.y + a.h, b.y + b.h) - y)}
}
contains :: proc(r: Rect, x, y: f64) -> bool {return(
		x >= r.x &&
		y >= r.y &&
		x < r.x + r.w &&
		y < r.y + r.h \
	)}

// Single UI thread. Owners are move-only by convention; stamps borrow unless retained.
Lifetime :: struct {
	references: u64,
	alive:      bool,
	allocator:  mem.Allocator,
}
Frame_Stamp :: struct {
	lifetime:                          ^Lifetime,
	attempt, model_revision, sequence: u64,
}
Publication :: struct {
	lifetime:                          ^Lifetime,
	attempt, model_revision, sequence: u64,
	published:                         Frame_Stamp,
	ready, committing:                 bool,
}
Publication_Error :: enum {
	None,
	Allocation,
	Exhausted,
	Invalid,
	Stale,
	Reentry,
}
create :: proc(a: mem.Allocator) -> (Publication, Publication_Error) {
	life, e := new(Lifetime, a)
	if e != nil {return {}, .Allocation}
	life^ = {1, true, a}
	return {lifetime = life}, .None
}
retain :: proc(s: Frame_Stamp) -> bool {
	if s.lifetime == nil || s.lifetime.references == max(u64) {return false}
	s.lifetime.references += 1
	return true
}
release :: proc(s: Frame_Stamp) {
	if s.lifetime == nil {return}
	life := s.lifetime
	life.references -= 1
	if life.references == 0 {free(life, life.allocator)}
}
destroy :: proc(p: ^Publication) {
	if p.lifetime != nil {p.lifetime.alive = false; release({lifetime = p.lifetime})}
	p^ = {}
}
begin_attempt :: proc(p: ^Publication, revision: u64) -> (Frame_Stamp, Publication_Error) {
	if p.committing {return {}, .Reentry}
	p.ready = false
	if p.lifetime == nil || !p.lifetime.alive {return {}, .Invalid}
	if p.attempt == max(u64) {return {}, .Exhausted}
	p.attempt += 1
	p.model_revision = revision
	return {p.lifetime, p.attempt, revision, p.sequence}, .None
}
validate :: proc(p: ^Publication, s: Frame_Stamp) -> Publication_Error {
	if p.lifetime == nil ||
	   s.lifetime != p.lifetime ||
	   !p.lifetime.alive ||
	   s.attempt == 0 ||
	   s.attempt != p.attempt ||
	   s.model_revision != p.model_revision ||
	   s.sequence != p.sequence {return .Stale}
	return .None
}
enter_commit :: proc(p: ^Publication, s: Frame_Stamp) -> Publication_Error {
	if p.committing {return .Reentry}
	if p.published == s {return .Stale}
	if e := validate(p, s); e != .None {return e}
	p.committing = true
	return .None
}
finish_commit :: proc(p: ^Publication, s: Frame_Stamp) {p.published = s; p.committing = false
	p.ready = true}
is_current :: proc(p: ^Publication, s: Frame_Stamp) -> bool {return p.ready && p.published == s}
invalidate :: proc(p: ^Publication) {p.ready = false}
advance_sequence :: proc(p: ^Publication) -> Publication_Error {
	if p.committing {return .Reentry}
	p.ready = false
	if p.lifetime == nil || !p.lifetime.alive {return .Invalid}
	if p.sequence == max(u64) {return .Exhausted}
	p.sequence += 1
	return .None
}
