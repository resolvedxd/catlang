const std = @import("std");
const Tokenizer = @import("tokenizer.zig");
const Parser = @import("parser.zig");
const AST = @import("AST.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const input = "1+3+2";
    std.debug.print("input: {s}\n", .{input});
    var tokenizer = Tokenizer.Tokenizer.init(input);
    const tokens = tokenizer.tokenize(allocator);

    std.debug.print("Tokens ({}): \n", .{tokens.items.len});
    for (tokens.items) |token| {
        std.debug.print("{s}:{s}\n", .{ tokenizer.buffer[token.pos.start..token.pos.end], @tagName(token.type) });
    }

    std.debug.print("\nAST:\n", .{});
    var parser = Parser.Parser.init(allocator, tokens, input);
    if (parser.parse()) |tree| {
        try AST.print_tree(tree);
    } else |err| {
        std.debug.print("{s}\n", .{@errorName(err)});
    }
}
