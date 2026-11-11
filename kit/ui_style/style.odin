package ui_style

import base "../ui_base"
import layout "../ui_layout"

Color :: base.Color
Extent :: base.Extent
Rect :: base.Rect
Insets :: layout.Insets
Scale_Mode :: layout.Scale_Mode
finite_nonnegative :: base.finite_nonnegative
snap :: base.snap
// Semantic styling role is an application-provided key, not a layout node kind.
Role :: string
Visual_State :: enum {
	Normal,
	Selected,
	Hovered,
	Pressed,
	Focused,
	Disabled,
}
State_Mask :: bit_set[Visual_State]
Paint_Property :: enum {
	Foreground,
	Background,
	Border,
	Border_Width,
	Focus_Color,
	Focus_Width,
	Font,
	Font_Size,
	Image,
	Radius,
}
Font_ID :: struct {
	id: string,
}
Image_ID :: struct {
	id: string,
}
Token_Ref :: struct {
	id: string,
}
Image_Off :: struct {}
Paint_Value :: union {
	Color,
	f64,
	Font_ID,
	Image_ID,
	Token_Ref,
	Image_Off,
}
Declaration :: struct {
	property: Paint_Property,
	value:    Paint_Value,
}
State_Style :: struct {
	states: [Visual_State][]Declaration,
}
Named_Style :: struct {
	id:    string,
	style: State_Style,
}
Role_Style :: struct {
	role:  Role,
	style: State_Style,
}
Paint_Token :: struct {
	id:    string,
	value: Paint_Value,
}
Theme :: struct {
	revision: string,
	roles:    []Role_Style,
	styles:   []Named_Style,
	tokens:   []Paint_Token,
}
Appearance :: struct {
	style_id: string,
	local:    State_Style,
}
Cascade_Level :: enum {
	Default,
	Theme,
	Named,
	Local,
}
Provenance :: struct {
	level:              Cascade_Level,
	style_id, token_id: string,
	state:              Visual_State,
	fallback:           bool,
}
Computed_Property :: struct {
	value:      Paint_Value,
	provenance: Provenance,
}
Computed_Appearance :: [Paint_Property]Computed_Property
Visual_Kind :: enum {
	Role,
	Rectangle,
	Rounded_Rectangle,
	Line,
	Border,
	Ellipse,
	Triangle,
	Polygon,
	Image,
}
Visual :: struct {
	kind:      Visual_Kind,
	intrinsic: Maybe(Extent),
	points:    [][2]f64,
}
Slice_Mode :: enum {
	Stretch,
	Repeat,
}
Nine_Slice_Metadata :: struct {
	border:                    [4]int,
	texture_scale:             f64,
	edges, center_x, center_y: Slice_Mode,
	omit_center:               bool,
	padding:                   Maybe(Insets),
}
Image_Metadata :: struct {
	id:         string,
	source:     Extent,
	nine_slice: Maybe(Nine_Slice_Metadata),
}
Resource_Catalog :: struct {
	revision: string,
	images:   []Image_Metadata,
}

