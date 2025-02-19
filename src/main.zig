const std = @import("std");
const Tokenizer = @import("tokenizer.zig");

pub fn main() !void {
    // const t = "return 1;";
    var tokenizer = Tokenizer.Tokenizer.init("");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const tokens = tokenizer.tokenize(allocator);
    for (tokens.items) |token| {
        std.debug.print("{s}:{s}\n", .{ tokenizer.buffer[token.pos.start..token.pos.end], @tagName(token.type) });
    }
    std.debug.print("{}\n", .{tokens.items.len});
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
