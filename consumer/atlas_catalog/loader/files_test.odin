package loader

import "core:fmt"
import "core:mem"
import "core:os"
import "core:testing"

@(test)
loader_checked_allocation_sweep_and_path_containment :: proc(t: ^testing.T) {
	dir, e := os.make_directory_temp("/tmp/opencode", "atlas-loader-fault-", context.allocator)
	if !testing.expect(t, e == nil) {return}; defer delete(dir); defer os.remove(dir)
	manifest := fmt.aprintf(
		"%s/manifest.json",
		dir,
	); defer delete(manifest); defer os.remove(manifest)
	page := fmt.aprintf("%s/page.png", dir); defer delete(page); defer os.remove(page)
	text := `{"version":1,"pages":[{"id":"p","file":"page.png"}],"regions":[{"id":"icon","page":"p","rect":[0,0,2,2]}]}`
	b := valid_rgba_fixture()
	testing.expect(
		t,
		os.write_entire_file(manifest, text) == nil && os.write_entire_file(page, b[:]) == nil,
	)
	live: mem.Tracking_Allocator
	mem.tracking_allocator_init(
		&live,
		context.allocator,
	); defer mem.tracking_allocator_destroy(&live)
	f := Output_Fault {
		backing = mem.tracking_allocator(&live),
	}
	requests := 0
	for nth := 0; nth <= requests; nth += 1 {
		f.calls, f.refuse = 0, nth
		set, error := load_set(manifest, {output_fault, &f})
		if nth ==
		   0 {requests = f.calls; testing.expect(t, error.stage == "")} else {testing.expect(t, error.stage != "" && len(set.decoded) == 0)}
		destroy_loaded_set(&set)
		testing.expect(t, len(live.allocation_map) == 0 && len(live.bad_free_array) == 0)
	}
	link := fmt.aprintf("%s/outside.png", dir); defer delete(link); defer os.remove(link)
	testing.expect(t, os.symlink("/etc/passwd", link) == nil)
	for name in ([]string{"/etc/passwd", "../outside.png", "outside.png", "missing.png"}) {
		bad := fmt.aprintf(`{"version":1,"pages":[{"id":"p","file":"%s"}],"regions":[]}`, name)
		testing.expect(t, os.write_entire_file(manifest, bad) == nil); delete(bad)
		set, error := load_set(manifest)
		testing.expect(t, error.stage != "" && error.field != "" && len(set.decoded) == 0)
		destroy_loaded_set(&set)
	}
}

@(test)
external_files_load_recheck_changed_bytes_and_explicit_retry :: proc(t: ^testing.T) {
	dir, de := os.make_directory_temp("/tmp/opencode", "atlas-files-", context.allocator)
	if !testing.expect(t, de == nil) {return}; defer delete(dir)
	manifest := fmt.aprintf("%s/manifest.json", dir); defer delete(manifest)
	page := fmt.aprintf("%s/page.png", dir); defer delete(page)
	defer {os.remove(manifest); os.remove(page); os.remove(dir)}
	text := `{"version":1,"pages":[{"id":"p","file":"page.png"}],"regions":[{"id":"icon","page":"p","rect":[0,0,2,2]}]}`
	b := valid_rgba_fixture()
	testing.expect(t, os.write_entire_file(manifest, text) == nil)
	testing.expect(t, os.write_entire_file(page, b[:]) == nil)
	set, e := load_set(manifest)
	if !testing.expect(
		t,
		e.stage == "",
		"external manifest and PNG load as one staging set",
	) {return}
	defer destroy_loaded_set(&set)
	testing.expect(
		t,
		len(set.catalog.revision) == 64 &&
		len(set.decoded) == 1 &&
		len(set.decoded[0].pixels) == 16,
	)
	testing.expect_value(t, recheck_set(&set), Load_Error{})
	testing.expect(t, os.write_entire_file(page, "broken") == nil)
	testing.expect_value(t, recheck_set(&set).field, "Files_Changed")
	testing.expect_value(t, set.decoded[0].pixels[0], u8(255))
	failed, failure := load_set(manifest)
	testing.expect_value(t, string(failure.path[:failure.path_length]), page)
	testing.expect(t, failure.stage != "" && len(failed.decoded) == 0)
	destroy_loaded_set(&failed)
	testing.expect(t, os.write_entire_file(page, b[:]) == nil)
	retry, recovered := load_set(manifest)
	testing.expect(t, recovered.stage == "" && retry.catalog.revision == set.catalog.revision)
	destroy_loaded_set(&retry)
}
