package ui_gestures
import base "../ui_base"
// Physical loss/failure cleanup only: it never activates or produces a drop.
block :: proc(s: ^State, p: ^base.Publication, reason: Cancel_Reason = .Update_Failed) -> bool {
	if reason <= .None || reason > .Update_Failed || p == nil || p.committing {return false}
	if s.frame.stamp.lifetime != nil && s.frame.stamp.lifetime != p.lifetime {return false}
	base.invalidate(p)
	if s.version == max(u64) || s.clock_epoch == max(u64) {return false}
	s.version += 1; s.clock_epoch += 1
	if s.live.phase != .Idle {
		s.live.phase, s.live.reason = .Idle, reason
		s.result = {
			code   = .Applied,
			cycle  = s.live.cycle,
			phase  = .Idle,
			reason = reason,
		}
		emit(&s.result, s.live, .Cancelled)
	}
	return true
}
