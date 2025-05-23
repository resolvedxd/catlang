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
        arguments: *Node,
        return_type: ?*Node,
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

pub fn printTree(node: Node) void {
    switch (node) {
        .number_literal, .string_literal, .identifier => {
            std.debug.print("{s}", .{@tagName(node)});
        },
        .bin_op => {
            std.debug.print("({s} ", .{@tagName(node)});
            printTree(node.bin_op.left.*);
            std.debug.print("{s}", .{Tokenizer.lexeme(node.bin_op.op)});
            printTree(node.bin_op.right.*);
            std.debug.print(")", .{});
        },
        .unary_op => {
            std.debug.print("({s} {s}", .{ @tagName(node), Tokenizer.lexeme(node.unary_op.op) });
            printTree(node.unary_op.operand.*);
            std.debug.print(")", .{});
        },
        .variable_declaration => {
            std.debug.print("({s} {s}", .{ @tagName(node), node.variable_declaration.id.identifier.value });
            if (node.variable_declaration.type) |type_node| {
                std.debug.print(":{s}", .{type_node.identifier.value});
            }
            if (node.variable_declaration.init) |init| {
                std.debug.print("=", .{});
                printTree(init.*);
            }
            std.debug.print(")", .{});
        },
        .function_declaration => {
            std.debug.print("({s} {s}(", .{ @tagName(node), node.function_declaration.id.identifier.value });
            for (node.function_declaration.arguments.block.items) |arg| {
                std.debug.print("{s}:{s}", .{ arg.variable_declaration.id.identifier.value, arg.variable_declaration.type.?.identifier.value });
            }
            std.debug.print(")=>{s}\n", .{"{"});

            printTree(node.function_declaration.body.*);
            std.debug.print("{s})", .{"}"});
        },
        .if_expr => {
            std.debug.print("({s} ", .{@tagName(node)});
            printTree(node.if_expr.condition.*);
            std.debug.print(" then=>{s}\n", .{"{"});
            printTree(node.if_expr.then_branch.*);
            std.debug.print("{s}", .{"}"});
            if (node.if_expr.else_branch) |else_branch| {
                std.debug.print(" else=>{s}\n", .{"{"});
                printTree(else_branch.*);
                std.debug.print("{s}", .{"}"});
            }
        },
        .block => {
            for (node.block.items) |nd| {
                printTree(nd.*);
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
            deallocTreePtr(allocator, node.bin_op.left);
            deallocTreePtr(allocator, node.bin_op.right);
        },
        .variable_declaration => {
            deallocTreePtr(allocator, node.variable_declaration.id);
            if (node.variable_declaration.type) |type_node| {
                deallocTreePtr(allocator, type_node);
            }
            if (node.variable_declaration.init) |init| {
                deallocTreePtr(allocator, init);
            }
        },
        .function_declaration => {
            deallocTreePtr(allocator, node.function_declaration.id);
            deallocTreePtr(allocator, node.function_declaration.body);
            deallocTreePtr(allocator, node.function_declaration.arguments);
            if (node.function_declaration.return_type) |ret| deallocTreePtr(allocator, ret);
        },
        .block => {
            for (node.block.items) |nd| {
                deallocTreePtr(allocator, nd);
            }
            node.block.deinit();
        },
        .if_expr => {
            deallocTreePtr(allocator, node.if_expr.condition);
            deallocTreePtr(allocator, node.if_expr.then_branch);
            if (node.if_expr.else_branch) |else_branch| {
                deallocTreePtr(allocator, else_branch);
            }
        },
        .identifier, .number_literal, .string_literal, .empty_statement => {},
        else => {
            std.log.err("!!!unimplemented tree deallocation for node type: {s}\n", .{@tagName(node)});
        },
    }
}

pub fn deallocTreePtr(allocator: std.mem.Allocator, node: *Node) void {
    deallocTree(allocator, node.*);
    allocator.destroy(node);
}

pub fn deallocNodeList(allocator: std.mem.Allocator, list: std.ArrayList(*Node)) void {
    for (list.items) |node|
        deallocTreePtr(allocator, node);

    list.deinit();
}
