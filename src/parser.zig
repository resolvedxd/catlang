const std = @import("std");
const Tokenizer = @import("tokenizer.zig");
const AST = @import("AST.zig");
const Token = Tokenizer.Token;
const TokenType = Tokenizer.TokenType;

pub const ParseError = error{ unexpected_token, allocation_error, other };
pub const ParseErrorKind = enum {
    unexpected_token,
    expected_and_found,
    allocation_error,
    other,
};
const ErrorInfo = union(ParseErrorKind) {
    unexpected_token: struct { expected: Tokenizer.TokenType, found: Token },
    expected_and_found: struct { expected: [:0]const u8, found: Token },
    allocation_error: i0,
    other: [:0]const u8,
};

pub const Parser = struct {
    tokens: std.ArrayList(Token),
    source_code: [:0]const u8,
    token: Token,
    index: usize,
    allocator: std.mem.Allocator,
    error_info: ErrorInfo,

    pub fn init(allocator: std.mem.Allocator, input: std.ArrayList(Token), source_code: [:0]const u8) Parser {
        return Parser{
            .allocator = allocator,
            .tokens = input,
            .source_code = source_code,
            .token = input.items[0],
            .index = 0,
            .error_info = .{ .allocation_error = 0 },
        };
    }

    fn nextToken(self: *Parser) bool {
        self.index += 1;

        if (self.index < self.tokens.items.len) {
            self.token = self.tokens.items[self.index];
            return true;
        } else return false;
    }

    fn accept(self: *Parser, token: TokenType) bool {
        if (self.token.type == token) {
            return nextToken(self);
        } else return false;
    }

    fn acceptIdentifier(self: *Parser, identifier: []const u8) bool {
        const expected = self.source_code[self.token.pos.start..self.token.pos.end];

        std.debug.print("{} {}", .{ expected.len, identifier.len });
        if (self.token.type == .identifier and std.mem.eql(u8, expected, identifier)) {
            return nextToken(self);
        } else return false;
    }

    fn expect(self: *Parser, token: TokenType) !void {
        if (accept(self, token))
            return;
        self.error_info = ErrorInfo{ .unexpected_token = .{ .expected = token, .found = self.token } };
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
            const expr = try self.expression();
            try self.expect(.paren_right);
            return expr;
        } else if (self.accept(.bang)) {
            const unary_node = AST.Node{
                .unary_op = .{
                    .op = .bang,
                    .operand = try AST.allocNode(self.allocator, try self.expression()),
                },
            };
            return unary_node;
        }

        self.error_info = ErrorInfo{ .expected_and_found = .{ .expected = "expression", .found = self.token } };
        return error.unexpected_token;
    }

    fn term(self: *Parser) ParseError!AST.Node {
        var left: AST.Node = try self.factor();

        while (self.token.type == .asterisk or self.token.type == .slash) {
            const op_type = self.token.type;
            _ = self.nextToken();
            const right = try self.factor();

            left = AST.Node{ .bin_op = .{
                .op = op_type,
                .left = try AST.allocNode(self.allocator, left),
                .right = try AST.allocNode(self.allocator, right),
            } };
        }

        return left;
    }

    fn comparison(self: *Parser) ParseError!AST.Node {
        var left: AST.Node = try self.term();

        while (self.token.type == .equal_equal or
            self.token.type == .bang_equal or
            self.token.type == .greater_than or
            self.token.type == .greater_than_or_eq or
            self.token.type == .lesser_than or
            self.token.type == .lesser_than_or_eq)
        {
            const op_type = self.token.type;
            _ = self.nextToken();
            const right = try self.term();

            left = AST.Node{ .bin_op = .{
                .op = op_type,
                .left = try AST.allocNode(self.allocator, left),
                .right = try AST.allocNode(self.allocator, right),
            } };
        }

        return left;
    }

    fn expression(self: *Parser) ParseError!AST.Node {
        var left = try self.comparison();
        errdefer AST.deallocTree(self.allocator, left);

        while (self.token.type == .plus or self.token.type == .minus) {
            const op_type = self.token.type;
            _ = self.nextToken();
            const right = try self.comparison();

            left = AST.Node{ .bin_op = .{
                .op = op_type,
                .left = try AST.allocNode(self.allocator, left),
                .right = try AST.allocNode(self.allocator, right),
            } };
        }

        return left;
    }

    fn variableDeclaration(self: *Parser) ParseError!AST.Node {
        const var_name = self.source_code[self.token.pos.start..self.token.pos.end];
        const id = AST.Node{ .identifier = .{ .value = var_name } };
        try self.expect(.identifier);
        var var_node = AST.Node{ .variable_declaration = .{
            .id = try AST.allocNode(self.allocator, id),
            .init = null,
        } };
        errdefer AST.deallocTree(self.allocator, var_node);

        if (self.accept(.equal)) {
            const expr = try self.expression();
            var_node.variable_declaration.init = try AST.allocNode(self.allocator, expr);
            errdefer AST.deallocTree(self.allocator, var_node);
        }
        return var_node;
    }

    fn ifStatement(self: *Parser) ParseError!AST.Node {
        // HACK: the first two errdefers that free memory segfault if the error occured after the 3rd errdefer which
        // frees the whole node
        var has_else = false;

        try self.expect(.paren_left);
        const condition = try self.expression();
        errdefer if (!has_else) AST.deallocTree(self.allocator, condition);
        try self.expect(.paren_right);

        const then_branch = try self.block();
        errdefer if (!has_else) AST.deallocTree(self.allocator, then_branch);
        var node = AST.Node{
            .if_expr = .{
                .condition = try AST.allocNode(self.allocator, condition),
                .then_branch = try AST.allocNode(self.allocator, then_branch),
                .else_branch = null,
            },
        };

        if (self.accept(.keyword_else)) {
            has_else = true;
            errdefer AST.deallocTree(self.allocator, node);
            const else_branch = try self.block();
            node.if_expr.else_branch = try AST.allocNode(self.allocator, else_branch);
        }
        return node;
    }

    fn statement(self: *Parser) ParseError!AST.Node {
        var statement_node = AST.Node{ .empty_statement = 0 };
        errdefer AST.deallocTree(self.allocator, statement_node);
        if (self.accept(.keyword_var)) {
            statement_node = try self.variableDeclaration();
            try self.expect(.semicolon);
        } else if (self.accept(.keyword_fun)) {
            statement_node = try self.functionDeclaration();
        } else if (self.accept(.keyword_if)) {
            statement_node = try self.ifStatement();
        } else {
            self.error_info = ErrorInfo{ .expected_and_found = .{ .expected = "statement", .found = self.token } };
            return error.unexpected_token;
        }

        return statement_node;
    }

    fn block(self: *Parser) ParseError!AST.Node {
        var arr = std.ArrayList(*AST.Node).init(self.allocator);
        try self.expect(.curly_br_left);
        while (self.token.type != .curly_br_right) {
            errdefer AST.deallocNodeList(self.allocator, arr);
            const stmt = try self.statement();
            if (arr.append(try AST.allocNode(self.allocator, stmt))) |_| {} else |_| {
                AST.deallocNodeList(self.allocator, arr);
                return error.allocation_error;
            }
        }
        errdefer AST.deallocNodeList(self.allocator, arr);

        try self.expect(.curly_br_right);

        const block_node = AST.Node{ .block = arr };
        return block_node;
    }

    fn functionDeclaration(self: *Parser) ParseError!AST.Node {
        const fun_name = self.source_code[self.token.pos.start..self.token.pos.end];
        const id = try AST.allocNode(self.allocator, AST.Node{ .identifier = .{ .value = fun_name } });
        errdefer self.allocator.destroy(id);

        try self.expect(.identifier);
        const fun_block = try AST.allocNode(self.allocator, try self.block());
        errdefer AST.deallocTree(fun_block);

        const fun_node = AST.Node{ .function_declaration = .{ .id = id, .body = fun_block } };
        return fun_node;
    }

    pub fn parse(self: *Parser) !AST.Node {
        const expr = try self.statement();
        return expr;
    }
};

