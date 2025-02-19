const std = @import("std");

pub const TokenType = enum {
    invalid,
    eof,
    number_literal,
    string_literal,
    keyword_return,
    keyword_if,
    keyword_while,
    keyword_for,
    keyword_var,
    keyword_fun,
    identifier,
    semicolon,
    colon,
    equal,
    bang,
    plus,
    minus,
    asterisk,
    paren_left,
    paren_right,
    curly_br_left,
    curly_br_right,
    square_br_left,
    square_br_right,
    greater_than,
    lesser_than,
    equal_equal,
    greater_than_or_eq,
    lesser_than_or_eq,
};
pub fn lexeme(token: TokenType) [:0]const u8 {
    return switch (token) {
        .semicolon => ";",
        .colon => ":",
        .equal => "=",
        .equal_equal => "==",
        .greater_than => ">",
        .lesser_than => "<",
        .greater_than_or_eq => ">=",
        .lesser_than_or_eq => "<=",
        .bang => "!",
        .plus => "+",
        .minus => "-",
        .asterisk => "*",
        .paren_left => "(",
        .paren_right => ")",
        .curly_br_left => "{",
        .curly_br_right => "}",
        .square_br_left => "[",
        .square_br_right => "]",

        // todo
        else => "",
    };
}
pub const token_strings = std.StaticStringMap(TokenType).initComptime(.{
    .{ lexeme(.semicolon), .semicolon },
    .{ lexeme(.colon), .colon },
    .{ lexeme(.equal), .equal },
    .{ lexeme(.greater_than), .greater_than },
    .{ lexeme(.lesser_than), .lesser_than },
    .{ lexeme(.bang), .bang },
    .{ lexeme(.plus), .plus },
    .{ lexeme(.minus), .minus },
    .{ lexeme(.asterisk), .asterisk },
    .{ lexeme(.paren_left), .paren_left },
    .{ lexeme(.paren_right), .paren_right },
    .{ lexeme(.curly_br_left), .curly_br_left },
    .{ lexeme(.curly_br_right), .curly_br_right },
    .{ lexeme(.square_br_left), .square_br_left },
    .{ lexeme(.square_br_right), .square_br_right },
});
pub const Pos = struct { start: usize, end: usize };

pub const Token = struct {
    type: TokenType,
    pos: Pos,
};

pub const keywords = std.StaticStringMap(TokenType).initComptime(.{
    .{ "return", .keyword_return },
    .{ "if", .keyword_if },
    .{ "while", .keyword_while },
    .{ "for", .keyword_for },
    .{ "var", .keyword_var },
});

