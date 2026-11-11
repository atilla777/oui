package sections

import gesture_model "../../gestures_demo/model"
import "core:fmt"
import gestures "ui:ui_gestures"

Gesture_View :: struct {
	state:   struct {
		live: gestures.Live,
	},
	model:   ^gesture_model.State,
	outcome: gesture_model.Outcome,
	ids:     ^[12][2][64]u8,
	status:  []u8,
}
GESTURE_PANELS := [2]string{"gestures/left", "gestures/right"}
GESTURE_ACCEPT_TYPES := [1]string{"card"}
GESTURE_TARGETS := [2]string{"gestures/left-title", "gestures/right-title"}
GESTURE_VIEWPORTS := [2]string{"gestures/left-viewport", "gestures/right-viewport"}
GESTURE_CONTENTS := [2]string{"gestures/left-content", "gestures/right-content"}
GESTURE_PANS := [2]string{"gestures/left-pan", "gestures/right-pan"}
GESTURE_REPEATS := [4]string {
	"gestures/left-up",
	"gestures/left-down",
	"gestures/right-up",
	"gestures/right-down",
}
compose_gesture_page :: proc(r: Page_Input, c: ^Page_Composition, g: Gesture_View) -> bool {
	if g.model == nil {return false}
	label(
		c,
		"gestures/title",
		"root",
		"G14 / cards-repeat-pan + C04 editor",
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
	)
	node(
		c,
		"name/field",
		"root",
		.Stack,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 36}, padding = {4, 4, 4, 4}},
	)
	label(
		c,
		"name/value",
		"name/field",
		r.model.gesture_name.draft,
		{x = {mode = .Fill}, y = {mode = .Fill}},
	)
	c.targets[c.ni] = {"name/field", "editor", true, true}; c.ni += 1
	label(
		c,
		"gestures/status",
		"root",
		fmt.bprintf(
			g.status[:],
			"%v | %s -> %s | result=%v",
			g.state.live.phase,
			g.state.live.owner.payload_id,
			g.state.live.target_id,
			g.outcome.reason,
		),
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
	)
	node(
		c,
		"gestures/panels",
		"root",
		.Row,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 320}, gap = 12},
	)
	index := 0
	for panel, p in g.model.panels {
		root := GESTURE_PANELS[p]
		node(
			c,
			root,
			"gestures/panels",
			.Column,
			{x = {mode = .Fill}, y = {mode = .Fill}, gap = 4},
		)
		c.gestures[c.ngestures] = {
			id           = panel.id,
			node_id      = GESTURE_TARGETS[p],
			kind         = .Drop_Target,
			accept_types = GESTURE_ACCEPT_TYPES[:],
		}; c.ngestures += 1
		titles := [2]string{"gestures/left-title", "gestures/right-title"}
		title := panel.id
		if g.state.live.phase == .Active &&
		   g.state.live.owner.kind == .Drag_Source &&
		   g.state.live.target_id == panel.id {
			allowed := g.state.live.target_accepted
			for i in 0 ..< panel.count {if panel.cards[i] == g.state.live.owner.payload_id {allowed = false}}
			title = "Drop: accepted" if allowed else "Drop: refused"
			if r.model.locale ==
			   .Russian {title = "Перенос: разрешён" if allowed else "Перенос: отказ"}
		}
		label(c, titles[p], root, title, {x = {mode = .Fill}, y = {mode = .Fixed, value = 24}})
		actions := [2]string{"gestures/left-actions", "gestures/right-actions"}
		node(
			c,
			actions[p],
			root,
			.Row,
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 30}, gap = 4},
		)
		for sign in 0 ..< 2 {
			id := GESTURE_REPEATS[p * 2 + sign]
			label_ids := [4]string {
				"gestures/left-up-label",
				"gestures/left-down-label",
				"gestures/right-up-label",
				"gestures/right-down-label",
			}
			button(c, id, label_ids[p * 2 + sign], actions[p], "-24" if sign == 0 else "+24")
			c.gestures[c.ngestures] = {
				id          = id,
				node_id     = id,
				kind        = .Repeat_Scroll,
				scroll_id   = GESTURE_VIEWPORTS[p],
				step        = -24 if sign == 0 else 24,
				delay_ms    = 400,
				interval_ms = 100,
			}; c.ngestures += 1
		}
		node(
			c,
			GESTURE_VIEWPORTS[p],
			root,
			.Stack,
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 192}, overflow = .Clip},
		)
		node(
			c,
			GESTURE_CONTENTS[p],
			GESTURE_VIEWPORTS[p],
			.Column,
			{x = {mode = .Fill}, y = {mode = .Content}},
		)
		c.layer_scroll[c.nscroll] = {GESTURE_VIEWPORTS[p], GESTURE_CONTENTS[p]}; c.nscroll += 1
		for card_index in 0 ..< panel.count {
			card := panel.cards[card_index]
			id := fmt.bprintf(g.ids[index][0][:], "gestures/%s", card)
			caption := fmt.bprintf(g.ids[index][1][:], "gestures/%s-label", card); index += 1
			node(
				c,
				id,
				GESTURE_CONTENTS[p],
				.Stack,
				{x = {mode = .Fill}, y = {mode = .Fixed, value = 48}},
			)
			label(c, caption, id, card, {x = {mode = .Fill}, y = {mode = .Fixed, value = 48}})
			c.targets[c.ni] = {id, "button", true, true}; c.ni += 1
			c.gestures[c.ngestures] = {
				id           = card,
				node_id      = id,
				kind         = .Drag_Source,
				payload_id   = card,
				payload_type = "card",
			}; c.ngestures += 1
		}
		pan := GESTURE_PANS[p]
		labels := [2]string{"gestures/left-pan-label", "gestures/right-pan-label"}
		node(c, pan, root, .Stack, {x = {mode = .Fill}, y = {mode = .Fixed, value = 32}})
		label(
			c,
			labels[p],
			pan,
			"Pan handle" if r.model.locale == .English else "Ручка прокрутки",
			{x = {mode = .Fill}, y = {mode = .Fill}},
		)
		c.targets[c.ni] = {pan, "button", true, true}; c.ni += 1
		c.gestures[c.ngestures] = {
			id        = pan,
			node_id   = pan,
			kind      = .Pan_Scroll,
			scroll_id = GESTURE_VIEWPORTS[p],
		}; c.ngestures += 1
	}
	c.initial_focus = "name/field"; return true
}
