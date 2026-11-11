package sections

import model "../model"
import "core:fmt"
import tr "ui:translations"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"
import rich "ui:ui_rich"
import style "ui:ui_style"
import text "ui:ui_text"
import graphemes "ui:unicode_graphemes"

Content :: struct {
	theme:              style.Theme,
	roles:              [1]style.Role_Style,
	named:              [1]style.Named_Style,
	tokens:             [1]style.Paint_Token,
	role_declarations:  [4]style.Declaration,
	named_declarations: [4]style.Declaration,
	nodes:              [64]layout.Node,
	texts:              [32]text.Text_Node,
	targets:            [16]interaction.Target,
	styles:             [64]style.Description,
	n, nt, ni, ns:      int,
	declarations:       [16][8]style.Declaration,
	points:             [5][2]f64,
	triangle:           [3][2]f64,
	rich:               [2]rich.Description,
	nr:                 int,
	buffer:             [256]u8,
	metadata_buffer:    [256]u8,
	consumer_count:     int,
	consumer_violated:  bool,
}
add :: proc(c: ^Content, id, parent: string, kind: layout.Kind, l: layout.Layout) {
	c.nodes[c.n] = {
		id      = id,
		parent  = parent,
		role    = kind,
		layout  = l,
		enabled = true,
		visible = true,
	}; c.n += 1
}
content_label :: proc(
	c: ^Content,
	id, parent, value: string,
	l: layout.Layout,
	options: text.Text_Options = {},
) {
	add(c, id, parent, .Content, l); c.texts[c.nt] = {id, value, {"own"}, 14, options}; c.nt += 1
}
content_button :: proc(c: ^Content, id, parent, value: string) {
	label(
		c,
		id,
		parent,
		value,
		{x = {mode = .Content}, y = {mode = .Fixed, value = 24}, padding = {3, 1, 3, 1}},
	)
	c.targets[c.ni] = {id, "button", true, true}; c.ni += 1
}

TEXT_RU :: "Основа отрисовки текста\nЦелые строки переносятся по доступной ширине.\n\nПустая строка сохраняет свою область.\né Вперёд Вперёд Вперёд Вперёд …\n"
TEXT_EN :: "Text rendering foundation\nWhole lines wrap inside the available width.\n\nThe empty line reserves its own box.\né Go Go Go Go …\n"
SHORT_RU :: "Краткий текст: é Вперёд …\n"
SHORT_EN :: "Short text: é Forward …\n"
PROBE_RU :: "Вперёд Вперёд\n"
PROBE_EN :: "Forward Forward\n"
RICH_RU :: "Это [b]карточка [color=#ffd260ff]с выделением[/color][/b]: [size=24]крупный текст[/size], [i]курсив[/i] и [u]подчёркивание[/u]. Значок  и [img id=\"star\" alt=\"золотая звезда\" w=28 h=28/] — часть целой строки. Поставляемый запасной шрифт: α Ω ά ∞; комбинируемый знак: á. При изменении ширины изображение переносится целиком, а следующий элемент следует за абзацем.\n"
RICH_EN :: "This is a [b]card [color=#ffd260ff]with emphasis[/color][/b]: [size=24]large text[/size], [i]italic[/i] and [u]underline[/u]. The icon  and [img id=\"star\" alt=\"golden star\" w=28 h=28/] belong to one complete string. Bundled fallback font: α Ω ά ∞; combining mark: á. Changing the width moves the image as one object, and the next element follows the paragraph.\n"

