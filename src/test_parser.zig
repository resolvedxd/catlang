const std = @import("std");
const Tokenizer = @import("tokenizer.zig");
const Parser = @import("parser.zig");
const AST = @import("AST.zig");
const Node = AST.Node;

pub fn treesEqual(a: Node, b: Node) bool {
    switch (a) {
        .variable_declaration => {
            if (!treesEqual(a.variable_declaration.id.*, b.variable_declaration.id.*)) return false;
            if (a.variable_declaration.init) |init_a| {
                if (b.variable_declaration.init) |init_b| {
                    return treesEqual(init_a.*, init_b.*);
                }
            }
        },
        .bin_op => {
            // TODO: check if a and b are the same type
            if (a.bin_op.op != b.bin_op.op) return false;
            if (!treesEqual(a.bin_op.left.*, b.bin_op.left.*)) return false;
            if (!treesEqual(a.bin_op.right.*, b.bin_op.right.*)) return false;
        },
        .number_literal => {
            return std.mem.eql(u8, a.number_literal.value, b.number_literal.value);
        },
        .identifier => {
            return std.mem.eql(u8, a.identifier.value, b.identifier.value);
        },
        else => {
            std.debug.print("\n! unhandled node type while comparing trees {s}\n", .{@tagName(a)});
        },
    }
    return true;
}

pub fn testParse(allocator: std.mem.Allocator, input: [:0]const u8, expected_tree: Node) !bool {
    var tokenizer = Tokenizer.Tokenizer.init(input);
    const tokens = tokenizer.tokenize(allocator);
    defer tokens.deinit();

    var parser = Parser.Parser.init(allocator, tokens, input);
    if (parser.parse()) |tree| {
        AST.deallocTree(allocator, tree);
        return treesEqual(tree, expected_tree);
    } else |err| {
        Parser.printError(parser, err);
        return false;
    }
}

test "statement" {
    const allocator = std.testing.allocator;
    const expected_tree = Node{
        .variable_declaration = .{
            .id = try AST.allocNode(allocator, Node{ .identifier = .{ .value = "test_stmt" } }),
            .init = try AST.allocNode(allocator, Node{
                .bin_op = .{
                    .left = try AST.allocNode(allocator, Node{
                        .bin_op = .{
                            .left = try AST.allocNode(allocator, Node{ .number_literal = .{ .value = "1" } }),
                            .op = .plus,
                            .right = try AST.allocNode(allocator, Node{
                                .bin_op = .{
                                    .left = try AST.allocNode(allocator, Node{ .number_literal = .{ .value = "2" } }),
                                    .op = .asterisk,
                                    .right = try AST.allocNode(allocator, Node{ .number_literal = .{ .value = "3" } }),
                                },
                            }),
                        },
                    }),
                    .op = .plus,
                    .right = try AST.allocNode(allocator, Node{ .number_literal = .{ .value = "4" } }),
                },
            }),
            .type = try AST.allocNode(allocator, Node{ .identifier = .{ .value = "i32" } }),
        },
    };
    const stmt = try testParse(allocator, "var test_stmt: i32 = 1+2*3+4;", expected_tree);
    AST.deallocTree(allocator, expected_tree);
    try std.testing.expect(stmt);
}