const lineAndCol = struct {
    col: i32,
    line: i32,
};

pub fn printSourceLocation(parser: Parser, position: Tokenizer.Pos) lineAndCol {
    var start_pos = position.start;
    var end_pos = position.end;
    var total_lines: i32 = 0;
    var lines_to_start: i32 = 0;
    var line_col: i32 = 0;
    var i: usize = parser.source_code.len;
    var found_col = false;
    while (i > 0) {
        const ch = parser.source_code[i];
        if (start_pos != position.start and ch == '\n' and position.end != end_pos) {
            end_pos = i;
        }
        if (start_pos > i and ch == '\n' and position.start == start_pos) {
            start_pos = i;
            lines_to_start = total_lines;
        }
        if (position.start != start_pos and !found_col) {
            line_col += 1;
            found_col = true;
        }
        if (ch == '\n') total_lines += 1;
        i -= 1;
    }
    const line_and_col = lineAndCol{ .line = total_lines - lines_to_start + 1, .col = line_col };

    var buf: [24]u8 = undefined;
    var line_number: []u8 = undefined;
    if (std.fmt.bufPrint(&buf, "{}: ", .{total_lines - lines_to_start + 1})) |a| {
        line_number = a;
    } else |_| {
        @memset(&buf, 0);
    }
    std.debug.print("{s}{s}\n", .{ line_number, parser.source_code[start_pos + 1 .. end_pos] });

    const col = position.start - start_pos - 1;
    if (col >= 1024) return line_and_col;
    var padding: [1024]u8 = undefined;
    @memset(&padding, ' ');

    if (position.end - position.start > 1) {
        var range: [128]u8 = undefined;
        @memset(&range, '-');
        std.debug.print("{s}^{s}^\n", .{ padding[0 .. col + line_number.len], range[0 .. position.end - position.start - 2] });
    } else {
        std.debug.print("{s}^\n", .{padding[0 .. col + line_number.len]});
    }
    return line_and_col;
}

pub fn printError(parser: Parser, err: ParseError) void {
    switch (parser.error_info) {
        .unexpected_token => {
            const info = parser.error_info.unexpected_token;
            const line_and_col = printSourceLocation(parser, info.found.pos);
            std.log.err("expected {s}, found {s} (line {} col {})\n", .{ @tagName(info.expected), @tagName(info.found.type), line_and_col.line, line_and_col.col });
        },
        .other => {
            std.debug.print("{s} {s}\n", .{ @errorName(err), parser.error_info.other });
        },
        .allocation_error => {
            std.debug.print("{s} alloc error\n", .{@errorName(err)});
        },
        .expected_and_found => {
            const info = parser.error_info.expected_and_found;
            const line_and_col = printSourceLocation(parser, info.found.pos);
            std.log.err("expected {s}, found {s} (line {} col {})\n", .{ info.expected, @tagName(info.found.type), line_and_col.line, line_and_col.col });
        },
        // else => {
        //     std.debug.print("{s}\n", .{@errorName(err)});
        // },
    }
}