compose_content :: proc(c: ^Content, m: model.Model, atlas: []style.Atlas_Region = nil) -> bool {
	en := m.locale == .English
	if m.page == .Layout && m.layout_details {
		add(
			c,
			"layout/constraints",
			"root",
			.Column,
			{
				x = {mode = .Fill},
				y = {mode = .Fixed, value = 174},
				gap = 8,
				padding = {4, 4, 4, 4},
				overflow = .Clip,
			},
		)
		add(
			c,
			"layout/sizes",
			"layout/constraints",
			.Row,
			{
				x = {mode = .Fill},
				y = {mode = .Fixed, value = 54},
				padding = {4, 4, 4, 4},
				gap = 4,
				align = .Center,
				justify = .SpaceBetween,
			},
		)
		label(
			c,
			"layout/fixed",
			"layout/sizes",
			"Fixed",
			{
				x = {mode = .Fixed, value = 120, min = 80, max = 160},
				y = {mode = .Content},
				grow = 1,
				shrink = 1,
				margin = {2, 2, 2, 2},
			},
		)
		label(
			c,
			"layout/percent",
			"layout/sizes",
			"30 percent",
			{
				x = {mode = .Percent, value = 0.3, min = 60, max = 200},
				y = {mode = .Content},
				shrink = 1,
			},
		)
		label(
			c,
			"layout/content",
			"layout/sizes",
			"Content",
			{
				x = {mode = .Content, min = 24, max = 200},
				y = {mode = .Content},
				grow = 2,
				shrink = 1,
			},
		)
		label(
			c,
			"layout/fill",
			"layout/sizes",
			"Fill",
			{x = {mode = .Fill, min = 32, max = 300}, y = {mode = .Content}},
		)
		add(
			c,
			"layout/alignment",
			"layout/constraints",
			.Row,
			{
				x = {mode = .Fill},
				y = {mode = .Fixed, value = 54},
				gap = 8,
				align = .End,
				justify = .Center,
			},
		)
		label(
			c,
			"layout/align-start",
			"layout/alignment",
			"Start",
			{
				x = {mode = .Fixed, value = 80},
				y = {mode = .Fixed, value = 20},
				align_self = .Start,
			},
		)
		label(
			c,
			"layout/align-center",
			"layout/alignment",
			"Center",
			{
				x = {mode = .Fixed, value = 80},
				y = {mode = .Fixed, value = 20},
				align_self = .Center,
			},
		)
		label(
			c,
			"layout/align-end",
			"layout/alignment",
			"End",
			{x = {mode = .Fixed, value = 80}, y = {mode = .Fixed, value = 20}},
		)
		label(
			c,
			"layout/constraint-label",
			"layout/constraints",
			"min/max | grow/shrink | margin/padding/gap | align/justify",
			{x = {mode = .Fill}, y = {mode = .Content}},
			{wrap = .WordWrap},
		)
	}
	if m.page == .Text {
		catalog, ok := tr.init(
			[]string{"ru", "en"},
			[]tr.Entry {
				{"text.foundation", {TEXT_RU, TEXT_EN}},
				{"text.short", {SHORT_RU, SHORT_EN}},
				{"text.probe", {PROBE_RU, PROBE_EN}},
			},
		).(tr.Catalog)
		if !ok {return false}
		locale := "ru"; if en {locale = "en"}; key := "text.foundation"; if m.text.short {key = "text.short"}
		value, found := tr.lookup(catalog, key, locale).(string); if !found {return false}
		probe, pok := tr.lookup(catalog, "text.probe", locale).(string); if !pok {return false}
		key_label, limit_label :=
			"Ключ normal / short",
			"Случай лимита"; if en {key_label, limit_label = "Key normal / short", "Limit fixture"}
		add(c, "text/actions", "root", .Row, {x = {mode = .Fill}, y = {mode = .Content}, gap = 8})
		button(
			c,
			"text/key",
			"text/actions",
			key_label,
		); button(c, "text/limit", "text/actions", limit_label)
		label(
			c,
			"text/paragraph",
			"root",
			value,
			{x = {mode = .Fill}, y = {mode = .Content}},
			{wrap = .WordWrap},
		)
		add(
			c,
			"text/specimens",
			"root",
			.Row,
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 32}, gap = 6},
		)
		for id, i in ([2]string{"text/clip", "text/ellipsis"}) {label(c, id, "text/specimens", value, {x = {mode = .Fill}, y = {mode = .Fill}}, {wrap = .WordWrap, overflow = text.Text_Overflow(i), max_lines = 1, overflow_expected = true})}
		add(
			c,
			"text/alignments",
			"root",
			.Row,
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 32}, gap = 6},
		)
		alignment := "Вперёд Вперёд"; if en {alignment = "Forward Forward"}
		for id, i in ([2]string{"text/center", "text/right"}) {label(c, id, "text/alignments", alignment, {x = {mode = .Fill}, y = {mode = .Fill}}, {horizontal = text.Text_Horizontal(i + 1), vertical = text.Text_Vertical(i + 1), overflow_expected = true})}
		width := layout.Axis_Size {
			mode = .Fill,
		}; if m.text.limit_fixture >= 2 {width = {
				mode  = .Fixed,
				value = 30,
			}}
		label(
			c,
			"text/probe",
			"root",
			probe,
			{x = width, y = {mode = .Content}},
			{overflow = .Clip, overflow_expected = m.text.limit_fixture >= 2},
		)
		count, counted := graphemes.count(
			probe,
		).(int); if !counted {return false}; c.consumer_count = count; c.consumer_violated = m.text.limit_fixture % 2 == 1 && count > 0
		limit := "none"; if !en {limit = "нет"}; if m.text.limit_fixture % 2 == 1 {limit = "0"}
		report := fmt.bprintf(
			c.buffer[:],
			"%s | text.probe EGC=%d | Unicode 15.1 | case=%d | exceeded=%t | limit=%s" if en else "%s | text.probe EGC=%d | Unicode 15.1 | случай=%d | превышение=%t | лимит=%s",
			key,
			count,
			m.text.limit_fixture,
			c.consumer_violated,
			limit,
		)
		label(
			c,
			"text/report",
			"root",
			report,
			{x = {mode = .Fill}, y = {mode = .Content}},
			{wrap = .WordWrap},
		)
	}
	if m.page == .Rich_Text {
		caption, following :=
			"Одна строка с многоточием",
			"Этот элемент следует за абзацем."; source := RICH_RU
		if en {caption, following, source = "One line with ellipsis", "This element follows the paragraph.", RICH_EN}
		button(c, "rich/limit", "root", caption)
		label(
			c,
			"rich/combined-label",
			"root",
			"C07: rich + custom circle + frozen transition (click circle)" if en else "C07: rich + custom круг + frozen transition (нажмите круг)",
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 28}},
			{},
		)
		add(
			c,
			"rich/circle",
			"root",
			.Box,
			{x = {mode = .Fixed, value = 72}, y = {mode = .Fixed, value = 72}},
		)
		c.targets[c.ni] = {"rich/circle", "button", true, true}; c.ni += 1
		for id, i in ([2]string{"rich/card", "rich/ellipsis"}) {
			add(c, id, "root", .Content, {x = {mode = .Fill}, y = {mode = .Content}})
			o := text.Text_Options {
				wrap = .WordWrap,
			}; if i == 1 ||
			   m.rich.ellipsis {o.overflow = .Ellipsis; o.max_lines = 1; o.overflow_expected = true}
			c.rich[i] = {
				id = id,
				source = source,
				base_style = {font_id = "own", size = 16, color = {240, 240, 240, 255}},
				options = o,
			}; c.nr += 1
			if i ==
			   0 {label(c, "rich/following", "root", following, {x = {mode = .Fill}, y = {mode = .Content}}, {wrap = .WordWrap})}
		}
	}
	if m.page == .Styling {
		accent := style.Color{60, 130, 230, 255}; if m.styling.dark {accent = {180, 70, 210, 255}}
		c.tokens[0] = {"accent", accent}
		c.role_declarations = {
			{.Font, style.Font_ID{"own"}},
			{.Font_Size, f64(14)},
			{.Background, style.Token_Ref{"accent"}},
			{.Foreground, style.Color{240, 240, 240, 255}},
		}
		c.named_declarations = {
			{.Border, style.Color{240, 210, 110, 255}},
			{.Border_Width, f64(2)},
			{.Focus_Color, style.Color{255, 218, 110, 255}},
			{.Focus_Width, f64(3)},
		}
		c.roles[0].role = "sample"; c.roles[0].style.states[.Normal] = c.role_declarations[:]
		c.named[0].id = "sample-override"; c.named[0].style.states[.Normal] = c.named_declarations[:]
		colors := [5]style.Color {
			{220, 170, 40, 255},
			{50, 180, 190, 255},
			{200, 70, 60, 255},
			{70, 130, 70, 255},
			{85, 85, 85, 255},
		}
		for state, i in ([5]style.Visual_State{.Selected, .Hovered, .Pressed, .Focused, .Disabled}) {c.declarations[9 + i][0] = {.Background, colors[i]}; c.roles[0].style.states[state] = c.declarations[9 + i][:1]}
		c.theme = {
			revision = "showcase-theme",
			roles    = c.roles[:],
			styles   = c.named[:],
			tokens   = c.tokens[:],
		}
		add(
			c,
			"styling/actions",
			"root",
			.Row,
			{x = {mode = .Fill}, y = {mode = .Content}, gap = 8},
		)
		words := [4]string {
			"Theme",
			"Selected",
			"Disabled",
			"Count",
		}; if !en {words = {"Тема", "Выбор", "Недоступность", "Счётчик"}}
		for id, i in ([4]string{"styling/theme", "styling/selected", "styling/disabled", "styling/count"}) {button(c, id, "styling/actions", words[i])}
		fallback := "Missing image"; if !en {fallback = "Нет ресурса"}; button(c, "styling/fallback", "styling/actions", fallback)
		for &n in c.nodes[:c.n] {if n.id == "styling/count" {n.enabled = !m.styling.disabled}}
		for &target in c.targets[:c.ni] {if target.id == "styling/count" {target.enabled = !m.styling.disabled}}
		add(
			c,
			"styling/palette",
			"root",
			.Row,
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 64}, gap = 8},
		)
		c.points = {{0, 0}, {1, 0}, {0.55, 0.5}, {1, 1}, {0, 1}}
		c.triangle = {{0, 1}, {0.5, 0}, {1, 1}}
		for id, i in ([9]string{"styling/rectangle", "styling/rounded", "styling/line", "styling/border", "styling/ellipse", "styling/triangle", "styling/polygon", "styling/image", "styling/panel"}) {
			add(
				c,
				id,
				"styling/palette",
				.Box,
				{x = {mode = .Fixed, value = 56}, y = {mode = .Fixed, value = 56}},
			)
			d := style.Description {
				id   = id,
				role = "sample",
			}; d.visual.intrinsic = style.Extent {
				56,
				56,
			}; d.visual.kind = style.Visual_Kind(i + 1); if i == 8 {d.visual.kind = .Role}
			c.declarations[i][0] = {
				.Radius,
				f64(8),
			}; d.appearance.style_id = "sample-override"; d.appearance.local.states[.Normal] = c.declarations[i][:1]
			if i ==
			   0 {c.declarations[i][1] = {.Background, style.Color{40, 100, 160, 255}}; d.appearance.local.states[.Normal] = c.declarations[i][:2]}
			if i == 6 {d.visual.points = c.points[:]}
			if i == 5 {d.visual.points = c.triangle[:]}
			if i ==
			   7 {image := "icon"; if m.styling.missing_image {image = "absent"}; c.declarations[i][1] = {.Image, style.Image_ID{image}}; d.appearance.local.states[.Normal] = c.declarations[i][:2]}
			if m.styling.selected {d.states += {.Selected}}
			if m.styling.disabled {d.states += {.Disabled}}
			c.styles[c.ns] = d; c.ns += 1
		}
		c.styles[c.ns] = {
			id = "styling/count",
			role = "sample",
			appearance = {style_id = "sample-override"},
		}; if m.styling.selected {c.styles[c.ns].states += {.Selected}}; c.ns += 1
		label(
			c,
			"styling/status",
			"root",
			fmt.bprintf(
				c.buffer[:],
				"count=%d | selected=%t | disabled=%t" if en else "Счётчик=%d | выбор=%t | недоступно=%t",
				m.styling.count,
				m.styling.selected,
				m.styling.disabled,
			),
			{x = {mode = .Fill}, y = {mode = .Content}},
			{wrap = .WordWrap},
		)
	}
	if m.page == .Atlas {
		fg, bg :=
			style.Color{20, 25, 35, 255},
			style.Color{235, 240, 245, 255}; focus := style.Color{0, 0, 0, 255}
		if m.atlas.dark {fg, bg, focus = style.Color{240, 243, 250, 255}, style.Color{20, 25, 38, 255}, style.Color{255, 225, 0, 255}}
		add(
			c,
			"atlas/body",
			"root",
			.Column,
			{
				x = {mode = .Fill},
				y = {mode = .Fill},
				gap = 8,
				padding = {6, 6, 6, 6},
				overflow = .Clip,
			},
		)
		c.declarations[5][0], c.declarations[5][1], c.declarations[5][2], c.declarations[5][3] =
			{.Background, bg},
			{.Foreground, fg},
			{.Font, style.Font_ID{"own"}},
			{.Font_Size, f64(14)}
		c.styles[c.ns] = {
			id = "atlas/body",
		}; c.styles[c.ns].appearance.local.states[.Normal] = c.declarations[5][:4]; c.ns += 1
		add(
			c,
			"atlas/actions",
			"atlas/body",
			.Row,
			{x = {mode = .Fill}, y = {mode = .Content}, gap = 8},
		)
		words := [5]string {
			"A / B",
			"Reload",
			"Selected",
			"Disabled",
			"Count",
		}; if !en {words = {"A / B", "Перезагрузить", "Выбор", "Недоступность", "Счётчик"}}
		for id, i in ([5]string{"atlas/assets", "atlas/reload", "atlas/selected", "atlas/disabled", "atlas/count"}) {button(c, id, "atlas/actions", words[i])}
		theme := "Theme"; if !en {theme = "Тема"}; button(c, "atlas/theme", "atlas/actions", theme)
		add(
			c,
			"atlas/panel",
			"atlas/body",
			.Column,
			{
				x = {mode = .Fill},
				y = {mode = .Fixed, value = 100},
				padding = {8, 8, 8, 8},
				gap = 4,
			},
		)
		pivot :=
			[2]f64{}; for region in atlas {if region.image.id == "info" {if v, has := region.pivot.?; has {pivot = v}}}
		label(
			c,
			"atlas/metadata",
			"atlas/body",
			fmt.bprintf(
				c.metadata_buffer[:],
				"info pivot=(%g,%g) | regions=%d | manifest v1",
				pivot[0],
				pivot[1],
				len(atlas),
			),
			{x = {mode = .Fill}, y = {mode = .Content}},
		)
		add(
			c,
			"atlas/slices",
			"atlas/body",
			.Row,
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 60}, gap = 8},
		)
		for id, i in ([4]string{"atlas/button", "atlas/stretch", "atlas/repeat", "atlas/empty"}) {
			add(
				c,
				id,
				"atlas/slices",
				.Box,
				{x = {mode = .Fixed, value = 132}, y = {mode = .Fixed, value = 42}},
			)
			images := [4]string {
				"button",
				"slice-stretch",
				"slice-repeat",
				"slice-empty",
			}; image := images[i]
			c.declarations[i][0] = {.Image, style.Image_ID{image}}
			c.styles[c.ns] = {
				id = id,
				visual = {kind = .Image, intrinsic = style.Extent{32, 20}},
			}; c.styles[c.ns].appearance.local.states[.Normal] = c.declarations[i][:1]; c.ns += 1
			if i == 0 {
				c.targets[c.ni] = {
					id,
					"button",
					!m.atlas.disabled,
					true,
				}; c.ni += 1; c.nodes[c.n - 1].enabled = !m.atlas.disabled
				d := &c.styles[c.ns - 1]; d.role = "button"
				c.declarations[0][1], c.declarations[0][2], c.declarations[0][3], c.declarations[0][4], c.declarations[0][5] =
					{.Focus_Color, focus},
					{.Focus_Width, f64(2)},
					{.Background, style.Color{}},
					{.Border_Width, f64(0)},
					{.Font, style.Font_ID{"own"}}
				d.appearance.local.states[.Normal] = c.declarations[0][:6]
				states := [5]string {
					"button-selected",
					"button-hovered",
					"button-pressed",
					"button-focused",
					"button-disabled",
				}
				for state, j in ([5]style.Visual_State{.Selected, .Hovered, .Pressed, .Focused, .Disabled}) {c.declarations[6 + j][0] = {.Image, style.Image_ID{states[j]}}; d.appearance.local.states[state] = c.declarations[6 + j][:1]}
				if m.atlas.selected {d.states += {.Selected}}
			}
		}
		c.declarations[4][0] = {.Image, style.Image_ID{"panel"}}
		c.styles[c.ns] = {
			id = "atlas/panel",
		}; c.styles[c.ns].appearance.local.states[.Normal] = c.declarations[4][:1]; c.ns += 1
		add(
			c,
			"atlas/pivot-area",
			"atlas/body",
			.Absolute,
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 64}},
		)
		add(
			c,
			"atlas/pivot-sample",
			"atlas/pivot-area",
			.Box,
			{
				x = {mode = .Fixed, value = 32},
				y = {mode = .Fixed, value = 32},
				anchor = {0.5, 0.5},
				pivot = pivot,
			},
		)
		c.declarations[11][0] = {.Image, style.Image_ID{"info"}}; c.styles[c.ns] = {
			id = "atlas/pivot-sample",
			visual = {kind = .Image, intrinsic = style.Extent{32, 32}},
		}; c.styles[c.ns].appearance.local.states[.Normal] = c.declarations[11][:1]; c.ns += 1
		add(
			c,
			"atlas/pivot-marker",
			"atlas/pivot-area",
			.Box,
			{x = {mode = .Fixed, value = 2}, y = {mode = .Fixed, value = 2}, anchor = {0.5, 0.5}},
		)
		c.declarations[12][0] = {.Background, style.Color{255, 170, 20, 255}}; c.styles[c.ns] = {
			id = "atlas/pivot-marker",
		}; c.styles[c.ns].appearance.local.states[.Normal] = c.declarations[12][:1]; c.ns += 1
		label(
			c,
			"atlas/status",
			"atlas/body",
			fmt.bprintf(
				c.buffer[:],
				"count=%d | B=%t | reload=%d | selected=%t | disabled=%t" if en else "Счётчик=%d | B=%t | reload=%d | выбор=%t | недоступно=%t",
				m.atlas.count,
				m.atlas.alternate,
				m.atlas.reload,
				m.atlas.selected,
				m.atlas.disabled,
			),
			{x = {mode = .Fill}, y = {mode = .Content}},
		)
		c.texts[c.nt - 1].options.wrap = .WordWrap
		for id in ([2]string{"atlas/metadata", "atlas/status"}) {c.styles[c.ns] = {
				id = id,
			}; c.styles[c.ns].appearance.local.states[.Normal] = c.declarations[5][:4]; c.ns += 1}
		for &n in c.nodes[:c.n] {if n.id == "atlas/count" {n.enabled = !m.atlas.disabled}}
		for &target in c.targets[:c.ni] {if target.id == "atlas/count" {target.enabled = !m.atlas.disabled}}
	}
	return true
}
