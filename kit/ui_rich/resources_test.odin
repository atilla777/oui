package ui_rich

import "core:testing"
chain :: proc(style: Rich_Style, user: rawptr) -> []string {return (cast(^[2]string)user)[:]}
coverage :: proc(r: rune, style: Rich_Style, user: rawptr) -> string {if r == 'я' {return(
			"fallback" \
		)}
	return "body"}
@(test)
fallback_coverage_and_chain_are_frozen_and_addressed :: proc(t: ^testing.T) {
	d, e := parse_rich_text("aя", {font_id = "body", size = 10})
	if !testing.expect(t, e.code == .None) {return}
	b := Rich_Block {
		document = d,
		base_style = {font_id = "body", size = 10},
	}
	defer destroy_rich_block(&b, context.allocator)
	ids := [2]string{"body", "fallback"}
	e = rich_resolve_resources(
		&b,
		{font_chain = chain, coverage = coverage, user = &ids},
		context.allocator,
	)
	if !testing.expect(t, e.code == .None) {return}
	ids[0] = "changed"
	testing.expect(
		t,
		len(b.coverage) == 2 &&
		b.coverage[1].resource == "fallback" &&
		b.coverage[1].source_range == (Text_Source_Range{1, 3}),
	)
	testing.expect(t, len(b.font_chains) == 1 && b.font_chains[0].resources[0] == "body")
}
