const Tokenizer = @import("tokenizer.zig");
const std = @import("std");

const NullaryOperator = i0;
const Value = struct { value: []const u8 };
const UnaryOperator = struct { operand: *Node, op: Tokenizer.TokenType };
const BinaryOperator = struct { left: *Node, right: *Node, op: Tokenizer.TokenType };

pub const Node = union(enum) {
    number_literal: Value,
    string_literal: Value,
    identifier: Value,
    bin_op: BinaryOperator,
    equal: BinaryOperator,
    unary_op: UnaryOperator,
    empty_statement: NullaryOperator,
    variable_declaration: struct {
        id: *Node,
        init: ?*Node,
        type: ?*Node,
    },
    block: std.ArrayList(*Node),
    function_declaration: struct {
        id: *Node,
        body: *Node,
    },
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

pub fn printTree(node: Node) !void {
    switch (node) {
        .number_literal, .string_literal, .identifier => {
            std.debug.print("{s}", .{@tagName(node)});
        },
        .bin_op => {
            std.debug.print("({s} ", .{@tagName(node)});
            try printTree(node.bin_op.left.*);
            std.debug.print("{s}", .{Tokenizer.lexeme(node.bin_op.op)});
            try printTree(node.bin_op.right.*);
            std.debug.print(")", .{});
        },
        .unary_op => {
            std.debug.print("({s} {s}", .{ @tagName(node), Tokenizer.lexeme(node.unary_op.op) });
            try printTree(node.unary_op.operand.*);
            std.debug.print(")", .{});
        },
        .variable_declaration => {
            std.debug.print("({s} {s}", .{ @tagName(node), node.variable_declaration.id.identifier.value });
            if (node.variable_declaration.type) |type_node| {
                std.debug.print(":{s}", .{type_node.identifier.value});
            }
            if (node.variable_declaration.init) |init| {
                std.debug.print("=", .{});
                try printTree(init.*);
            }
            std.debug.print(")", .{});
        },
        .function_declaration => {
            std.debug.print("({s} {s}=>{s}\n", .{ @tagName(node), node.function_declaration.id.identifier.value, "{" });
            try printTree(node.function_declaration.body.*);
            std.debug.print("{s})", .{"}"});
        },
        .if_expr => {
            std.debug.print("({s} ", .{@tagName(node)});
            try printTree(node.if_expr.condition.*);
            std.debug.print(" then=>{s}\n", .{"{"});
            try printTree(node.if_expr.then_branch.*);
            std.debug.print("{s}", .{"}"});
            if (node.if_expr.else_branch) |else_branch| {
                std.debug.print(" else=>{s}\n", .{"{"});
                try printTree(else_branch.*);
                std.debug.print("{s}", .{"}"});
            }
        },
        .block => {
            for (node.block.items) |nd| {
                try printTree(nd.*);
                std.debug.print("\n", .{});
            }
        },
        else => {
            std.debug.print("unimplemented tree printer node type: {s}", .{@tagName(node)});
        },
    }
}

pub fn allocNode(allocator: std.mem.Allocator, node: Node) !*Node {
    const mem = allocator.create(Node);
    if (mem) |m| {
        m.* = node;
        return m;
    } else |_| {
        return error.allocation_error;
    }
}

pub fn deallocTree(allocator: std.mem.Allocator, node: Node) void {
    switch (node) {
        .bin_op => {
            deallocTree(allocator, node.bin_op.left.*);
            deallocTree(allocator, node.bin_op.right.*);
            allocator.destroy(node.bin_op.left);
            allocator.destroy(node.bin_op.right);
        },
        .variable_declaration => {
            deallocTree(allocator, node.variable_declaration.id.*);
            allocator.destroy(node.variable_declaration.id);
            if (node.variable_declaration.type) |type_node| {
                deallocTree(allocator, type_node.*);
                allocator.destroy(type_node);
            }
            if (node.variable_declaration.init) |init| {
                deallocTree(allocator, init.*);
                allocator.destroy(init);
            }
        },
        .function_declaration => {
            deallocTree(allocator, node.function_declaration.id.*);
            allocator.destroy(node.function_declaration.id);
            deallocTree(allocator, node.function_declaration.body.*);
            allocator.destroy(node.function_declaration.body);
        },
        .block => {
            for (node.block.items) |nd| {
                deallocTree(allocator, nd.*);
                allocator.destroy(nd);
            }
            node.block.deinit();
        },
        .if_expr => {
            deallocTree(allocator, node.if_expr.condition.*);
            allocator.destroy(node.if_expr.condition);
            deallocTree(allocator, node.if_expr.then_branch.*);
            allocator.destroy(node.if_expr.then_branch);
            if (node.if_expr.else_branch) |else_branch| {
                deallocTree(allocator, else_branch.*);
                allocator.destroy(else_branch);
            }
        },
        .identifier, .number_literal, .string_literal, .empty_statement => {},
        else => {
            std.log.err("!!!unimplemented tree deallocation for node type: {s}\n", .{@tagName(node)});
        },
    }
}

pub fn deallocNodeList(allocator: std.mem.Allocator, list: std.ArrayList(*Node)) void {
    for (list.items) |node| {
        deallocTree(allocator, node.*);
        allocator.destroy(node);
    }

    list.deinit();
}
