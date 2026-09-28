const std = @import("std");
const rl = @import("raylib");

pub fn parse_kenney_xml(allocator: std.mem.Allocator, xml_content: []const u8) !std.StringHashMap(rl.Rectangle) {
    var sprite_map = std.StringHashMap(rl.Rectangle).init(allocator);
    errdefer sprite_map.deinit();

    var iterator = std.mem.tokenizeSequence(u8, xml_content, "<SubTexture ");
    _ = iterator.next(); // header

    while (iterator.next()) |tag| {
        const full_name = try extract_attr(tag, "name=\"");
        const name = if (std.mem.lastIndexOfScalar(u8, full_name, '.')) |dot_idx|
            full_name[0..dot_idx]
        else
            full_name;
        const x = try std.fmt.parseFloat(f32, try extract_attr(tag, "x=\""));
        const y = try std.fmt.parseFloat(f32, try extract_attr(tag, "y=\""));
        const w = try std.fmt.parseFloat(f32, try extract_attr(tag, "width=\""));
        const h = try std.fmt.parseFloat(f32, try extract_attr(tag, "height=\""));

        try sprite_map.put(name, rl.Rectangle{ .x = x, .y = y, .width = w, .height = h });
    }

    return sprite_map;
}

fn extract_attr(tag: []const u8, attr_key: []const u8) ![]const u8 {
    const start_idx = std.mem.indexOf(u8, tag, attr_key) orelse return error.AttributeNotFound;
    const value_start = start_idx + attr_key.len;
    const value_end = std.mem.indexOfPos(u8, tag, value_start, "\"") orelse return error.MalformedXml;
    return tag[value_start..value_end];
}
