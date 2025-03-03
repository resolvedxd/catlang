const std = @import("std");
const Tokenizer = @import("tokenizer.zig");
const AST = @import("AST.zig");
const Token = Tokenizer.Token;
const TokenType = Tokenizer.TokenType;

// fun main(): void {
//  return 1;
// }

// while the tokenizer just represents different symbols by their positions in the source code, the parser will include the symbols themselves.
// this will make preserving the tree by itself easier, making the source code no longer need to stay in memory.

pub const ParseError = error{unexpected_token};

pub const Parser = struct {
    tokens: std.ArrayList(Token),
    source_code: [:0]const u8,
    token: Token,
    index: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, input: std.ArrayList(Token), source_code: [:0]const u8) Parser {
        return Parser{
            .allocator = allocator,
            .tokens = input,
            .source_code = source_code,
            .token = input.items[0],
            .index = 0,
        };
    }

    // TODO: move this to AST.zig
    fn alloc_node(self: *Parser, node: AST.Node) !*AST.Node {
        const mem = try self.allocator.create(AST.Node);
        mem.* = node;
        return mem;
    }

    fn next_token(self: *Parser) bool {
        self.index += 1;

        if (self.index < self.tokens.items.len) {
            self.token = self.tokens.items[self.index];
            return true;
        } else return false;
    }

    fn accept(self: *Parser, token: TokenType) bool {
        if (self.token.type == token) {
            return next_token(self);
        } else return false;
    }

    fn expect(self: *Parser, token: TokenType) !void {
        if (accept(self, token))
            return;
        return error.unexpected_token;
    }

    fn factor(self: *Parser) !AST.Node {
        const past_tkn = self.token.pos;

        if (self.accept(.number_literal)) {
            const token_text = self.source_code[past_tkn.start..past_tkn.end];
            return AST.Node{ .number_literal = .{ .value = @constCast(token_text) } };
        } else if (self.accept(.identifier)) {
            const token_text = self.source_code[past_tkn.start..past_tkn.end];
            return AST.Node{ .identifier = .{ .value = @constCast(token_text) } };
        } else if (self.accept(.paren_left)) {
            // const expr = try self.expression();
            try self.expect(.paren_right);
        }

        return error.unexpected_token;
    }

    fn term(self: *Parser) !AST.Node {
        var left: AST.Node = try self.factor();

        while (self.token.type == .asterisk or self.token.type == .slash) {
            const op_type = self.token.type;
            _ = self.next_token();
            const right = try self.factor();

            left = AST.Node{ .bin_op = .{
                .op = op_type,
                .left = try self.alloc_node(left),
                .right = try self.alloc_node(right),
            } };
        }

        return left;
    }

    fn expression(self: *Parser) !AST.Node {
        var left = try self.term();

        while (self.token.type == .plus or self.token.type == .minus) {
            const op_type = self.token.type;
            _ = self.next_token();
            const right = try self.term();

            left = AST.Node{ .bin_op = .{
                .op = op_type,
                .left = try self.alloc_node(left),
                .right = try self.alloc_node(right),
            } };
        }

        return left;
    }

    pub fn parse(self: *Parser) !AST.Node {
        const expr = try self.expression();
        return expr;
    }
};
