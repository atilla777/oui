package ui_collections

import "core:fmt"
import "core:mem"
import "core:strings"

decode_part :: proc(id: string, cursor: ^int) -> (string, bool) {
	start := cursor^; length := 0
	for cursor^ < len(id) && id[cursor^] >= '0' && id[cursor^] <= '9' {
		digit := int(id[cursor^] - '0'); if length > (max(int) - digit) / 10 {return "", false}
		length = length * 10 + digit; cursor^ += 1
	}
	if cursor^ == start ||
	   cursor^ >= len(id) ||
	   id[cursor^] != ':' {return "", false}; cursor^ += 1
	if length > len(id) - cursor^ {return "", false}
	part := id[cursor^:cursor^ + length]; cursor^ += length; return part, true
}
decode_item_node_id :: proc(id: string) -> (collection, item: string, valid: bool) {
	cursor := 0
	collection, valid = decode_part(id, &cursor); if !valid {return "", "", false}
	item, valid = decode_part(id, &cursor)
	return collection, item, valid && cursor == len(id)
}

item_node_id :: proc(
	collection, item: string,
	a := context.allocator,
) -> (
	string,
	mem.Allocator_Error,
) #optional_allocator_error {
	b1, b2: [32]u8
	return strings.concatenate(
		[]string {
			fmt.bprintf(b1[:], "%d:", len(collection)),
			collection,
			fmt.bprintf(b2[:], "%d:", len(item)),
			item,
		},
		a,
	)
}
