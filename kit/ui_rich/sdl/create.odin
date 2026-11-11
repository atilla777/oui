package ui_rich_sdl

import backend "../../ui_sdl"
import sdl "vendor:sdl3"

create_generation :: proc(
	renderer: ^sdl.Renderer,
	revision: string,
	images: []RGBA_Image,
	sources: []Rich_Font_Source,
	chains: []Rich_Font_Chain,
	requests: []Rich_Font_Request,
	scale: f64,
	a := context.allocator,
) -> (
	^Generation,
	backend.Error,
) {
	error := backend.Error {
		code = .Invalid,
	}
	g, ok := create_rich_generation(
		renderer,
		revision,
		images,
		sources,
		chains,
		requests,
		scale,
		a,
		&error,
	)
	if !ok {return nil, error}
	return g, {}
}
creation_failure :: proc(
	out: ^backend.Error,
	code: backend.Code,
	id: string = "",
) -> bool {if out != nil {out^ = {code, id}}; return false}
