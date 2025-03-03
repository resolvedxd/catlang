const Tokenizer = @import("tokenizer.zig");
const std = @import("std");

const nullary_operator = i0;
const value = struct { value: []u8 };
const unary_operator = struct { operand: *Node };
const binary_operator = struct { left: *Node, right: *Node, op: Tokenizer.TokenType };

pub const Node = union(enum) {
    number_literal: value,
    string_literal: value,
    identifier: value,
    bin_op: binary_operator,
    equal: binary_operator,
    bang: unary_operator,
    paren_expr: unary_operator,
    block: []*Node,
    if_expr: struct {
        condition: *Node,
        then_branch: *Node,
        else_branch: ?*Node,
    },
    while_expr: struct {
        condition: *Node,
        body: *Node,
    },
    for_expr: struct {
        initializer: ?*Node,
        condition: *Node,
        increment: ?*Node,
        body: *Node,
    },
    return_expr: ?*Node,
};

pub fn print_tree(node: Node) !void {
    switch (node) {
        .number_literal, .string_literal, .identifier => {
            std.debug.print("{s}", .{@tagName(node)});
        },
        .bin_op => {
            std.debug.print("{s} left:", .{@tagName(node)});
            try print_tree(node.bin_op.left.*);
            std.debug.print("right:", .{});
            try print_tree(node.bin_op.right.*);
            std.debug.print("\n", .{});
        },
        else => {},
    }
}
