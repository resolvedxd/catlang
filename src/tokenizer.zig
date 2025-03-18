const std = @import("std");

pub const TokenType = enum {
    invalid,
    eof,
    number_literal,
    string_literal,
    keyword_return,
    keyword_if,
    keyword_else,
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
    slash,
    comma,
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
    bang_equal,
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
        .bang_equal => "!=",
        .plus => "+",
        .minus => "-",
        .asterisk => "*",
        .slash => "/",
        .comma => ",",
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
    .{ lexeme(.slash), .slash },
    .{ lexeme(.comma), .comma },
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
    .{ "else", .keyword_else },
    .{ "while", .keyword_while },
    .{ "for", .keyword_for },
    .{ "var", .keyword_var },
    .{ "fun", .keyword_fun },
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
                ';', ':', '+', '-', '*', '(', ')', '{', '}', '[', ']' => {
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
                '!' => {
                    self.index += 1;
                    switch (self.buffer[self.index]) {
                        '=' => {
                            self.index += 1;
                            result.type = .bang_equal;
                        },
                        else => result.type = .bang,
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
