const std = @import("std");
const Tokenizer = @import("tokenizer.zig");
const Parser = @import("parser.zig");
const AST = @import("AST.zig");
const Utils = @import("utils.zig");
const Node = AST.Node;

pub const std_options: std.Options = .{ .logFn = Utils.coloredLog };
// TODO: better errors when missing a closing bracket

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();
    const input =
        \\fun test {  
        \\ var a = 1+2*3;
        \\ if (a == 4) {
        \\  var i = 0;
        \\  var asd = 123;
        \\ } else {}
        \\}
    ;
    std.debug.print("input: \n{s}\n", .{input});
    var tokenizer = Tokenizer.Tokenizer.init(input);
    const tokens = tokenizer.tokenize(allocator);
    defer tokens.deinit();

    // std.debug.print("Tokens ({}): \n", .{tokens.items.len});
    // for (tokens.items) |token| {
    //     std.debug.print("{s}:{s}\n", .{ tokenizer.buffer[token.pos.start..token.pos.end], @tagName(token.type) });
    // }

    var parser = Parser.Parser.init(allocator, tokens, input);
    if (parser.parse()) |tree| {
        std.debug.print("\nAST:\n", .{});
        try AST.printTree(tree);
        AST.deallocTree(allocator, tree);
    } else |err| {
        Parser.printError(parser, err);
    }
}