valid_paint_value :: proc(property: Paint_Property, value: Paint_Value) -> bool {
	switch property {
	case .Foreground, .Background, .Border, .Focus_Color:
		_, ok := value.(Color); return ok
	case .Border_Width, .Focus_Width, .Font_Size, .Radius:
		v, ok := value.(f64)
		return ok && finite_nonnegative(v) && (property != .Font_Size || v > 0)
	case .Font:
		v, ok := value.(Font_ID); return ok && v.id != ""
	case .Image:
		if v, ok := value.(Image_ID); ok {return v.id != ""}
		_, ok := value.(Image_Off); return ok
	}
	return false
}
valid_state_style :: proc(style: State_Style, theme: Theme) -> bool {
	for state in Visual_State {for d, i in style.states[state] {
			if d.property < .Foreground || d.property > .Radius {return false}
			if state != .Normal && (d.property == .Font || d.property == .Font_Size) {return false}
			for prior in style.states[state][:i] {if prior.property == d.property {return false}}
			if ref, ok := d.value.(Token_Ref); ok {
				if ref.id == "" {return false}
				for token in theme.tokens {if token.id == ref.id && !valid_paint_value(d.property, token.value) {return false}}
			} else if !valid_paint_value(d.property, d.value) {return false}
		}}
	return true
}
valid_image_metadata :: proc(image: Image_Metadata) -> bool {
	if !finite_nonnegative(image.source.w) ||
	   !finite_nonnegative(image.source.h) ||
	   image.source.w == 0 ||
	   image.source.h == 0 {return false}
	if nine, ok := image.nine_slice.?; ok {
		for mode in ([3]Slice_Mode{nine.edges, nine.center_x, nine.center_y}) {if mode != .Stretch && mode != .Repeat {return false}}
		for b in nine.border {if b < 0 {return false}}
		if !finite_nonnegative(nine.texture_scale) || nine.texture_scale == 0 {return false}
		if f64(nine.border[0]) + f64(nine.border[2]) > image.source.w ||
		   f64(nine.border[1]) + f64(nine.border[3]) > image.source.h {return false}
		x := image.source.w - f64(nine.border[0]) - f64(nine.border[2])
		y := image.source.h - f64(nine.border[1]) - f64(nine.border[3])
		for v in ([4]f64{(f64(nine.border[0]) + f64(nine.border[2])) * nine.texture_scale, (f64(nine.border[1]) + f64(nine.border[3])) * nine.texture_scale, x * nine.texture_scale, y * nine.texture_scale}) {if !finite_nonnegative(v) {return false}}
		if (nine.edges == .Repeat && (x <= 0 || y <= 0)) ||
		   (!nine.omit_center &&
				   ((nine.center_x == .Repeat && x <= 0) ||
						   (nine.center_y == .Repeat && y <= 0))) {return false}
		if p, has := nine.padding.?;
		   has {for v in ([4]f64{p.left, p.top, p.right, p.bottom}) {if !finite_nonnegative(v) {return false}}}
	}
	return true
}

// Borrowed pure cascade, used only synchronously. prepare below materializes it.
resolve_appearance :: proc(
	role: Role,
	appearance: Appearance,
	theme: Theme,
	states: State_Mask,
) -> Computed_Appearance {
	r := Computed_Appearance {
		.Foreground   = {Color{240, 240, 240, 255}, {}},
		.Background   = {Color{32, 32, 32, 255}, {}},
		.Border       = {Color{180, 180, 180, 255}, {}},
		.Border_Width = {f64(1), {}},
		.Focus_Color  = {Color{255, 255, 255, 255}, {}},
		.Focus_Width  = {f64(2), {}},
		.Font         = {Font_ID{"default"}, {}},
		.Font_Size    = {f64(16), {}},
		.Image        = {Image_Off{}, {}},
		.Radius       = {f64(0), {}},
	}
	states := states
	if .Disabled in states {states -= {.Hovered, .Pressed}}
	for e in theme.roles {if e.role == role {apply_style(&r, e.style, .Theme, "", theme, states)}}
	if appearance.style_id != "" {
		found := false
		for e in theme.styles {if e.id == appearance.style_id {found = true; apply_style(&r, e.style, .Named, e.id, theme, states); break}}
		if !found {for &p in r {p.provenance.fallback = true}}
	}
	apply_style(&r, appearance.local, .Local, "", theme, states)
	return r
}
apply_style :: proc(
	result: ^Computed_Appearance,
	style: State_Style,
	level: Cascade_Level,
	style_id: string,
	theme: Theme,
	states: State_Mask,
) {
	for state in Visual_State {
		if state != .Normal && state not_in states {continue}
		for d in style.states[state] {
			value := d.value
			origin := Provenance {
				level    = level,
				style_id = style_id,
				state    = state,
			}
			if ref, ok := value.(Token_Ref); ok {
				found := false
				for token in theme.tokens {if token.id == ref.id {value = token.value; found = true; break}}
				if !found {result[d.property].provenance.fallback = true; continue}
				origin.token_id = ref.id
			}
			result[d.property] = {value, origin}
		}
	}
}
