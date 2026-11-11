package ui_editor
import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"
@(test)
reader_owns_unicode_geometry_and_survives_runtime_destroy :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator)
	ctx := interaction.create(context.allocator, &p)
	s := create()
	if !publish(
		t,
		&p,
		&ctx,
		&s,
		description("a\u0301я"),
	) {destroy(&s); interaction.destroy(&ctx); base.destroy(&p); return}
	f, ok := try_copy_frame(&s.frame)
	destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	defer destroy_frame(&f)
	if !testing.expect(t, ok) {return}
	e, found := find(&f, "name")
	testing.expect(
		t,
		found &&
		e.value == "a\u0301я" &&
		e.boundaries[1] == 3 &&
		e.runs[1].start == 3 &&
		!f.stamp.lifetime.alive,
	)
}
