package ui_gestures
import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"
@(test)
owning_reader_keeps_signals_payload_and_ancestry_after_runtime_destroy :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator)
	ctx := interaction.create(context.allocator, &p)
	s := create(); ds := descriptions([]string{"card"})
	if !publish(
		t,
		&p,
		&ctx,
		&s,
		ds[:],
	) {destroy(&s); interaction.destroy(&ctx); base.destroy(&p); return}
	dispatch(&s, &ctx, nil, {kind = .Begin, id = "drag", source = .Agent})
	if !publish(
		t,
		&p,
		&ctx,
		&s,
		ds[:],
	) {destroy(&s); interaction.destroy(&ctx); base.destroy(&p); return}
	f, ok := try_copy_frame(&s.frame)
	destroy(&s); interaction.destroy(&ctx); base.destroy(&p); defer destroy_frame(&f)
	if !testing.expect(t, ok) {return}
	testing.expect(
		t,
		f.live.owner.payload_id == "card" &&
		f.gestures[1].accept_types[0] == "card" &&
		f.gestures[0].ancestors[0] == "root" &&
		f.result.signals[0].owner_id == "drag" &&
		!f.stamp.lifetime.alive,
	)
}
