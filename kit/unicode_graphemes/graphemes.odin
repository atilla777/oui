package unicode_graphemes

import "core:mem"
import "core:unicode/utf8"

UNICODE_VERSION :: "15.1.0"

Invalid_UTF8 :: struct {
	byte_offset: int,
}
Boundaries_Result :: union {
	[]int,
	Invalid_UTF8,
}
Count_Result :: union {
	int,
	Invalid_UTF8,
}

// The returned slice is owned by allocator; caller deletes it with that allocator.
// Failure returns no partial offsets. Input bytes are only borrowed during the call.
boundaries :: proc(
	text: string,
	allocator: mem.Allocator = context.allocator,
) -> Boundaries_Result {
	offsets := make([dynamic]int, allocator)
	append(&offsets, 0)
	result := scan(text, &offsets)
	if error, failed := result.(Invalid_UTF8); failed {
		delete(offsets)
		return error
	}
	return offsets[:]
}

count :: proc(text: string) -> Count_Result {
	return scan(text, nil)
}

// Fallible sibling for owning UI preparation. Count first so scanning cannot
// grow the array; no allocator refusal is hidden or replaced by another source.
try_boundaries :: proc(
	text: string,
	allocator: mem.Allocator = context.allocator,
) -> (
	Boundaries_Result,
	mem.Allocator_Error,
) {
	result := count(text)
	if invalid, yes := result.(Invalid_UTF8); yes {return invalid, nil}
	n := result.(int)
	offsets, e := make([dynamic]int, 0, n + 1, allocator)
	if e != nil {return nil, e}
	append(&offsets, 0)
	scan(text, &offsets)
	return offsets[:], nil
}

@(private)
GCB :: enum u8 {
	Other,
	CR,
	LF,
	Control,
	Extend,
	ZWJ,
	Regional_Indicator,
	Prepend,
	SpacingMark,
	L,
	V,
	T,
	LV,
	LVT,
}
@(private)
InCB :: enum u8 {
	None,
	Consonant,
	Linker,
	Extend,
}
@(private)
GCB_Range :: struct {
	lo, hi: rune,
	value:  GCB,
}
@(private)
EP_Range :: struct {
	lo, hi: rune,
	value:  bool,
}
@(private)
InCB_Range :: struct {
	lo, hi: rune,
	value:  InCB,
}

@(private)
State :: struct {
	previous:          GCB,
	ri_odd:            bool,
	// Suffixes EP Extend* and EP Extend* ZWJ, respectively (GB11).
	ep_extend, ep_zwj: bool,
	// Suffix Consonant (Extend|Linker)*, with at least one Linker (GB9c).
	consonant, linked: bool,
}

@(private)
range_index :: proc(r: rune, ranges: []$T) -> int {
	lo, hi := 0, len(ranges)
	for lo < hi {
		mid := lo + (hi - lo) / 2
		if r < ranges[mid].lo {hi = mid
		} else if r > ranges[mid].hi {lo = mid + 1
		} else {return mid}
	}
	return -1
}

@(private)
properties :: proc(r: rune) -> (gcb: GCB, ep: bool, incb: InCB) {
	if i := range_index(r, gcb_ranges[:]); i >= 0 {gcb = gcb_ranges[i].value}
	if i := range_index(r, ep_ranges[:]); i >= 0 {ep = ep_ranges[i].value}
	if i := range_index(r, incb_ranges[:]); i >= 0 {incb = incb_ranges[i].value}
	return
}

@(private)
is_control :: proc(p: GCB) -> bool {
	return p == .Control || p == .CR || p == .LF
}

@(private)
break_before :: proc(s: State, next: GCB, ep: bool, incb: InCB) -> bool {
	p := s.previous
	if p == .CR && next == .LF {return false} 	// GB3
	if is_control(p) || is_control(next) {return true} 	// GB4, GB5 (before GB9)
	if p == .L && (next == .L || next == .V || next == .LV || next == .LVT) {return false} 	// GB6
	if (p == .LV || p == .V) && (next == .V || next == .T) {return false} 	// GB7
	if (p == .LVT || p == .T) && next == .T {return false} 	// GB8
	if next == .Extend || next == .ZWJ {return false} 	// GB9
	if next == .SpacingMark {return false} 	// GB9a
	if p == .Prepend {return false} 	// GB9b
	if incb == .Consonant && s.consonant && s.linked {return false} 	// GB9c
	if s.ep_zwj && ep {return false} 	// GB11
	if p == .Regional_Indicator && next == .Regional_Indicator && s.ri_odd {return false} 	// GB12/13
	return true // GB999
}

@(private)
advance :: proc(s: ^State, p: GCB, ep: bool, incb: InCB) {
	if p == .Regional_Indicator {s.ri_odd = !s.ri_odd
	} else {s.ri_odd = false}
	s.ep_zwj = p == .ZWJ && s.ep_extend
	s.ep_extend = ep || (p == .Extend && s.ep_extend)
	switch incb {
	case .Consonant:
		s.consonant, s.linked = true, false
	case .Linker:
		s.linked = s.consonant
	case .Extend: // Keep the candidate suffix.
	case .None:
		s.consonant, s.linked = false, false
	}
	s.previous = p
}

@(private)
scan :: proc(text: string, offsets: ^[dynamic]int) -> Count_Result {
	n := 0
	s: State
	for i := 0; i < len(text); {
		r, width := utf8.decode_rune(text[i:])
		if r == utf8.RUNE_ERROR && width == 1 {return Invalid_UTF8{i}}
		p, ep, incb := properties(r)
		if i == 0 || break_before(s, p, ep, incb) {
			n += 1
			if i != 0 && offsets != nil {append(offsets, i)}
		}
		advance(&s, p, ep, incb)
		i += width
	}
	if len(text) != 0 && offsets != nil {append(offsets, len(text))} 	// GB2
	return n
}