pub const Tokenizer = struct {
    buffer: [:0]const u8,
    index: usize,

    const State = enum { start, identifier, number_literal, string_literal };

    pub fn init(buf: [:0]const u8) Tokenizer {
        return Tokenizer{ .buffer = buf, .index = 0 };
    }

    pub fn next(self: *Tokenizer) Token {
        var result: Token = .{ .type = TokenType.invalid, .pos = .{ .start = self.index, .end = self.index + 1 } };

        sw: switch (State.start) {
            .start => switch (self.buffer[self.index]) {
                0 => {
                    result.type = .eof;
                    result.pos = .{ .start = self.index, .end = self.index };
                },
                ' ', '\t', '\n' => {
                    self.index += 1;
                    result.pos.start = self.index;
                    continue :sw .start;
                },
                'A'...'Z', 'a'...'z' => {
                    result.type = .identifier;
                    continue :sw .identifier;
                },
                '"' => {
                    result.type = .string_literal;
                    self.index += 1;
                    continue :sw .string_literal;
                },
                '0'...'9' => {
                    result.type = .number_literal;
                    continue :sw .number_literal;
                },
                ';', ':', '!', '+', '-', '*', '(', ')', '{', '}', '[', ']' => {
                    result.type = token_strings.get(self.buffer[self.index .. self.index + 1]) orelse .invalid;
                    self.index += 1;
                    result.pos.end = self.index;
                },
                '=' => {
                    self.index += 1;
                    switch (self.buffer[self.index]) {
                        '=' => {
                            self.index += 1;
                            result.type = .equal_equal;
                        },
                        else => result.type = .equal,
                    }
                    result.pos.end = self.index;
                },
                '>' => {
                    self.index += 1;
                    switch (self.buffer[self.index]) {
                        '=' => {
                            self.index += 1;
                            result.type = .greater_than_or_eq;
                        },
                        else => result.type = .greater_than,
                    }
                    result.pos.end = self.index;
                },
                '<' => {
                    self.index += 1;
                    switch (self.buffer[self.index]) {
                        '=' => {
                            self.index += 1;
                            result.type = .lesser_than_or_eq;
                        },
                        else => result.type = .lesser_than,
                    }
                    result.pos.end = self.index;
                },
                else => {
                    self.index += 1;
                },
            },
            .identifier => switch (self.buffer[self.index]) {
                'A'...'Z', 'a'...'z', '0'...'9', '_' => {
                    self.index += 1;
                    result.pos.end = self.index;
                    continue :sw .identifier;
                },
                else => {
                    if (keywords.get(self.buffer[result.pos.start..result.pos.end])) |kw|
                        result.type = kw;
                },
            },
            .number_literal => switch (self.buffer[self.index]) {
                '0'...'9', '_', 'x', 'a'...'f', 'A'...'F' => {
                    self.index += 1;
                    result.pos.end = self.index;
                    continue :sw .number_literal;
                },
                else => {},
            },
            .string_literal => switch (self.buffer[self.index]) {
                '"' => {
                    self.index += 1;
                    result.pos.end = self.index;
                },
                else => {
                    self.index += 1;
                    result.pos.end = self.index;
                    continue :sw .string_literal;
                },
            },
        }
        return result;
    }

    pub fn tokenize(self: *Tokenizer, allocator: std.mem.Allocator) std.ArrayList(Token) {
        var tokens = std.ArrayList(Token).init(allocator);

        var token: Token = self.next();
        while (token.type != .eof) : (token = self.next()) {
            tokens.append(token) catch undefined;
        } else tokens.append(token) catch undefined;

        return tokens;
    }
};

fn tokens_equal(actual: std.ArrayList(Token), expected: []const TokenType) bool {
    if (actual.items.len != expected.len) return false;

    for (actual.items, expected) |actual_t, expected_t| {
        if (actual_t.type != expected_t) return false;
    }
    return true;
}
fn test_tokenize(str: [:0]const u8, expected: []const TokenType) !void {
    var tokenizer = Tokenizer.init(str);
    var tokens = tokenizer.tokenize(std.testing.allocator);
    defer tokens.deinit();
    for (tokens.items) |token|
        std.debug.print("{s}:{s}, ", .{ str[token.pos.start..token.pos.end], @tagName(token.type) });
    std.debug.print("\n", .{});
    _ = tokens.pop();
    try std.testing.expect(tokens_equal(tokens, expected));
}

test "keywords" {
    try test_tokenize("return", &.{.keyword_return});
    try test_tokenize("if", &.{.keyword_if});
    try test_tokenize("while", &.{.keyword_while});
    try test_tokenize("for", &.{.keyword_for});
}

test "number literal" {
    try test_tokenize("1234", &.{.number_literal});
    try test_tokenize("0xff_a1_23", &.{.number_literal});
    try test_tokenize("0b00_00_01", &.{.number_literal});
    try test_tokenize("0456", &.{.number_literal});
}

test "string literal" {
    try test_tokenize("\"test if while for\"", &.{.string_literal});
}

test "variable assignment" {
    try test_tokenize("var hello: u32 = 123;", &.{ .keyword_var, .identifier, .colon, .identifier, .equal, .number_literal, .semicolon });
}

test "math" {
    try test_tokenize("1+2*3-4", &.{ .number_literal, .plus, .number_literal, .asterisk, .number_literal, .minus, .number_literal });
}

test "if" {
    try test_tokenize("if (1 == 2)", &.{ .keyword_if, .paren_left, .number_literal, .equal_equal, .number_literal, .paren_right });
    try test_tokenize("if (1 >= 2 > 3)", &.{ .keyword_if, .paren_left, .number_literal, .greater_than_or_eq, .number_literal, .greater_than, .number_literal, .paren_right });
    try test_tokenize("if (1 <= 2 < 3)", &.{ .keyword_if, .paren_left, .number_literal, .lesser_than_or_eq, .number_literal, .lesser_than, .number_literal, .paren_right });
}
