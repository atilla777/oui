package ui_gestures
import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"
@(test)
rebuild_cancels_removed_or_changed_owner_without_retargeting_cycle :: proc(t: ^testing.T) {
	for remove in ([2]bool{false, true}) {
		p, _ := base.create(context.allocator); defer base.destroy(&p)
		ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
		s := create(); defer destroy(&s)
		ds := descriptions([]string{"card"})
		if !publish(t, &p, &ctx, &s, ds[:]) {return}
		r := dispatch(&s, &ctx, nil, {kind = .Begin, id = "drag", source = .Agent})
		if !testing.expect(t, r.code == .Applied) {return}
		selected := ds[:]
		if remove {selected = ds[1:]} else {ds[0].payload_id = "different"}
		if !publish(t, &p, &ctx, &s, selected) {return}
		reason := Cancel_Reason.Mode_Changed; if remove {reason = .Removed}
		testing.expect(
			t,
			s.live.phase == .Idle &&
			s.live.cycle == 1 &&
			s.live.reason == reason &&
			s.frame.result.count == 1 &&
			s.frame.result.signals[0].kind == .Cancelled,
		)
	}
}
