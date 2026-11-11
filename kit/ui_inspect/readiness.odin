package ui_inspect
// The host still supplies a fresh publication/model binding per capture. A
// retained reader cannot revive the lifetime of its destroyed runtime.
is_ready :: proc(i: ^Inspection) -> bool {return(
		i.ready &&
		i.frame.stamp.lifetime != nil &&
		i.frame.stamp.lifetime.alive \
	)}
